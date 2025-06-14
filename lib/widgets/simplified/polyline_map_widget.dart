// lib/widgets/simplified/polyline_map_widget.dart
import 'package:flutter/material.dart';
import 'dart:math' as Math;
import '../../config/theme.dart';
import '../../models/report_model.dart';

class PolylineMapWidget extends StatefulWidget {
  final GeoPoint currentLocation;
  final List<Map<String, dynamic>> polylineRoutes;
  final bool isLoading;

  const PolylineMapWidget({
    Key? key,
    required this.currentLocation,
    required this.polylineRoutes,
    this.isLoading = false,
  }) : super(key: key);

  @override
  _PolylineMapWidgetState createState() => _PolylineMapWidgetState();
}

class _PolylineMapWidgetState extends State<PolylineMapWidget> {
  int? _selectedRouteIndex;
  bool _showAllRoutes = true;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls
        _buildMapControls(),
        
        // Map area
        Expanded(
          child: widget.isLoading 
              ? _buildLoadingView()
              : widget.polylineRoutes.isEmpty 
                  ? _buildEmptyView()
                  : _buildMapView(),
        ),
        
        // Route legend
        if (widget.polylineRoutes.isNotEmpty && _showAllRoutes)
          _buildRouteLegend(),
      ],
    );
  }
  
  Widget _buildMapControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedRouteIndex != null
                  ? 'Showing: ${widget.polylineRoutes[_selectedRouteIndex!]['destination_name']}'
                  : 'Showing: All ${widget.polylineRoutes.length} routes',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Toggle all routes
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showAllRoutes = !_showAllRoutes;
                if (!_showAllRoutes && _selectedRouteIndex == null) {
                  _selectedRouteIndex = 0; // Show first route
                } else if (_showAllRoutes) {
                  _selectedRouteIndex = null;
                }
              });
            },
            icon: Icon(
              _showAllRoutes ? Icons.visibility : Icons.visibility_off,
              size: 16,
            ),
            label: Text(
              _showAllRoutes ? 'Show One' : 'Show All',
              style: TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading water supply routes...',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Routes Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No water supply routes found in your area',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Map background
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.blue.shade50,
            ),
            
            // Custom painted map with routes
            CustomPaint(
              size: Size.infinite,
              painter: PolylineMapPainter(
                currentLocation: widget.currentLocation,
                polylineRoutes: widget.polylineRoutes,
                selectedRouteIndex: _selectedRouteIndex,
                showAllRoutes: _showAllRoutes,
              ),
            ),
            
            // Route selection overlay
            if (!_showAllRoutes) _buildRouteSelector(),
            
            // Current location indicator
            _buildCurrentLocationIndicator(),
            
            // Map scale/compass
            _buildMapInfo(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurrentLocationIndicator() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'You are here',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapInfo() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore, color: Colors.orange, size: 16),
            SizedBox(height: 2),
            Text(
              'N',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRouteSelector() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        constraints: BoxConstraints(maxWidth: 200),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Route',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  height: 120,
                  child: ListView.builder(
                    itemCount: widget.polylineRoutes.length,
                    itemBuilder: (context, index) {
                      final route = widget.polylineRoutes[index];
                      final isSelected = _selectedRouteIndex == index;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRouteIndex = index;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 4),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange.shade100 : null,
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected 
                                ? Border.all(color: Colors.orange)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getRouteColor(index),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Route ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRouteLegend() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.legend_toggle, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Route Legend',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${widget.polylineRoutes.length} routes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: Math.min(widget.polylineRoutes.length, 8),
                  itemBuilder: (context, index) {
                    final route = widget.polylineRoutes[index];
                    final isShortest = index == 0;
                    
                    return Container(
                      width: 100,
                      margin: EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: _getRouteColor(index),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 4),
                              if (isShortest)
                                Icon(Icons.star, color: Colors.red, size: 12),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            isShortest ? 'Shortest' : 'Route ${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isShortest ? FontWeight.bold : FontWeight.normal,
                              color: isShortest ? Colors.red : Colors.black87,
                            ),
                          ),
                          Text(
                            '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getRouteColor(int index) {
    final colors = [
      Colors.red,      // Shortest route
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }
}

class PolylineMapPainter extends CustomPainter {
  final GeoPoint currentLocation;
  final List<Map<String, dynamic>> polylineRoutes;
  final int? selectedRouteIndex;
  final bool showAllRoutes;
  
  PolylineMapPainter({
    required this.currentLocation,
    required this.polylineRoutes,
    this.selectedRouteIndex,
    required this.showAllRoutes,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (polylineRoutes.isEmpty) return;
    
    // Calculate bounds for all routes
    final bounds = _calculateBounds();
    
    // Draw routes
    if (showAllRoutes) {
      _drawAllRoutes(canvas, size, bounds);
    } else if (selectedRouteIndex != null) {
      _drawSingleRoute(canvas, size, bounds, selectedRouteIndex!);
    }
    
    // Draw current location
    _drawCurrentLocation(canvas, size, bounds);
    
    // Draw destination markers
    _drawDestinationMarkers(canvas, size, bounds);
  }
  
  MapBounds _calculateBounds() {
    double minLat = currentLocation.latitude;
    double maxLat = currentLocation.latitude;
    double minLng = currentLocation.longitude;
    double maxLng = currentLocation.longitude;
    
    for (final route in polylineRoutes) {
      final points = route['polyline_points'] as List<dynamic>? ?? [];
      
      for (final point in points) {
        if (point is Map<String, dynamic>) {
          final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
          
          minLat = Math.min(minLat, lat);
          maxLat = Math.max(maxLat, lat);
          minLng = Math.min(minLng, lng);
          maxLng = Math.max(maxLng, lng);
        }
      }
    }
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    return MapBounds(
      minLat: minLat - latPadding,
      maxLat: maxLat + latPadding,
      minLng: minLng - lngPadding,
      maxLng: maxLng + lngPadding,
    );
  }
  
  void _drawAllRoutes(Canvas canvas, Size size, MapBounds bounds) {
    for (int i = 0; i < polylineRoutes.length; i++) {
      _drawRoute(canvas, size, bounds, i, alpha: 0.8);
    }
  }
  
  void _drawSingleRoute(Canvas canvas, Size size, MapBounds bounds, int routeIndex) {
    // Draw other routes faded
    for (int i = 0; i < polylineRoutes.length; i++) {
      if (i != routeIndex) {
        _drawRoute(canvas, size, bounds, i, alpha: 0.2);
      }
    }
    
    // Draw selected route highlighted
    _drawRoute(canvas, size, bounds, routeIndex, alpha: 1.0, strokeWidth: 4.0);
  }
  
  void _drawRoute(Canvas canvas, Size size, MapBounds bounds, int routeIndex, {double alpha = 1.0, double strokeWidth = 3.0}) {
    final route = polylineRoutes[routeIndex];
    final points = route['polyline_points'] as List<dynamic>? ?? [];
    
    if (points.length < 2) return;
    
    final color = _getRouteColor(routeIndex).withOpacity(alpha);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    bool firstPoint = true;
    
    for (final point in points) {
      if (point is Map<String, dynamic>) {
        final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
        
        final screenPoint = _geoToScreen(lat, lng, size, bounds);
        
        if (firstPoint) {
          path.moveTo(screenPoint.dx, screenPoint.dy);
          firstPoint = false;
        } else {
          path.lineTo(screenPoint.dx, screenPoint.dy);
        }
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawCurrentLocation(Canvas canvas, Size size, MapBounds bounds) {
    final screenPoint = _geoToScreen(
      currentLocation.latitude,
      currentLocation.longitude,
      size,
      bounds,
    );
    
    // Outer circle
    final outerPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenPoint, 12, outerPaint);
    
    // Inner circle
    final innerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenPoint, 6, innerPaint);
    
    // Center dot
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenPoint, 2, centerPaint);
  }
  
  void _drawDestinationMarkers(Canvas canvas, Size size, MapBounds bounds) {
    for (int i = 0; i < polylineRoutes.length; i++) {
      final route = polylineRoutes[i];
      final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
      
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final screenPoint = _geoToScreen(lat, lng, size, bounds);
        
        // Marker background
        final markerPaint = Paint()
          ..color = _getRouteColor(i)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(screenPoint, 8, markerPaint);
        
        // Marker border
        final borderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(screenPoint, 8, borderPaint);
        
        // Water drop icon (simplified)
        final iconPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(screenPoint, 3, iconPaint);
      }
    }
  }
  
  Offset _geoToScreen(double lat, double lng, Size size, MapBounds bounds) {
    final x = (lng - bounds.minLng) / (bounds.maxLng - bounds.minLng) * size.width;
    final y = (bounds.maxLat - lat) / (bounds.maxLat - bounds.minLat) * size.height;
    return Offset(x, y);
  }
  
  Color _getRouteColor(int index) {
    final colors = [
      Colors.red,      // Shortest route
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MapBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  
  MapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}