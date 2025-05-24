// lib/screens/admin/route_optimization_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../models/route_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../widgets/common/custom_loader.dart';
import '../../widgets/common/custom_bottom.dart';
import '../../widgets/admin/map_widget.dart';  // Import the map widget

class RouteOptimizationScreen extends StatefulWidget {
  const RouteOptimizationScreen({Key? key}) : super(key: key);

  @override
  _RouteOptimizationScreenState createState() => _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState extends State<RouteOptimizationScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isOptimizing = false;
  bool _showMap = true;
  List<ReportModel> _allReports = [];
  List<ReportModel> _selectedReports = [];
  RouteModel? _optimizedRoute;
  GeoPoint? _currentLocation;
  String _errorMessage = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AuthService _authService;
  late DatabaseService _databaseService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final currentLocation = GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        
        // Get unresolved reports
        final reports = await _databaseService.getUnresolvedReportsList();
        
        setState(() {
          _currentLocation = currentLocation;
          _allReports = reports;
          _isLoading = false;
        });
        
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = 'Failed to get current location. Please check location permissions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _optimizeRoute() async {
    if (_selectedReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one water point'),
        ),
      );
      return;
    }
    
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location is required'),
        ),
      );
      return;
    }
    
    setState(() {
      _isOptimizing = true;
      _errorMessage = '';
    });
    
    try {
      // Call API to optimize route
      final routeData = await _apiService.getOptimizedRoute(
        _selectedReports,
        _currentLocation!,
        _authService.currentUser!.uid,
      );
      
      // Process API response and convert to RouteModel
      final processedData = _convertTimestamps(routeData as Map<String, dynamic>);
      
      // Create RouteModel with proper error handling
      RouteModel optimizedRoute;
      try {
        optimizedRoute = RouteModel.fromJson(processedData);
      } catch (e) {
        print('Error creating RouteModel: $e');
        
        // Manually construct RouteModel
        optimizedRoute = _manuallyCreateRouteModel(processedData);
      }
      
      setState(() {
        _optimizedRoute = optimizedRoute;
        _isOptimizing = false;
        _showMap = true; // Switch to map view
      });
      
      // Save route to database
      await _databaseService.createRoute(routeData as Map<String, dynamic>);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route optimized successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error optimizing route: $e';
        _isOptimizing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $_errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Helper to convert timestamps in the route data
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    var result = Map<String, dynamic>.from(data);
    
    // Convert timestamp strings to DateTime
    if (result.containsKey('createdAt')) {
      try {
        if (result['createdAt'] is String) {
          result['createdAt'] = DateTime.parse(result['createdAt']);
        } else if (result['createdAt'] is int) {
          result['createdAt'] = DateTime.fromMillisecondsSinceEpoch(result['createdAt']);
        }
      } catch (e) {
        print('Error converting createdAt: $e');
        result['createdAt'] = DateTime.now();
      }
    } else {
      result['createdAt'] = DateTime.now();
    }
    
    if (result.containsKey('updatedAt')) {
      try {
        if (result['updatedAt'] is String) {
          result['updatedAt'] = DateTime.parse(result['updatedAt']);
        } else if (result['updatedAt'] is int) {
          result['updatedAt'] = DateTime.fromMillisecondsSinceEpoch(result['updatedAt']);
        }
      } catch (e) {
        print('Error converting updatedAt: $e');
        result['updatedAt'] = DateTime.now();
      }
    } else {
      result['updatedAt'] = DateTime.now();
    }
    
    return result;
  }
  
  // Manually create a RouteModel when fromJson fails
  RouteModel _manuallyCreateRouteModel(Map<String, dynamic> data) {
    List<String> reportIds = [];
    if (data.containsKey('reportIds') && data['reportIds'] is List) {
      reportIds = List<String>.from((data['reportIds'] as List).map((e) => e.toString()));
    }
    
    List<RoutePoint> points = [];
    if (data.containsKey('points') && data['points'] is List) {
      points = (data['points'] as List).map((point) {
        if (point is Map<String, dynamic>) {
          return RoutePoint(
            nodeId: point['nodeId']?.toString() ?? '',
            location: GeoPoint(
              latitude: _getDoubleValue(point['location']?['latitude'], 0),
              longitude: _getDoubleValue(point['location']?['longitude'], 0),
            ),
            address: point['address']?.toString() ?? '',
            label: point['label']?.toString(),
          );
        }
        return RoutePoint(
          nodeId: '',
          location: GeoPoint(latitude: 0, longitude: 0),
          address: '',
        );
      }).toList();
    }
    
    List<RouteSegment> segments = [];
    if (data.containsKey('segments') && data['segments'] is List) {
      segments = (data['segments'] as List).map((segment) {
        if (segment is Map<String, dynamic>) {
          // Process 'from' point
          RoutePoint fromPoint;
          if (segment['from'] is Map<String, dynamic>) {
            var from = segment['from'] as Map<String, dynamic>;
            fromPoint = RoutePoint(
              nodeId: from['nodeId']?.toString() ?? '',
              location: GeoPoint(
                latitude: _getDoubleValue(from['location']?['latitude'], 0),
                longitude: _getDoubleValue(from['location']?['longitude'], 0),
              ),
              address: from['address']?.toString() ?? '',
              label: from['label']?.toString(),
            );
          } else {
            fromPoint = RoutePoint(
              nodeId: '',
              location: GeoPoint(latitude: 0, longitude: 0),
              address: '',
            );
          }
          
          // Process 'to' point
          RoutePoint toPoint;
          if (segment['to'] is Map<String, dynamic>) {
            var to = segment['to'] as Map<String, dynamic>;
            toPoint = RoutePoint(
              nodeId: to['nodeId']?.toString() ?? '',
              location: GeoPoint(
                latitude: _getDoubleValue(to['location']?['latitude'], 0),
                longitude: _getDoubleValue(to['location']?['longitude'], 0),
              ),
              address: to['address']?.toString() ?? '',
              label: to['label']?.toString(),
            );
          } else {
            toPoint = RoutePoint(
              nodeId: '',
              location: GeoPoint(latitude: 0, longitude: 0),
              address: '',
            );
          }
          
          // Process polyline
          List<GeoPoint> polyline = [];
          if (segment['polyline'] is List) {
            polyline = (segment['polyline'] as List).map((point) {
              if (point is Map<String, dynamic>) {
                return GeoPoint(
                  latitude: _getDoubleValue(point['latitude'], 0),
                  longitude: _getDoubleValue(point['longitude'], 0),
                );
              }
              return GeoPoint(latitude: 0, longitude: 0);
            }).toList();
          }
          
          return RouteSegment(
            from: fromPoint,
            to: toPoint,
            distance: _getDoubleValue(segment['distance'], 0),
            polyline: polyline,
          );
        }
        
        // Default segment if parsing fails
        return RouteSegment(
          from: RoutePoint(
            nodeId: '',
            location: GeoPoint(latitude: 0, longitude: 0),
            address: '',
          ),
          to: RoutePoint(
            nodeId: '',
            location: GeoPoint(latitude: 0, longitude: 0),
            address: '',
          ),
          distance: 0,
          polyline: [],
        );
      }).toList();
    }
    
    return RouteModel(
      id: data['id']?.toString() ?? 'route-${DateTime.now().millisecondsSinceEpoch}',
      adminId: data['adminId']?.toString() ?? '',
      reportIds: reportIds,
      points: points,
      segments: segments,
      totalDistance: _getDoubleValue(data['totalDistance'], 0),
      createdAt: data['createdAt'] ?? DateTime.now(),
      updatedAt: data['updatedAt'] ?? DateTime.now(),
    );
  }
  
  // Helper to safely convert to double
  double _getDoubleValue(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
  
  void _toggleReportSelection(ReportModel report) {
    setState(() {
      if (_isReportSelected(report)) {
        _selectedReports.removeWhere((r) => r.id == report.id);
      } else {
        _selectedReports.add(report);
      }
      
      // Reset optimized route when selection changes
      _optimizedRoute = null;
    });
  }
  
  bool _isReportSelected(ReportModel report) {
    return _selectedReports.any((r) => r.id == report.id);
  }
  
  void _toggleViewMode() {
    setState(() {
      _showMap = !_showMap;
    });
  }
  
  void _selectAllReports() {
    setState(() {
      if (_selectedReports.length == _allReports.length) {
        // Deselect all
        _selectedReports.clear();
      } else {
        // Select all
        _selectedReports = List.from(_allReports);
      }
      
      // Reset optimized route
      _optimizedRoute = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Closest Water Supply Finder'),
        actions: [
          // Toggle view button
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: _toggleViewMode,
            tooltip: _showMap ? 'Show List' : 'Show Map',
          ),
          
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: WaterDropLoader(
                message: 'Getting location and reports...',
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _showMap
                  ? _buildMapView()
                  : _buildListView(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: AppTheme.errorColor.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Try Again',
            onPressed: _loadInitialData,
            icon: Icons.refresh,
            type: CustomButtonType.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Map takes most of the screen
          Expanded(
            child: RouteMapWidget(
              routeModel: _optimizedRoute,
              reports: _allReports,
              selectedReports: _selectedReports,
              currentLocation: _currentLocation,
              onReportTap: _toggleReportSelection,
              showSelectionStatus: true,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildListView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Selection header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Water Points (${_selectedReports.length}/${_allReports.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _selectAllReports,
                  child: Text(
                    _selectedReports.length == _allReports.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
          ),
          
          // Reports list
          Expanded(
            child: _allReports.isEmpty
                ? _buildEmptyReportsList()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _allReports.length,
                    itemBuilder: (context, index) {
                      final report = _allReports[index];
                      return _buildReportItem(report);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyReportsList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Water Points Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing or adding new water points',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Refresh',
            onPressed: _loadInitialData,
            icon: Icons.refresh,
            type: CustomButtonType.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportItem(ReportModel report) {
    final isSelected = _isReportSelected(report);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _toggleReportSelection(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected 
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? AppTheme.primaryColor
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              // Report info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title.isNotEmpty ? report.title : 'Water Supply Point',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.address,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getWaterQualityColor(report.waterQuality).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getWaterQualityColor(report.waterQuality),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getWaterQualityText(report.waterQuality),
                            style: TextStyle(
                              color: _getWaterQualityColor(report.waterQuality),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
  
 Widget _buildBottomBar() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    child: _isOptimizing
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Finding closest water supply points...'),
              ],
            ),
          )
        : CustomButton(
            text: _optimizedRoute == null
                ? 'Find Closest Water Supply'
                : 'Recalculate Routes',
            onPressed: _selectedReports.isEmpty ? null : _optimizeRoute,
            icon: Icons.water_drop,
            isFullWidth: true,
            type: CustomButtonType.primary,
          ),
  );
}
  
 String _getWaterQualityText(WaterQualityState quality) {
  switch (quality) {
    case WaterQualityState.optimum:
      return 'Optimum';
    case WaterQualityState.highPh:
      return 'High pH';
    case WaterQualityState.highPhTemp:
      return 'High pH & Temp';
    case WaterQualityState.lowPh:
      return 'Low pH';
    case WaterQualityState.lowTemp:
      return 'Low Temperature';
    case WaterQualityState.lowTempHighPh:
      return 'Low Temp & High pH';
    case WaterQualityState.unknown:
    default:
      return 'Unknown';
  }
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