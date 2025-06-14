// lib/widgets/simplified/openstreet_map_widget.dart - CLEAN REDESIGN
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
  bool _showRouteInfo = true;
  bool _showAllMarkers = false;
  bool _showRouteLines = true;
  int? _selectedRoute;
  double _currentZoom = 12.0;
  
  // Display settings
  int _maxVisibleMarkers = 10; // Show only top 10 by default
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.polylineRoutes.isNotEmpty) {
        _fitMapToRoutes();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitMapToRoutes() {
    try {
      final bounds = _calculateMapBounds();
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
        if (!widget.isLoading && widget.polylineRoutes.isEmpty) _buildEmptyOverlay(),
        
        // Clean header controls
        if (widget.polylineRoutes.isNotEmpty) _buildCleanHeader(),
        
        // Zoom and view controls
        if (widget.polylineRoutes.isNotEmpty) _buildViewControls(),
        
        // Clean route information panel
        if (_showRouteInfo && widget.polylineRoutes.isNotEmpty) _buildCleanRoutePanel(),
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
              // Auto adjust visible markers based on zoom
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
        
        // Clean Polylines
        if (_showRouteLines)
          PolylineLayer(
            polylines: _buildCleanPolylines(),
          ),
        
        // Clean Markers
        MarkerLayer(
          markers: _buildCleanMarkers(),
        ),
      ],
    );
  }

  Widget _buildCleanHeader() {
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
                // Main info row
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
                            'Water Supply Network',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.polylineRoutes.length} locations • ${_getShortestDistance()} to nearest',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // View toggle button
                    _buildViewToggle(),
                  ],
                ),
                
                // Quick stats (only when not minimized)
                if (!_isMinimized) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat('Showing', _showAllMarkers ? '${widget.polylineRoutes.length}' : '$_maxVisibleMarkers', Colors.blue),
                      _buildQuickStat('Nearest', _getShortestDistance(), Colors.green),
                      _buildQuickStat('Zoom', '${_currentZoom.toInt()}x', Colors.orange),
                      _buildQuickStat('Coverage', 'All Areas', Colors.purple),
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
              Text(_showRouteLines ? 'Hide Routes' : 'Show Routes'),
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

  Widget _buildViewControls() {
    return Positioned(
      bottom: _showRouteInfo ? 220 : 100,
      right: 16,
      child: Column(
        children: [
          // Zoom level indicator
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
          
          // Zoom controls
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                // Zoom In
                IconButton(
                  onPressed: _currentZoom >= 18.0 ? null : _zoomIn,
                  icon: Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: _currentZoom >= 18.0 ? Colors.grey : Colors.blue,
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade300),
                // Zoom Out
                IconButton(
                  onPressed: _currentZoom <= 8.0 ? null : _zoomOut,
                  icon: Icon(Icons.remove, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: _currentZoom <= 8.0 ? Colors.grey : Colors.blue,
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade300),
                // Center
                IconButton(
                  onPressed: _centerOnLocation,
                  icon: Icon(Icons.my_location, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade300),
                // Fit all
                IconButton(
                  onPressed: _fitMapToRoutes,
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

  List<Polyline> _buildCleanPolylines() {
    List<Polyline> polylines = [];
    
    // Only show routes for selected or top routes
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

  List<Marker> _buildCleanMarkers() {
    List<Marker> markers = [];
    
    // Current location marker - always visible
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
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.person_pin,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
    
    // Water supply markers - limited and clean
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
              // Priority indicator for top 3
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

  Widget _buildCleanRoutePanel() {
    if (_isMinimized) return Container();
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: 180),
          child: Column(
            children: [
              // Clean header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.route, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Route Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Spacer(),
                    Text(
                      _showAllMarkers ? '${widget.polylineRoutes.length} total' : 'Top $_maxVisibleMarkers',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showRouteInfo = false),
                      child: Icon(Icons.close, size: 16, color: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),
              
              // Clean routes list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _showAllMarkers ? widget.polylineRoutes.length : _maxVisibleMarkers,
                  itemBuilder: (context, index) {
                    if (index >= widget.polylineRoutes.length) return Container();
                    
                    final route = widget.polylineRoutes[index];
                    return _buildCleanRouteItem(route, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanRouteItem(Map<String, dynamic> route, int index) {
    final distance = route['distance']?.toStringAsFixed(1) ?? '?';
    final travelTime = route['travel_time'] ?? '? min';
    final destinationName = route['destination_name'] ?? 'Water Supply ${index + 1}';
    final isSelected = _selectedRoute == index;
    final isTop3 = index < 3;
    
    return GestureDetector(
      onTap: () => _selectRoute(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blue.shade100 
              : (isTop3 ? Colors.grey.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Colors.blue.shade300 
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // Clean route indicator
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getCleanRouteColor(index),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isTop3
                    ? Icon(
                        index == 0 ? Icons.star : Icons.water_drop,
                        color: Colors.white,
                        size: 16,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            SizedBox(width: 12),
            
            // Route info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destinationName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isTop3 ? Colors.black87 : Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.straighten, size: 12, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Text(
                        '$distance km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Text(
                        travelTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              Icon(Icons.visibility, color: Colors.blue, size: 16),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getCleanRouteColor(int index) {
    final colors = [
      Colors.red.shade600,      // #1 - Red (closest)
      Colors.blue.shade600,     // #2 - Blue
      Colors.green.shade600,    // #3 - Green
      Colors.orange.shade600,   // #4 - Orange
      Colors.purple.shade600,   // #5 - Purple
      Colors.teal.shade600,     // #6 - Teal
      Colors.indigo.shade600,   // #7 - Indigo
      Colors.pink.shade600,     // #8 - Pink
      Colors.brown.shade600,    // #9 - Brown
      Colors.cyan.shade600,     // #10 - Cyan
    ];
    return colors[index % colors.length];
  }

  void _selectRoute(int index) {
    setState(() {
      _selectedRoute = _selectedRoute == index ? null : index;
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

  void _centerOnLocation() {
    _mapController.move(
      LatLng(widget.currentLocation.latitude, widget.currentLocation.longitude),
      15.0,
    );
    setState(() => _currentZoom = 15.0);
  }

  String _getShortestDistance() {
    if (widget.polylineRoutes.isEmpty) return '0 km';
    final distance = widget.polylineRoutes[0]['distance']?.toStringAsFixed(1) ?? '?';
    return '$distance km';
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
          
          if (lat != 0.0 && lng != 0.0) {
            minLat = minLat < lat ? minLat : lat;
            maxLat = maxLat > lat ? maxLat : lat;
            minLng = minLng < lng ? minLng : lng;
            maxLng = maxLng > lng ? maxLng : lng;
          }
        }
      }
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
                Text('Loading Water Supply Network...'),
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
              'No Water Supply Routes Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'No water supply routes available in your area.\nTry refreshing or check your location.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}