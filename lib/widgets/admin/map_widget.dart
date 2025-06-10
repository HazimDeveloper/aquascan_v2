// lib/widgets/admin/map_widget.dart - ENHANCED with Multiple Routes
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../models/report_model.dart' as route_model;
import '../../models/route_model.dart' as route_model;

class RouteMapWidget extends StatefulWidget {
  final route_model.RouteModel? routeModel;
  final List<ReportModel> reports;
  final List<ReportModel> selectedReports;
  final GeoPoint? currentLocation;
  final Function(ReportModel)? onReportTap;
  final bool showSelectionStatus;
  
  // NEW: Multiple routes support
  final List<Map<String, dynamic>>? multipleRoutes;
  final int? shortestRouteIndex;
  final List<Map<String, dynamic>>? waterSupplyPoints;
  final bool showMultipleRoutes;
  final Function(int)? onRouteSelected;

  const RouteMapWidget({
    Key? key,
    this.routeModel,
    required this.reports,
    this.selectedReports = const [],
    this.currentLocation,
    this.onReportTap,
    this.showSelectionStatus = true,
    // NEW parameters
    this.multipleRoutes,
    this.shortestRouteIndex,
    this.waterSupplyPoints,
    this.showMultipleRoutes = false,
    this.onRouteSelected,
  }) : super(key: key);

