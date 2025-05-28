// lib/widgets/admin/map_widget.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../models/route_model.dart' as route_model;

class RouteMapWidget extends StatefulWidget {
  final route_model.RouteModel? routeModel;
  final List<ReportModel> reports;
  final List<ReportModel> selectedReports;
  final GeoPoint? currentLocation;
  final Function(ReportModel)? onReportTap;
  final bool showSelectionStatus;

  const RouteMapWidget({
    Key? key,
    this.routeModel,
    required this.reports,
    this.selectedReports = const [],
    this.currentLocation,
    this.onReportTap,
    this.showSelectionStatus = true,
  }) : super(key: key);

  @override
  _RouteMapWidgetState createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  late MapController _mapController;
  ReportModel? _selectedReportForInfo;
  bool _isInfoWindowVisible = false;
  
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
    _logRouteData();
  }
  
  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeModel != widget.routeModel) {
      _logRouteData();
    }
  }
  
  void _logRouteData() {
    if (widget.routeModel != null) {
      _logDebug('Route model available:');
      _logDebug('  - Points: ${widget.routeModel!.points.length}');
      _logDebug('  - Segments: ${widget.routeModel!.segments.length}');
      _logDebug('  - Total distance: ${widget.routeModel!.totalDistance}');
      
      for (int i = 0; i < widget.routeModel!.segments.length; i++) {
        final segment = widget.routeModel!.segments[i];
        _logDebug('  - Segment $i: ${segment.polyline.length} polyline points, distance: ${segment.distance}');
      }
    } else {
      _logDebug('No route model available');
    }
  }
  
  // Calculate estimated travel time based on distance and average speed
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

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null && widget.reports.isEmpty) {
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
              });
            },
            onMapReady: () {
              // Zoom to fit all points with padding
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
            
            // Polylines for routes
            PolylineLayer(
              polylines: _buildRoutePolylines(),
            ),
            
            // Markers for points of interest
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),
        
        // Route info panel
        if (widget.routeModel != null && widget.routeModel!.totalDistance > 0)
          _buildRouteInfoPanel(),
          
        // Map controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
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
                    // Zoom in
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
                    // Zoom out
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
            ],
          ),
        ),
        
        // Info window when a report marker is tapped
        if (_isInfoWindowVisible && _selectedReportForInfo != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildReportInfoCard(_selectedReportForInfo!),
          ),
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
  
  Widget _buildRouteInfoPanel() {
    final distance = widget.routeModel!.totalDistance;
    final travelTime = calculateTravelTime(distance);
    
    String routeType = 'Route';
    if (widget.routeModel!.segments.isNotEmpty) {
      routeType = 'Water Supply Route';
    }
    
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
                        Text(
                          routeType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Closest water supply found',
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
                  // Distance
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Distance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  // Divider
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  
                  // Time
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            travelTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Travel Time',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  // Divider
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  
                  // Speed
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          const Text(
                            '30 km/h',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
  
  List<Polyline> _buildRoutePolylines() {
    final polylines = <Polyline>[];
    
    _logDebug('Building polylines...');
    
    if (widget.routeModel == null || widget.routeModel!.segments.isEmpty) {
      _logDebug('No route model or segments, returning empty polylines');
      return polylines;
    }
    
    _logDebug('Route model has ${widget.routeModel!.segments.length} segments');
    
    for (int i = 0; i < widget.routeModel!.segments.length; i++) {
      final segment = widget.routeModel!.segments[i];
      _logDebug('Processing segment $i with ${segment.polyline.length} polyline points');
      
      if (segment.polyline.isEmpty) {
        _logDebug('Segment $i has no polyline points, skipping');
        continue;
      }
      
      try {
        final points = segment.polyline
            .map((point) {
              _logDebug('Converting point: lat=${point.latitude}, lng=${point.longitude}');
              return LatLng(point.latitude, point.longitude);
            })
            .toList();
        
        if (points.length >= 2) {
          // Create a prominent polyline for the route
          polylines.add(
            Polyline(
              points: points,
              color: Colors.blue,
              strokeWidth: 5.0,
            ),
          );
          _logDebug('Added polyline for segment $i with ${points.length} points');
        } else {
          _logDebug('Segment $i has less than 2 points, skipping polyline');
        }
      } catch (e) {
        _logDebug('Error creating polyline for segment $i: $e');
      }
    }
    
    _logDebug('Created ${polylines.length} polylines total');
    return polylines;
  }
  
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    
    _logDebug('Building markers...');
    
    // Add current location marker first (will be on bottom layer)
    if (widget.currentLocation != null) {
      final locationMarker = Marker(
        point: LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
        width: 120,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green,
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
              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                "You",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      markers.add(locationMarker);
      _logDebug('Added current location marker');
    }
    
    // Add route point markers if route exists
    if (widget.routeModel != null && widget.routeModel!.points.isNotEmpty) {
      _logDebug('Adding ${widget.routeModel!.points.length} route point markers');
      
      for (int i = 0; i < widget.routeModel!.points.length; i++) {
        final point = widget.routeModel!.points[i];
        
        // Skip the start point (current location)
        if (point.nodeId == "start" || point.nodeId.contains("current")) {
          continue;
        }
        
        final isWaterSupply = point.nodeId.contains('supply') || 
                             point.label?.toLowerCase().contains('water') == true ||
                             point.address.toLowerCase().contains('water') ||
                             point.address.toLowerCase().contains('supply');
        
        if (isWaterSupply) {
          final marker = Marker(
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
          markers.add(marker);
          _logDebug('Added water supply marker for point: ${point.nodeId}');
        }
      }
    } 
    // If no route, show report markers
    else {
      _logDebug('No route available, showing ${widget.reports.length} report markers');
      
      for (final report in widget.reports) {
        final isSelected = widget.selectedReports.any((r) => r.id == report.id);
        
        final marker = Marker(
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
        markers.add(marker);
      }
      _logDebug('Added ${widget.reports.length} report markers');
    }
    
    _logDebug('Total markers created: ${markers.length}');
    return markers;
  }
  
  Widget _buildReportInfoCard(ReportModel report) {
    return Card(
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
    );
  }
  
  void _findClosestWaterSource(ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finding closest water supply...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Close the info window
    setState(() {
      _isInfoWindowVisible = false;
      _selectedReportForInfo = null;
    });
    
    // Trigger report selection if callback is available
    if (widget.onReportTap != null) {
      widget.onReportTap!(report);
    }
  }
  
  LatLng _calculateMapCenter() {
    if (widget.routeModel != null && widget.routeModel!.points.isNotEmpty) {
      final firstPoint = widget.routeModel!.points.first;
      return LatLng(firstPoint.location.latitude, firstPoint.location.longitude);
    } else if (widget.currentLocation != null) {
      return LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude);
    } else if (widget.reports.isNotEmpty) {
      final firstReport = widget.reports.first;
      return LatLng(firstReport.location.latitude, firstReport.location.longitude);
    } else {
      return const LatLng(6.4451267, 100.401005); // Default to Malaysia coordinates
    }
  }
  
  LatLngBounds? _calculateMapBounds() {
    final points = <LatLng>[];
    
    if (widget.currentLocation != null) {
      points.add(LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude));
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