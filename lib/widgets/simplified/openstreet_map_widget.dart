// lib/widgets/simplified/openstreet_map_widget.dart - WITH USER REPORTS
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import 'dart:math' as math;

class OpenStreetMapWidget extends StatefulWidget {
  final GeoPoint currentLocation;
  final List<Map<String, dynamic>> polylineRoutes;
  final List<ReportModel> userReports; // NEW: User reports
  final bool isLoading;

  const OpenStreetMapWidget({
    Key? key,
    required this.currentLocation,
    required this.polylineRoutes,
    this.userReports = const [], // NEW: Default empty list
    this.isLoading = false,
  }) : super(key: key);

  @override
  _OpenStreetMapWidgetState createState() => _OpenStreetMapWidgetState();
}

class _OpenStreetMapWidgetState extends State<OpenStreetMapWidget> {
  late MapController _mapController;
  bool _showRouteInfo = true;
  bool _showAllMarkers = false;
  bool _showRouteLines = true;
  bool _showReportRoutes = true; // NEW: Toggle for report routes
  int? _selectedRoute;
  ReportModel? _selectedReport; // NEW: Selected report
  double _currentZoom = 12.0;
  
  // Display settings
  int _maxVisibleMarkers = 10;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) {
        _fitMapToAllPoints();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // NEW: Fit map to include both routes and reports
  void _fitMapToAllPoints() {
    try {
      final bounds = _calculateMapBoundsWithReports();
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.all(50),
        ),
      );
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentZoom = _mapController.camera.zoom;
        });
      });
    } catch (e) {
      print('Error fitting map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main Map
        _buildMainMap(),
        
        // Loading overlay
        if (widget.isLoading) _buildLoadingOverlay(),
        
        // Empty state
        if (!widget.isLoading && widget.polylineRoutes.isEmpty && widget.userReports.isEmpty) 
          _buildEmptyOverlay(),
        
        // Clean header controls (UPDATED)
        if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) 
          _buildUpdatedHeader(),
        
        // Zoom and view controls
        if (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty) 
          _buildViewControls(),
        
        // Clean route information panel (UPDATED)
        if (_showRouteInfo && (widget.polylineRoutes.isNotEmpty || widget.userReports.isNotEmpty)) 
          _buildUpdatedRoutePanel(),
      ],
    );
  }

  Widget _buildMainMap() {
    final currentLatLng = LatLng(
      widget.currentLocation.latitude,
      widget.currentLocation.longitude,
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLatLng,
        initialZoom: 12.0,
        minZoom: 8.0,
        maxZoom: 18.0,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapEvent: (MapEvent mapEvent) {
          if (mapEvent is MapEventMove) {
            setState(() {
              _currentZoom = mapEvent.camera.zoom;
              if (_currentZoom >= 15) {
                _maxVisibleMarkers = 25;
              } else if (_currentZoom >= 13) {
                _maxVisibleMarkers = 15;
              } else {
                _maxVisibleMarkers = 10;
              }
            });
          }
        },
      ),
      children: [
        // OpenStreetMap Tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.aquascan',
          maxZoom: 18,
        ),
        
        // Clean Polylines (UPDATED - includes report routes)
        if (_showRouteLines)
          PolylineLayer(
            polylines: _buildAllPolylines(),
          ),
        
        // Clean Markers (UPDATED - includes report markers)
        MarkerLayer(
          markers: _buildAllMarkers(),
        ),
      ],
    );
  }

  // NEW: Build all polylines including report routes
  List<Polyline> _buildAllPolylines() {
    List<Polyline> polylines = [];
    
    // Add water supply routes
    polylines.addAll(_buildWaterSupplyPolylines());
    
    // Add report to water supply routes
    if (_showReportRoutes) {
      polylines.addAll(_buildReportToWaterSupplyPolylines());
    }
    
    return polylines;
  }

  // Existing water supply polylines method
  List<Polyline> _buildWaterSupplyPolylines() {
    List<Polyline> polylines = [];
    
    List<int> routesToShow = [];
    if (_selectedRoute != null) {
      routesToShow = [_selectedRoute!];
    } else {
      final maxRoutes = _showAllMarkers ? widget.polylineRoutes.length : _maxVisibleMarkers;
      routesToShow = List.generate(
        maxRoutes > widget.polylineRoutes.length ? widget.polylineRoutes.length : maxRoutes,
        (index) => index,
      );
    }
    
    for (int index in routesToShow) {
      if (index < widget.polylineRoutes.length) {
        final route = widget.polylineRoutes[index];
        final polylinePoints = route['polyline_points'] as List<dynamic>? ?? [];
        
        if (polylinePoints.length >= 2) {
          List<LatLng> latLngPoints = [];
          
          for (final point in polylinePoints) {
            if (point is Map<String, dynamic>) {
              final lat = (point['latitude'] as num?)?.toDouble();
              final lng = (point['longitude'] as num?)?.toDouble();
              
              if (lat != null && lng != null) {
                latLngPoints.add(LatLng(lat, lng));
              }
            }
          }
          
          if (latLngPoints.length >= 2) {
            final routeColor = _getCleanRouteColor(index);
            final isSelected = _selectedRoute == index;
            final isTop3 = index < 3;
            
            polylines.add(
              Polyline(
                points: latLngPoints,
                strokeWidth: isSelected ? 6.0 : (isTop3 ? 4.0 : 3.0),
                color: routeColor.withOpacity(isSelected ? 1.0 : 0.7),
                borderStrokeWidth: isSelected ? 8.0 : (isTop3 ? 5.0 : 4.0),
                borderColor: routeColor.withOpacity(0.3),
              ),
            );
          }
        }
      }
    }
    
    return polylines;
  }

  // NEW: Build polylines from EVERY report to nearest water supplies
  List<Polyline> _buildReportToWaterSupplyPolylines() {
    List<Polyline> polylines = [];
    
    print('🔗 Building connection lines for ${widget.userReports.length} reports...');
    
    for (int reportIndex = 0; reportIndex < widget.userReports.length; reportIndex++) {
      final report = widget.userReports[reportIndex];
      
      // Find nearest water supply point for THIS specific report
      final nearestWaterSupply = _findNearestWaterSupply(report);
      
      if (nearestWaterSupply != null) {
        print('📍 Report ${reportIndex + 1}: "${report.title}" → ${nearestWaterSupply['name']} (${nearestWaterSupply['distance']?.toStringAsFixed(1)}km)');
        
        // Create connection line from report to water supply
        final reportLatLng = LatLng(report.location.latitude, report.location.longitude);
        final waterSupplyLatLng = LatLng(
          (nearestWaterSupply['latitude'] as num).toDouble(),
          (nearestWaterSupply['longitude'] as num).toDouble(),
        );
        
        // Get unique color and style for this report
        Color lineColor = _getWaterQualityColor(report.waterQuality);
        bool isSelected = _selectedReport?.id == report.id;
        
        // Create multiple line styles for variety
        if (reportIndex % 3 == 0) {
          // Solid line for every 3rd report
          polylines.add(
            Polyline(
              points: [reportLatLng, waterSupplyLatLng],
              strokeWidth: isSelected ? 5.0 : 3.0,
              color: lineColor.withOpacity(isSelected ? 1.0 : 0.7),
              borderStrokeWidth: isSelected ? 2.0 : 1.0,
              borderColor: Colors.white.withOpacity(0.8),
            ),
          );
        } else {
          // Dashed line for other reports
          final segments = _createDashedLine(reportLatLng, waterSupplyLatLng, 25);
          
          for (int i = 0; i < segments.length; i += 2) {
            if (i + 1 < segments.length) {
              polylines.add(
                Polyline(
                  points: [segments[i], segments[i + 1]],
                  strokeWidth: isSelected ? 4.0 : 2.5,
                  color: lineColor.withOpacity(isSelected ? 1.0 : 0.6),
                ),
              );
            }
          }
        }
        
        // Add arrow indicator for direction (optional visual enhancement)
        if (isSelected) {
          _addDirectionArrow(polylines, reportLatLng, waterSupplyLatLng, lineColor);
        }
        
      } else {
        print('❌ Report ${reportIndex + 1}: "${report.title}" - No water supply found nearby');
      }
    }
    
    print('✅ Created ${polylines.length} connection line segments total');
    return polylines;
  }
  
  // NEW: Add arrow to show direction from report to water supply
  void _addDirectionArrow(List<Polyline> polylines, LatLng start, LatLng end, Color color) {
    // Calculate midpoint
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final midPoint = LatLng(midLat, midLng);
    
    // Calculate direction vector
    final deltaLat = end.latitude - start.latitude;
    final deltaLng = end.longitude - start.longitude;
    final length = math.sqrt(deltaLat * deltaLat + deltaLng * deltaLng);
    
    if (length > 0) {
      final arrowSize = 0.002; // Small arrow
      final arrowAngle = 30 * (math.pi / 180); // 30 degrees
      
      // Normalize direction
      final dirLat = deltaLat / length;
      final dirLng = deltaLng / length;
      
      // Calculate arrow points
      final arrowTip = LatLng(
        midPoint.latitude + dirLat * arrowSize,
        midPoint.longitude + dirLng * arrowSize,
      );
      
      final arrowLeft = LatLng(
        midPoint.latitude - dirLat * arrowSize * math.cos(arrowAngle) + dirLng * arrowSize * math.sin(arrowAngle),
        midPoint.longitude - dirLng * arrowSize * math.cos(arrowAngle) - dirLat * arrowSize * math.sin(arrowAngle),
      );
      
      final arrowRight = LatLng(
        midPoint.latitude - dirLat * arrowSize * math.cos(arrowAngle) - dirLng * arrowSize * math.sin(arrowAngle),
        midPoint.longitude - dirLng * arrowSize * math.cos(arrowAngle) + dirLat * arrowSize * math.sin(arrowAngle),
      );
      
      // Add arrow lines
      polylines.add(
        Polyline(
          points: [arrowTip, arrowLeft],
          strokeWidth: 3.0,
          color: color,
        ),
      );
      polylines.add(
        Polyline(
          points: [arrowTip, arrowRight],
          strokeWidth: 3.0,
          color: color,
        ),
      );
    }
  }

  // NEW: Create dashed line effect
  List<LatLng> _createDashedLine(LatLng start, LatLng end, int segments) {
    List<LatLng> points = [];
    
    for (int i = 0; i <= segments; i++) {
      final ratio = i / segments;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }
    
    return points;
  }

  // NEW: Find nearest water supply to a report
  Map<String, dynamic>? _findNearestWaterSupply(ReportModel report) {
    if (widget.polylineRoutes.isEmpty) return null;
    
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestSupply;
    
    for (final route in widget.polylineRoutes) {
      final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final distance = _calculateDistance(
          report.location.latitude,
          report.location.longitude,
          lat,
          lng,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestSupply = {
            'latitude': lat,
            'longitude': lng,
            'distance': distance,
            'name': destinationDetails['street_name'] ?? 'Water Supply',
          };
        }
      }
    }
    
    return nearestSupply;
  }

  // NEW: Calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLng = (lng2 - lng1) * (math.pi / 180);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  // NEW: Build all markers including reports (NO CURRENT LOCATION)
  List<Marker> _buildAllMarkers() {
    List<Marker> markers = [];
    
    // REMOVED: Current location marker
    // Only show report and water supply markers
    
    // Water supply markers
    markers.addAll(_buildWaterSupplyMarkers());
    
    // User report markers
    markers.addAll(_buildUserReportMarkers());
    
    return markers;
  }

  // NEW: Build user report markers with unique identifiers
  List<Marker> _buildUserReportMarkers() {
    List<Marker> markers = [];
    
    for (int i = 0; i < widget.userReports.length; i++) {
      final report = widget.userReports[i];
      final isSelected = _selectedReport?.id == report.id;
      
      // Find nearest supply info for this report
      final nearestSupply = _findNearestWaterSupply(report);
      final distance = nearestSupply?['distance']?.toStringAsFixed(1) ?? '?';
      
      markers.add(
        Marker(
          point: LatLng(report.location.latitude, report.location.longitude),
          width: isSelected ? 80 : 60,
          height: isSelected ? 100 : 80,
          child: GestureDetector(
            onTap: () => _selectReport(report),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main report marker
                Container(
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
                  decoration: BoxDecoration(
                    color: _getWaterQualityColor(report.waterQuality),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getWaterQualityColor(report.waterQuality).withOpacity(0.4),
                        blurRadius: isSelected ? 12 : 8,
                        offset: Offset(0, isSelected ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.report_problem,
                          color: Colors.white,
                          size: isSelected ? 28 : 20,
                        ),
                      ),
                      // Report number badge
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Water quality indicator
                      if (report.waterQuality != WaterQualityState.unknown)
                        Positioned(
                          bottom: -2,
                          left: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getWaterQualityIndicatorColor(report.waterQuality),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Center(
                              child: Icon(
                                _getWaterQualityIcon(report.waterQuality),
                                color: Colors.white,
                                size: 6,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Info label when selected
                if (isSelected) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getWaterQualityColor(report.waterQuality),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Report ${i + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '→ ${distance}km',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Basic info when not selected
                if (!isSelected) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${distance}km',
                      style: TextStyle(
                        color: _getWaterQualityColor(report.waterQuality),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    
    print('📍 Created ${markers.length} report markers with distances');
    return markers;
  }
  
  // NEW: Get icon for water quality
  IconData _getWaterQualityIcon(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Icons.check;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Icons.science;
      case WaterQualityState.highPhTemp:
        return Icons.whatshot;
      case WaterQualityState.lowTemp:
        return Icons.ac_unit;
      case WaterQualityState.lowTempHighPh:
        return Icons.warning;
      case WaterQualityState.unknown:
      default:
        return Icons.help;
    }
  }

  // Existing methods with minor updates...
  List<Marker> _buildWaterSupplyMarkers() {
    List<Marker> markers = [];
    
    final maxMarkers = _showAllMarkers ? widget.polylineRoutes.length : _maxVisibleMarkers;
    Set<String> addedLocations = {};
    
    for (int i = 0; i < maxMarkers && i < widget.polylineRoutes.length; i++) {
      final route = widget.polylineRoutes[i];
      final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
      
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final locationKey = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
        
        if (!addedLocations.contains(locationKey)) {
          addedLocations.add(locationKey);
          markers.add(_buildCleanWaterMarker(route, i, lat, lng));
        }
      }
    }
    
    return markers;
  }

  Marker _buildCleanWaterMarker(Map<String, dynamic> route, int index, double lat, double lng) {
    final isSelected = _selectedRoute == index;
    final isTop3 = index < 3;
    final routeColor = _getCleanRouteColor(index);
    
    return Marker(
      point: LatLng(lat, lng),
      width: isSelected ? 50 : (isTop3 ? 44 : 40),
      height: isSelected ? 50 : (isTop3 ? 44 : 40),
      child: GestureDetector(
        onTap: () => _selectRoute(index),
        child: Container(
          decoration: BoxDecoration(
            color: routeColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white, 
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: routeColor.withAlpha((0.4 * 255).toInt()),
                blurRadius: isSelected ? 12 : 8,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: isSelected ? 24 : (isTop3 ? 20 : 18),
                ),
              ),
              if (isTop3)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: index == 0 ? Color(0xFFFFD700) : (index == 1 ? Colors.grey.shade400 : Colors.brown),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Updated header with report info
  Widget _buildUpdatedHeader() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50.withOpacity(0.5),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.water_drop, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports & Water Network',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.polylineRoutes.length} supplies • ${widget.userReports.length} reports',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildViewToggle(),
                  ],
                ),
                
                if (!_isMinimized) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat('Supplies', '${widget.polylineRoutes.length}', Colors.blue),
                      _buildQuickStat('Reports', '${widget.userReports.length}', Colors.orange),
                      _buildQuickStat('Distance', _getShortestDistance(), Colors.green),
                      _buildQuickStat('Zoom', '${_currentZoom.toInt()}x', Colors.purple),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.tune, color: Colors.blue),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'show_all':
              _showAllMarkers = !_showAllMarkers;
              break;
            case 'toggle_routes':
              _showRouteLines = !_showRouteLines;
              break;
            case 'toggle_report_routes':
              _showReportRoutes = !_showReportRoutes;
              break;
            case 'toggle_info':
              _showRouteInfo = !_showRouteInfo;
              break;
            case 'minimize':
              _isMinimized = !_isMinimized;
              break;
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'show_all',
          child: Row(
            children: [
              Icon(_showAllMarkers ? Icons.visibility_off : Icons.visibility, size: 16),
              SizedBox(width: 8),
              Text(_showAllMarkers ? 'Show Top Only' : 'Show All'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_routes',
          child: Row(
            children: [
              Icon(_showRouteLines ? Icons.route : Icons.alt_route, size: 16),
              SizedBox(width: 8),
              Text(_showRouteLines ? 'Hide Supply Routes' : 'Show Supply Routes'),
            ],
          ),
        ),
        // NEW: Toggle for report routes
        PopupMenuItem(
          value: 'toggle_report_routes',
          child: Row(
            children: [
              Icon(_showReportRoutes ? Icons.link_off : Icons.link, size: 16),
              SizedBox(width: 8),
              Text(_showReportRoutes ? 'Hide Report Links' : 'Show Report Links'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_info',
          child: Row(
            children: [
              Icon(_showRouteInfo ? Icons.info : Icons.info_outline, size: 16),
              SizedBox(width: 8),
              Text(_showRouteInfo ? 'Hide Info' : 'Show Info'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'minimize',
          child: Row(
            children: [
              Icon(_isMinimized ? Icons.expand_more : Icons.expand_less, size: 16),
              SizedBox(width: 8),
              Text(_isMinimized ? 'Expand' : 'Minimize'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // NEW: Updated route panel with report info
  Widget _buildUpdatedRoutePanel() {
    if (_isMinimized) return Container();
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: 200),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      _selectedReport != null ? 'Report Details' : 'Network Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Spacer(),
                    if (_selectedReport != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedReport = null),
                        child: Icon(Icons.clear, size: 16, color: Colors.blue.shade600),
                      ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showRouteInfo = false),
                      child: Icon(Icons.close, size: 16, color: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _selectedReport != null 
                      ? _buildSelectedReportInfo()
                      : _buildNetworkOverview(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Selected report information
  Widget _buildSelectedReportInfo() {
    if (_selectedReport == null) return Container();
    
    final nearestWaterSupply = _findNearestWaterSupply(_selectedReport!);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getWaterQualityColor(_selectedReport!.waterQuality),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.report_problem, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedReport!.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'By: ${_selectedReport!.userName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        Text(
          _selectedReport!.description,
          style: TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        SizedBox(height: 12),
        
        if (nearestWaterSupply != null) ...[
          Row(
            children: [
              Icon(Icons.water_drop, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                'Nearest Water Supply: ${nearestWaterSupply['distance']?.toStringAsFixed(1)} km',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            nearestWaterSupply['name'] ?? 'Unknown',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
        
        SizedBox(height: 8),
        
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getWaterQualityColor(_selectedReport!.waterQuality).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getWaterQualityColor(_selectedReport!.waterQuality).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.science,
                color: _getWaterQualityColor(_selectedReport!.waterQuality),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Quality: ${_getWaterQualityText(_selectedReport!.waterQuality)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getWaterQualityColor(_selectedReport!.waterQuality),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // NEW: Network overview when no report selected
  Widget _buildNetworkOverview() {
    // Calculate connection statistics
    int totalConnections = 0;
    double totalDistance = 0.0;
    Map<String, int> supplyUsage = {}; // Track which supplies are used most
    
    for (final report in widget.userReports) {
      final nearestSupply = _findNearestWaterSupply(report);
      if (nearestSupply != null) {
        totalConnections++;
        totalDistance += nearestSupply['distance'] ?? 0.0;
        
        final supplyName = nearestSupply['name'] ?? 'Unknown';
        supplyUsage[supplyName] = (supplyUsage[supplyName] ?? 0) + 1;
      }
    }
    
    final avgDistance = totalConnections > 0 ? totalDistance / totalConnections : 0.0;
    
    // Find most used supply
    String? mostUsedSupply;
    int maxUsage = 0;
    supplyUsage.forEach((supply, count) {
      if (count > maxUsage) {
        maxUsage = count;
        mostUsedSupply = supply;
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network Summary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                'Water Supplies',
                '${widget.polylineRoutes.length}',
                Icons.water_drop,
                Colors.blue,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildOverviewCard(
                'User Reports',
                '${widget.userReports.length}',
                Icons.report_problem,
                Colors.orange,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                'Connections',
                '$totalConnections',
                Icons.link,
                Colors.green,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildOverviewCard(
                'Avg Distance',
                '${avgDistance.toStringAsFixed(1)}km',
                Icons.straighten,
                Colors.purple,
              ),
            ),
          ],
        ),
        
        if (widget.userReports.isNotEmpty) ...[
          SizedBox(height: 12),
          
          // Most used supply info
          if (mostUsedSupply != null) ...[
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most Connected Supply',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          '$mostUsedSupply ($maxUsage connections)',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
          ],
          
          Text(
            'Recent Reports',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: math.min(widget.userReports.length, 3),
              itemBuilder: (context, index) {
                final report = widget.userReports[index];
                final nearestSupply = _findNearestWaterSupply(report);
                final distance = nearestSupply?['distance']?.toStringAsFixed(1) ?? '?';
                
                return GestureDetector(
                  onTap: () => _selectReport(report),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getWaterQualityColor(report.waterQuality),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '→ ${distance}km to supply',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.link,
                          size: 12,
                          color: _getWaterQualityColor(report.waterQuality),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewControls() {
    return Positioned(
      bottom: _showRouteInfo ? 240 : 100,
      right: 16,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Zoom: ${_currentZoom.toInt()}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          SizedBox(height: 8),
          
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                IconButton(
                  onPressed: _currentZoom >= 18.0 ? null : _zoomIn,
                  icon: Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: _currentZoom >= 18.0 ? Colors.grey : Colors.blue,
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade300),
                IconButton(
                  onPressed: _currentZoom <= 8.0 ? null : _zoomOut,
                  icon: Icon(Icons.remove, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: _currentZoom <= 8.0 ? Colors.grey : Colors.blue,
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade300),
                IconButton(
                  onPressed: _centerOnReports,
                  icon: Icon(Icons.center_focus_strong, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade300),
                IconButton(
                  onPressed: _fitMapToAllPoints,
                  icon: Icon(Icons.zoom_out_map, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getCleanRouteColor(int index) {
    final colors = [
      Colors.red.shade600,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.pink.shade600,
      Colors.brown.shade600,
      Colors.cyan.shade600,
    ];
    return colors[index % colors.length];
  }

  // NEW: Water quality helper methods
  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.green;
      case WaterQualityState.highPh:
        return Colors.orange;
      case WaterQualityState.lowPh:
        return Colors.yellow.shade700;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTemp:
        return Colors.blue;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getWaterQualityIndicatorColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.green;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Colors.orange;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTemp:
        return Colors.lightBlue;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getWaterQualityText(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'Optimum';
      case WaterQualityState.highPh:
        return 'High pH';
      case WaterQualityState.lowPh:
        return 'Low pH';
      case WaterQualityState.highPhTemp:
        return 'High pH & Temp';
      case WaterQualityState.lowTemp:
        return 'Low Temperature';
      case WaterQualityState.lowTempHighPh:
        return 'Low Temp & High pH';
      case WaterQualityState.unknown:
      default:
        return 'Contaminated';
    }
  }

  void _selectRoute(int index) {
    setState(() {
      _selectedRoute = _selectedRoute == index ? null : index;
      _selectedReport = null; // Clear report selection
    });
  }

  // NEW: Select report method
  void _selectReport(ReportModel report) {
    setState(() {
      _selectedReport = _selectedReport?.id == report.id ? null : report;
      _selectedRoute = null; // Clear route selection
    });
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + 1).clamp(8.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
    setState(() => _currentZoom = newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - 1).clamp(8.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
    setState(() => _currentZoom = newZoom);
  }

  void _centerOnReports() {
    // Center on reports and water supplies instead of current location
    if (widget.userReports.isNotEmpty) {
      final firstReport = widget.userReports.first;
      _mapController.move(
        LatLng(firstReport.location.latitude, firstReport.location.longitude),
        15.0,
      );
    } else if (widget.polylineRoutes.isNotEmpty) {
      // Center on first water supply if no reports
      final firstRoute = widget.polylineRoutes.first;
      final destinationDetails = firstRoute['destination_details'] as Map<String, dynamic>? ?? {};
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        _mapController.move(LatLng(lat, lng), 15.0);
      }
    }
    setState(() => _currentZoom = 15.0);
  }

  String _getShortestDistance() {
    if (widget.polylineRoutes.isEmpty) return '0 km';
    final distance = widget.polylineRoutes[0]['distance']?.toStringAsFixed(1) ?? '?';
    return '$distance km';
  }

  // NEW: Calculate bounds including reports (NO CURRENT LOCATION)
  LatLngBounds _calculateMapBoundsWithReports() {
    // Start with first available point instead of current location
    double? minLat, maxLat, minLng, maxLng;
    
    // Include water supply routes
    for (final route in widget.polylineRoutes) {
      final points = route['polyline_points'] as List<dynamic>? ?? [];
      
      for (final point in points) {
        if (point is Map<String, dynamic>) {
          final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
          
          if (lat != 0.0 && lng != 0.0) {
            minLat = (minLat == null) ? lat : (minLat < lat ? minLat : lat);
            maxLat = (maxLat == null) ? lat : (maxLat > lat ? maxLat : lat);
            minLng = (minLng == null) ? lng : (minLng < lng ? minLng : lng);
            maxLng = (maxLng == null) ? lng : (maxLng > lng ? maxLng : lng);
          }
        }
      }
    }
    
    // Include user reports
    for (final report in widget.userReports) {
      final lat = report.location.latitude;
      final lng = report.location.longitude;
      
      minLat = (minLat == null) ? lat : (minLat < lat ? minLat : lat);
      maxLat = (maxLat == null) ? lat : (maxLat > lat ? maxLat : lat);
      minLng = (minLng == null) ? lng : (minLng < lng ? minLng : lng);
      maxLng = (maxLng == null) ? lng : (maxLng > lng ? maxLng : lng);
    }
    
    // Fallback to current location if no other points
    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      minLat = widget.currentLocation.latitude;
      maxLat = widget.currentLocation.latitude;
      minLng = widget.currentLocation.longitude;
      maxLng = widget.currentLocation.longitude;
    }
    
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(height: 16),
                Text('Loading Water Network...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOverlay() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 100, color: Colors.grey.shade400),
            SizedBox(height: 24),
            Text(
              'No Reports or Water Supplies',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'No user reports or water supplies found.\nCreate a report or check water supply data.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}