  @override
  _RouteMapWidgetState createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> with TickerProviderStateMixin {
  late MapController _mapController;
  ReportModel? _selectedReportForInfo;
  bool _isInfoWindowVisible = false;
  int? _selectedRouteIndex;
  
  // Animation controllers for route highlighting
  late AnimationController _pulseController;
  late AnimationController _routeAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _routeAnimation;
  
  // Constants for travel calculations
  static const double AVERAGE_SPEED_KM_PER_HOUR = 30.0;
  
  // Debug logging
  final bool _debugMode = true;
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('🗺️ MapWidget: $message');
    }
  }
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _routeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _routeAnimationController, curve: Curves.easeInOut),
    );
    
    _logRouteData();
    
    // Start route animation if multiple routes are shown
    if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true) {
      _routeAnimationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeModel != widget.routeModel || 
        oldWidget.multipleRoutes != widget.multipleRoutes) {
      _logRouteData();
      
      // Restart animation when routes change
      if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true) {
        _routeAnimationController.reset();
        _routeAnimationController.forward();
      }
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _routeAnimationController.dispose();
    super.dispose();
  }
  
  void _logRouteData() {
    if (widget.showMultipleRoutes && widget.multipleRoutes != null) {
      _logDebug('Multiple routes mode enabled');
      _logDebug('Routes available: ${widget.multipleRoutes!.length}');
      _logDebug('Shortest route index: ${widget.shortestRouteIndex}');
      _logDebug('Water supply points: ${widget.waterSupplyPoints?.length ?? 0}');
      
      for (int i = 0; i < widget.multipleRoutes!.length; i++) {
        final route = widget.multipleRoutes![i];
        _logDebug('Route $i: distance=${route['distance']}km, time=${route['estimated_time']}');
      }
    } else if (widget.routeModel != null) {
      _logDebug('Single route model available:');
      _logDebug('  - Points: ${widget.routeModel!.points.length}');
      _logDebug('  - Segments: ${widget.routeModel!.segments.length}');
      _logDebug('  - Total distance: ${widget.routeModel!.totalDistance}');
    } else {
      _logDebug('No route model available');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null && widget.reports.isEmpty && 
        (widget.waterSupplyPoints?.isEmpty ?? true)) {
      return _buildNoLocationView();
    }

    return Stack(
      children: [
        // The map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _calculateMapCenter(),
            initialZoom: 13.0,
            minZoom: 4,
            maxZoom: 18,
            onTap: (_, __) {
              setState(() {
                _isInfoWindowVisible = false;
                _selectedReportForInfo = null;
                _selectedRouteIndex = null;
              });
            },
            onMapReady: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final bounds = _calculateMapBounds();
                if (bounds != null) {
                  _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50.0),
                    ),
                  );
                }
              });
            },
          ),
          children: [
            // Base map tiles
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.water_watch',
            ),
            
            // Polylines for routes (multiple or single)
            PolylineLayer(
              polylines: _buildEnhancedRoutePolylines(),
            ),
            
            // Markers for points of interest
            MarkerLayer(
              markers: _buildEnhancedMarkers(),
            ),
          ],
        ),
        
        // Enhanced route info panel
        if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true)
          _buildMultipleRoutesInfoPanel()
        else if (widget.routeModel != null && widget.routeModel!.totalDistance > 0)
          _buildSingleRouteInfoPanel(),
          
        // Route legend for multiple routes
        if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true)
          _buildRouteLegend(),
          
        // Map controls
        Positioned(
          right: 16,
          bottom: widget.showMultipleRoutes ? 200 : 16,
          child: _buildMapControls(),
        ),
        
        // Info window when a report marker is tapped
        if (_isInfoWindowVisible && _selectedReportForInfo != null)
          _buildReportInfoCard(_selectedReportForInfo!),
        
        // Route details when a route is selected
        if (_selectedRouteIndex != null && widget.multipleRoutes != null)
          _buildRouteDetailsCard(widget.multipleRoutes![_selectedRouteIndex!], _selectedRouteIndex!),
      ],
    );
  }
  
  Widget _buildNoLocationView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            "No location data available",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Please enable location services or select a location",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // ENHANCED: Build multiple route polylines with different colors and animations
  List<Polyline> _buildEnhancedRoutePolylines() {
    final polylines = <Polyline>[];
    
    if (widget.showMultipleRoutes && widget.multipleRoutes?.isNotEmpty == true) {
      _logDebug('Building ${widget.multipleRoutes!.length} multiple routes polylines');
      
      // Build polylines for each route from current location to water supply
      for (int i = 0; i < widget.multipleRoutes!.length; i++) {
        final route = widget.multipleRoutes![i];
        final isShortestRoute = i == widget.shortestRouteIndex;
        final isSelectedRoute = i == _selectedRouteIndex;
        
        if (widget.currentLocation != null && route.containsKey('destination')) {
          final destination = route['destination'] as Map<String, dynamic>;
          
          // Create route points from current location to destination
          final points = [
            LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
            LatLng(
              destination['latitude']?.toDouble() ?? 0.0,
              destination['longitude']?.toDouble() ?? 0.0,
            ),
          ];
          
          // Determine route color and style
          Color routeColor;
          double strokeWidth;
          List<double> pattern = [];
          
          if (isShortestRoute) {
            routeColor = Colors.green;
            strokeWidth = 8.0;
          } else if (isSelectedRoute) {
            routeColor = Colors.blue;
            strokeWidth = 6.0;
          } else {
            routeColor = _getRouteColor(i);
            strokeWidth = 4.0;
            pattern = [10, 5]; // Dashed for non-primary routes
          }
          
          // Apply animation opacity
          final animatedOpacity = _routeAnimation.value;
          
          polylines.add(
            Polyline(
  points: points,
  color: routeColor.withOpacity(animatedOpacity),
  strokeWidth: strokeWidth,
  // If your Polyline API supports dashArray, use it like below:
  // dashArray: pattern,
),
          );
          
          _logDebug('Added route $i: ${isShortestRoute ? "SHORTEST" : isSelectedRoute ? "SELECTED" : "regular"} - ${route['distance']}km');
        }
      }
    } 
    // Single route mode (existing logic)
    else if (widget.routeModel != null && widget.routeModel!.segments.isNotEmpty) {
      _logDebug('Building single route polylines');
      
      for (int i = 0; i < widget.routeModel!.segments.length; i++) {
        final segment = widget.routeModel!.segments[i];
        
        if (segment.polyline.isNotEmpty) {
          try {
            final points = segment.polyline
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
            
            if (points.length >= 2) {
              polylines.add(
                Polyline(
                  points: points,
                  color: Colors.blue,
                  strokeWidth: 5.0,
                ),
              );
            }
          } catch (e) {
            _logDebug('Error creating polyline for segment $i: $e');
          }
        }
      }
    }
    
    _logDebug('Created ${polylines.length} polylines total');
    return polylines;
  }
  
  // Get distinct colors for different routes
  Color _getRouteColor(int index) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
    ];
    return colors[index % colors.length];
  }
  
  // ENHANCED: Build markers with water supply points and route indicators
  List<Marker> _buildEnhancedMarkers() {
    final markers = <Marker>[];
    
    _logDebug('Building enhanced markers...');
    
    // Add current location marker (always on top)
    if (widget.currentLocation != null) {
      markers.add(_buildCurrentLocationMarker());
    }
    
    // Multiple routes mode: Add water supply markers
    if (widget.showMultipleRoutes && widget.waterSupplyPoints?.isNotEmpty == true) {
      _logDebug('Adding ${widget.waterSupplyPoints!.length} water supply markers');
      
      for (int i = 0; i < widget.waterSupplyPoints!.length; i++) {
        final waterSupply = widget.waterSupplyPoints![i];
        final isShortestRoute = i == widget.shortestRouteIndex;
        final isSelectedRoute = i == _selectedRouteIndex;
        
        markers.add(_buildWaterSupplyMarker(waterSupply, i, isShortestRoute, isSelectedRoute));
      }
    }
    // Single route mode: Add route point markers
    else if (widget.routeModel != null && widget.routeModel!.points.isNotEmpty) {
      _logDebug('Adding ${widget.routeModel!.points.length} route point markers');
      
      for (int i = 0; i < widget.routeModel!.points.length; i++) {
        final point = widget.routeModel!.points[i];
        
        // Skip the start point (current location)
        if (point.nodeId == "start" || point.nodeId.contains("current")) {
          continue;
        }
        
        markers.add(_buildRoutePointMarker(point));
      }
    }
    // Default mode: Add report markers
    else {
      _logDebug('Adding ${widget.reports.length} report markers');
      
      for (final report in widget.reports) {
        markers.add(_buildReportMarker(report));
      }
    }
    
    _logDebug('Total markers created: ${markers.length}');
    return markers;
  }
  
  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
      width: 200,
      height: 100,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40 * _pulseAnimation.value,
                height: 40 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 20 * _pulseAnimation.value,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  "Your Location",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Marker _buildWaterSupplyMarker(Map<String, dynamic> waterSupply, int index, bool isShortestRoute, bool isSelectedRoute) {
    final routeInfo = widget.multipleRoutes![index];
    
    return Marker(
      point: LatLng(
        waterSupply['latitude']?.toDouble() ?? 0.0,
        waterSupply['longitude']?.toDouble() ?? 0.0,
      ),
      width: 160,
      height: 100,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
          });
          
          if (widget.onRouteSelected != null) {
            widget.onRouteSelected!(index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  // Main marker
                  Container(
                    width: isShortestRoute ? 60 : isSelectedRoute ? 55 : 50,
                    height: isShortestRoute ? 60 : isSelectedRoute ? 55 : 50,
                    decoration: BoxDecoration(
                      color: isShortestRoute 
                          ? Colors.green 
                          : isSelectedRoute 
                              ? Colors.blue 
                              : _getRouteColor(index),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: isShortestRoute ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isShortestRoute ? Icons.star : Icons.water_drop,
                      color: Colors.white,
                      size: isShortestRoute ? 35 : isSelectedRoute ? 30 : 28,
                    ),
                  ),
                  
                  // Route number badge
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Label
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isShortestRoute 
                      ? Colors.green 
                      : isSelectedRoute 
                          ? Colors.blue 
                          : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isShortestRoute 
                        ? Colors.green 
                        : isSelectedRoute 
                            ? Colors.blue 
                            : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isShortestRoute ? "SHORTEST" : "${routeInfo['distance']?.toStringAsFixed(1) ?? '?'}km",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isShortestRoute || isSelectedRoute ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (!isShortestRoute)
                      Text(
                        routeInfo['estimated_time'] ?? '',
                        style: TextStyle(
                          fontSize: 8,
                          color: isSelectedRoute ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Marker _buildRoutePointMarker(route_model.RoutePoint point) {
    final isWaterSupply = point.nodeId.contains('supply') || 
                         point.label?.toLowerCase().contains('water') == true ||
                         point.address.toLowerCase().contains('water') ||
                         point.address.toLowerCase().contains('supply');
    
    if (isWaterSupply) {
      return Marker(
        point: LatLng(point.location.latitude, point.location.longitude),
        width: 140,
        height: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.water_drop,
                color: Colors.white,
                size: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                point.label ?? "Water Supply",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Marker(point: LatLng(0, 0), width: 0, height: 0, child: Container());
  }
  
  Marker _buildReportMarker(ReportModel report) {
    final isSelected = widget.selectedReports.any((r) => r.id == report.id);
    
    return Marker(
      point: LatLng(report.location.latitude, report.location.longitude),
      width: 80,
      height: 40,
      child: GestureDetector(
        onTap: () {
          if (widget.onReportTap != null) {
            widget.onReportTap!(report);
          } else {
            setState(() {
              _selectedReportForInfo = report;
              _isInfoWindowVisible = true;
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isSelected ? Icons.check : Icons.warning,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
  
  // NEW: Multiple routes info panel
  Widget _buildMultipleRoutesInfoPanel() {
    final shortestRoute = widget.shortestRouteIndex != null && 
                         widget.multipleRoutes != null &&
                         widget.shortestRouteIndex! < widget.multipleRoutes!.length
        ? widget.multipleRoutes![widget.shortestRouteIndex!]
        : null;
    
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.route, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multiple Water Supply Routes',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.multipleRoutes?.length ?? 0} routes found to nearby water supplies',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (shortestRoute != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'SHORTEST ROUTE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Distance
                    Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.straighten, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${shortestRoute['distance']?.toStringAsFixed(1) ?? '?'} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Distance',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    
                    // Time
                    Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              shortestRoute['estimated_time'] ?? '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Travel Time',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    
                    // Destination
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shortestRoute['destination']?['street_name'] ?? 'Water Supply',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Destination',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Single route info panel (existing)
  Widget _buildSingleRouteInfoPanel() {
    final distance = widget.routeModel!.totalDistance;
    final travelTime = calculateTravelTime(distance);
    
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Water Supply Route',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Optimized route to water supply',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        'Distance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            travelTime,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        'Travel Time',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          const Text(
                            '30 km/h',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        'Avg. Speed',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // NEW: Route legend for multiple routes
  Widget _buildRouteLegend() {
    if (widget.multipleRoutes == null || widget.multipleRoutes!.isEmpty) {
      return Container();
    }
    
    return Positioned(
      left: 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(12),
          width: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Routes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.multipleRoutes!.asMap().entries.map((entry) {
                final index = entry.key;
                final route = entry.value;
                final isShortestRoute = index == widget.shortestRouteIndex;
                final isSelectedRoute = index == _selectedRouteIndex;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRouteIndex = _selectedRouteIndex == index ? null : index;
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isShortestRoute 
                                ? Colors.green 
                                : isSelectedRoute 
                                    ? Colors.blue 
                                    : _getRouteColor(index),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isShortestRoute ? 'Shortest' : 'Route ${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isShortestRoute ? FontWeight.bold : FontWeight.normal,
                                  color: isShortestRoute ? Colors.green : null,
                                ),
                              ),
                              Text(
                                '${route['distance']?.toStringAsFixed(1) ?? '?'}km',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom controls
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  _mapController.move(
                    _mapController.camera.center, 
                    _mapController.camera.zoom + 1
                  );
                },
                tooltip: 'Zoom In',
              ),
              const Divider(height: 1),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  _mapController.move(
                    _mapController.camera.center, 
                    _mapController.camera.zoom - 1
                  );
                },
                tooltip: 'Zoom Out',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Fit all markers button
        FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          onPressed: () {
            final bounds = _calculateMapBounds();
            if (bounds != null) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50.0),
                ),
              );
            }
          },
          child: const Icon(Icons.fit_screen),
          tooltip: 'Fit all markers',
        ),
        
        // Show/hide routes toggle (for multiple routes mode)
        if (widget.showMultipleRoutes) ...[
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: () {
              setState(() {
                _selectedRouteIndex = null;
              });
              // You could add logic to show/hide specific routes
            },
            child: const Icon(Icons.layers),
            tooltip: 'Clear selection',
          ),
        ],
      ],
    );
  }
  
  Widget _buildReportInfoCard(ReportModel report) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getWaterQualityColor(report.waterQuality).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.water_drop, 
                      color: _getWaterQualityColor(report.waterQuality),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isInfoWindowVisible = false;
                        _selectedReportForInfo = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onReportTap != null)
                    TextButton(
                      onPressed: () {
                        if (widget.onReportTap != null) {
                          widget.onReportTap!(report);
                          setState(() {
                            _isInfoWindowVisible = false;
                            _selectedReportForInfo = null;
                          });
                        }
                      },
                      child: Text(
                        widget.selectedReports.any((r) => r.id == report.id)
                            ? "Deselect"
                            : "Select",
                      ),
                    ),
                  
                  const SizedBox(width: 8),
                  
                  ElevatedButton(
                    onPressed: () {
                      _findClosestWaterSource(report);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Find Water Supply"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // NEW: Route details card when a route is selected
  Widget _buildRouteDetailsCard(Map<String, dynamic> route, int routeIndex) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: routeIndex == widget.shortestRouteIndex 
                          ? Colors.green.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      routeIndex == widget.shortestRouteIndex ? Icons.star : Icons.route,
                      color: routeIndex == widget.shortestRouteIndex ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeIndex == widget.shortestRouteIndex 
                              ? 'Shortest Route' 
                              : 'Route ${routeIndex + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: routeIndex == widget.shortestRouteIndex ? Colors.green : Colors.blue,
                          ),
                        ),
                        Text(
                          route['destination']?['street_name'] ?? 'Water Supply Point',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedRouteIndex = null;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        'Distance',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            route['estimated_time'] ?? '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        'Travel Time',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              if (route['destination'] != null) ...[
                const Divider(height: 1),
                const SizedBox(height: 8),
                
                Text(
                  'Destination Details',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  route['destination']['address'] ?? 'No address available',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                if (route['destination']['additional_info'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    route['destination']['additional_info'],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  void _findClosestWaterSource(ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finding closest water supply...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    setState(() {
      _isInfoWindowVisible = false;
      _selectedReportForInfo = null;
    });
    
    if (widget.onReportTap != null) {
      widget.onReportTap!(report);
    }
  }
  
  // Calculate estimated travel time
  String calculateTravelTime(double distanceInKm) {
    double timeInHours = distanceInKm / AVERAGE_SPEED_KM_PER_HOUR;
    int minutes = (timeInHours * 60).round();
    
    if (minutes < 60) {
      return "$minutes min";
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return "$hours h ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}";
    }
  }
  
  LatLng _calculateMapCenter() {
    if (widget.showMultipleRoutes && widget.waterSupplyPoints?.isNotEmpty == true) {
      // Center on first water supply point
      final firstPoint = widget.waterSupplyPoints!.first;
      return LatLng(
        firstPoint['latitude']?.toDouble() ?? 0.0,
        firstPoint['longitude']?.toDouble() ?? 0.0,
      );
    } else if (widget.routeModel != null && widget.routeModel!.points.isNotEmpty) {
      final firstPoint = widget.routeModel!.points.first;
      return LatLng(firstPoint.location.latitude, firstPoint.location.longitude);
    } else if (widget.currentLocation != null) {
      return LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude);
    } else if (widget.reports.isNotEmpty) {
      final firstReport = widget.reports.first;
      return LatLng(firstReport.location.latitude, firstReport.location.longitude);
    } else {
      return const LatLng(3.1390, 101.6869); // Default to Kuala Lumpur
    }
  }
  
  LatLngBounds? _calculateMapBounds() {
    final points = <LatLng>[];
    
    if (widget.currentLocation != null) {
      points.add(LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude));
    }
    
    // Add water supply points if in multiple routes mode
    if (widget.showMultipleRoutes && widget.waterSupplyPoints?.isNotEmpty == true) {
      for (final supply in widget.waterSupplyPoints!) {
        points.add(LatLng(
          supply['latitude']?.toDouble() ?? 0.0,
          supply['longitude']?.toDouble() ?? 0.0,
        ));
      }
    }
    
    for (final report in widget.reports) {
      points.add(LatLng(report.location.latitude, report.location.longitude));
    }
    
    if (widget.routeModel != null) {
      for (final point in widget.routeModel!.points) {
        points.add(LatLng(point.location.latitude, point.location.longitude));
      }
    }
    
    if (points.isEmpty) {
      return null;
    } else if (points.length == 1) {
      final point = points.first;
      final delta = 0.01; // About 1km
      return LatLngBounds(
        LatLng(point.latitude - delta, point.longitude - delta),
        LatLng(point.latitude + delta, point.longitude + delta),
      );
    }
    
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    
    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    
    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
  
  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.blue;
      case WaterQualityState.lowTemp:
        return Colors.green;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Colors.orange;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
}