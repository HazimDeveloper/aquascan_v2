// lib/widgets/simplified/openstreet_map_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';

class OpenStreetMapWidget extends StatefulWidget {
  final GeoPoint currentLocation;
  final List<Map<String, dynamic>> polylineRoutes;
  final bool isLoading;

  const OpenStreetMapWidget({
    Key? key,
    required this.currentLocation,
    required this.polylineRoutes,
    this.isLoading = false,
  }) : super(key: key);

  @override
  _OpenStreetMapWidgetState createState() => _OpenStreetMapWidgetState();
}

class _OpenStreetMapWidgetState extends State<OpenStreetMapWidget> {
  late MapController _mapController;
  int? _selectedRouteIndex;
  bool _showAllRoutes = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Map controls
        _buildMapControls(),
        
        // Main map
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.map, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedRouteIndex != null
                  ? 'Route ${_selectedRouteIndex! + 1}: ${widget.polylineRoutes[_selectedRouteIndex!]['destination_name'] ?? 'Water Supply'}'
                  : 'Showing ${widget.polylineRoutes.length} water supply routes',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          
          // Toggle all routes button
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllRoutes = !_showAllRoutes;
                  if (!_showAllRoutes && _selectedRouteIndex == null) {
                    _selectedRouteIndex = 0; // Show shortest route first
                  } else if (_showAllRoutes) {
                    _selectedRouteIndex = null;
                  }
                });
              },
              icon: Icon(
                _showAllRoutes ? Icons.layers : Icons.layers_clear,
                size: 16,
                color: Colors.orange,
              ),
              label: Text(
                _showAllRoutes ? 'Show One' : 'Show All',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size(0, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading OpenStreetMap...',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Getting water supply routes',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
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
              'No Routes Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No water supply routes found in your area.\nTry refreshing or check your location.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    // Convert current location to LatLng
    final currentLatLng = LatLng(
      widget.currentLocation.latitude,
      widget.currentLocation.longitude,
    );

    // Calculate map bounds
    final bounds = _calculateMapBounds();
    
    return Stack(
      children: [
        // Main FlutterMap
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentLatLng,
            initialZoom: 13.0,
            minZoom: 10.0,
            maxZoom: 18.0,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // OpenStreetMap tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.aquascan',
              maxZoom: 18,
              errorTileCallback: (tile, error, stackTrace) {
                print('Map tile error: $error');
              },
            ),
            
            // Polyline routes
            PolylineLayer(
              polylines: _buildPolylines(),
            ),
            
            // Markers for current location and water supplies
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),
        
        // Route selector (when showing single route)
        if (!_showAllRoutes) _buildRouteSelector(),
        
        // Zoom controls
        _buildZoomControls(),
        
        // Center on location button
        _buildLocationButton(),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    List<Polyline> polylines = [];
    
    // Determine which routes to show
    List<int> routeIndices = [];
    if (_showAllRoutes) {
      routeIndices = List.generate(widget.polylineRoutes.length, (index) => index);
    } else if (_selectedRouteIndex != null) {
      routeIndices = [_selectedRouteIndex!];
    }
    
    for (int index in routeIndices) {
      if (index < widget.polylineRoutes.length) {
        final route = widget.polylineRoutes[index];
        final polylinePoints = route['polyline_points'] as List<dynamic>? ?? [];
        
        if (polylinePoints.isNotEmpty) {
          // Convert points to LatLng
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
          
          if (latLngPoints.isNotEmpty) {
            polylines.add(
              Polyline(
                points: latLngPoints,
                strokeWidth: index == 0 ? 5.0 : 4.0, // Thicker for shortest route
                color: _getRouteColor(index),
                borderStrokeWidth: index == 0 ? 7.0 : 5.0,
                borderColor: _getRouteColor(index).withOpacity(0.3),
              ),
            );
          }
        }
      }
    }
    
    return polylines;
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];
    
    // Current location marker
    markers.add(
      Marker(
        point: LatLng(
          widget.currentLocation.latitude,
          widget.currentLocation.longitude,
        ),
        width: 60,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.person_pin_circle,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
    
    // Water supply markers
    Set<String> addedLocations = {}; // Prevent duplicate markers
    
    for (int i = 0; i < widget.polylineRoutes.length; i++) {
      final route = widget.polylineRoutes[i];
      final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
      
      final lat = (destinationDetails['latitude'] as num?)?.toDouble();
      final lng = (destinationDetails['longitude'] as num?)?.toDouble();
      
      if (lat != null && lng != null) {
        final locationKey = '$lat,$lng';
        
        if (!addedLocations.contains(locationKey)) {
          addedLocations.add(locationKey);
          
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  _showWaterSupplyInfo(route, i);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _getRouteColor(i),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.water_drop,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (i == 0) // Show star for shortest route
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.yellow,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    
    return markers;
  }

  LatLngBounds _calculateMapBounds() {
    double minLat = widget.currentLocation.latitude;
    double maxLat = widget.currentLocation.latitude;
    double minLng = widget.currentLocation.longitude;
    double maxLng = widget.currentLocation.longitude;
    
    for (final route in widget.polylineRoutes) {
      final points = route['polyline_points'] as List<dynamic>? ?? [];
      
      for (final point in points) {
        if (point is Map<String, dynamic>) {
          final lat = (point['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (point['longitude'] as num?)?.toDouble() ?? 0.0;
          
          minLat = minLat < lat ? minLat : lat;
          maxLat = maxLat > lat ? maxLat : lat;
          minLng = minLng < lng ? minLng : lng;
          maxLng = maxLng > lng ? maxLng : lng;
        }
      }
    }
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  Widget _buildRouteSelector() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        width: 200,
        constraints: BoxConstraints(maxHeight: 200),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Select Route',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.polylineRoutes.length,
                    itemBuilder: (context, index) {
                      final route = widget.polylineRoutes[index];
                      final isSelected = _selectedRouteIndex == index;
                      final isShortest = index == 0;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRouteIndex = index;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.orange.shade100 
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.orange 
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getRouteColor(index),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: isShortest 
                                    ? Icon(Icons.star, color: Colors.white, size: 10)
                                    : null,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isShortest 
                                          ? 'Shortest Route' 
                                          : 'Route ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isShortest ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${route['distance']?.toStringAsFixed(1) ?? '?'} km',
                                      style: TextStyle(
                                        fontSize: 11,
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

  Widget _buildZoomControls() {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_in",
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange,
            child: Icon(Icons.add),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_out",
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange,
            child: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButton() {
    return Positioned(
      bottom: 20,
      right: 16,
      child: FloatingActionButton(
        mini: true,
        heroTag: "center_location",
        onPressed: () {
          final bounds = _calculateMapBounds();
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: EdgeInsets.all(50),
            ),
          );
        },
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: Icon(Icons.center_focus_strong),
      ),
    );
  }

  Widget _buildRouteLegend() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.legend_toggle, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Water Supply Routes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.polylineRoutes.length} routes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.polylineRoutes.length,
                  itemBuilder: (context, index) {
                    final route = widget.polylineRoutes[index];
                    final isShortest = index == 0;
                    final distance = route['distance']?.toStringAsFixed(1) ?? '?';
                    final travelTime = route['travel_time'] ?? '? min';
                    
                    return Container(
                      width: 120,
                      margin: EdgeInsets.only(right: 12),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getRouteColor(index).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getRouteColor(index).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _getRouteColor(index),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 4),
                              if (isShortest)
                                Icon(Icons.star, color: Colors.red, size: 14),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            isShortest ? 'Shortest Route' : 'Route ${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isShortest ? Colors.red : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '$distance km',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            travelTime,
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
      Colors.red,        // Shortest route - Red
      Colors.blue,       // Route 2 - Blue  
      Colors.green,      // Route 3 - Green
      Colors.orange,     // Route 4 - Orange
      Colors.purple,     // Route 5 - Purple
      Colors.pink,       // Route 6 - Pink
      Colors.teal,       // Route 7 - Teal
      Colors.indigo,     // Route 8 - Indigo
    ];
    return colors[index % colors.length];
  }

  void _showWaterSupplyInfo(Map<String, dynamic> route, int routeIndex) {
    final destinationDetails = route['destination_details'] as Map<String, dynamic>? ?? {};
    final isShortest = routeIndex == 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getRouteColor(routeIndex),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.water_drop, color: Colors.white, size: 16),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                isShortest ? 'Shortest Route' : 'Route ${routeIndex + 1}',
                style: TextStyle(fontSize: 16),
              ),
            ),
            if (isShortest)
              Icon(Icons.star, color: Colors.red, size: 20),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.location_on, 'Location', 
                destinationDetails['street_name'] ?? 'Water Supply Point'),
            _buildInfoRow(Icons.home, 'Address', 
                destinationDetails['address'] ?? 'Unknown Address'),
            _buildInfoRow(Icons.place, 'Point of Interest', 
                destinationDetails['point_of_interest'] ?? 'Water Access Point'),
            _buildInfoRow(Icons.straighten, 'Distance', 
                '${route['distance']?.toStringAsFixed(1) ?? '?'} km'),
            _buildInfoRow(Icons.access_time, 'Travel Time', 
                route['travel_time'] ?? 'Unknown'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _selectedRouteIndex = routeIndex;
                _showAllRoutes = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRouteColor(routeIndex),
              foregroundColor: Colors.white,
            ),
            child: Text('Focus Route'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}