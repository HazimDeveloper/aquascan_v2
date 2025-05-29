// lib/screens/admin/route_optimization_screen.dart - FIXED VERSION
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
import '../../widgets/admin/map_widget.dart';

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
  
  // Debug logging
  final bool _debugMode = true;
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('📱 RouteOptimization: $message');
    }
  }
  
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
      _logDebug('Starting to load initial data...');
      
      // Get current location
      _logDebug('Getting current location...');
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final currentLocation = GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _logDebug('Location obtained: ${position.latitude}, ${position.longitude}');
        
        // Get unresolved reports
        _logDebug('Fetching unresolved reports...');
        final reports = await _databaseService.getUnresolvedReportsList();
        _logDebug('Found ${reports.length} unresolved reports');
        
        setState(() {
          _currentLocation = currentLocation;
          _allReports = reports;
          _isLoading = false;
        });
        
        _animationController.forward();
        _logDebug('Initial data loaded successfully');
      } else {
        setState(() {
          _errorMessage = 'Failed to get current location. Please check location permissions.';
          _isLoading = false;
        });
        _logDebug('Failed to get location - position is null');
      }
    } catch (e) {
      _logDebug('Error loading initial data: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _optimizeRoute() async {
    if (_selectedReports.isEmpty) {
      _logDebug('No reports selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one water point'),
        ),
      );
      return;
    }
    
    if (_currentLocation == null) {
      _logDebug('Current location is null');
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
      _logDebug('Starting route optimization...');
      _logDebug('Selected reports: ${_selectedReports.length}');
      _logDebug('Current location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      _logDebug('Admin ID: ${_authService.currentUser!.uid}');
      
      // Check API service availability first
      final apiBaseUrl = _apiService.baseUrl;
      _logDebug('API base URL: $apiBaseUrl');
      
      // Simple connectivity test
      try {
        final testResponse = await _testApiConnectivity();
        if (!testResponse) {
          throw Exception('API server is not reachable. Please check your connection and try again.');
        }
      } catch (e) {
        _logDebug('API connectivity test failed: $e');
        throw Exception('Cannot connect to the route optimization service. Please check your internet connection.');
      }
      
      // Call API to optimize route
      _logDebug('Calling API service for route optimization...');
      final routeData = await _apiService.getOptimizedRoute(
        _selectedReports,
        _currentLocation!,
        _authService.currentUser!.uid,
      );
      
      _logDebug('Received route data from API');
      _logDebug('Route data keys: ${routeData.keys.toList()}');
      
      // Process API response with enhanced error handling
      final processedData = _processRouteData(routeData);
      _logDebug('Route data processed successfully');
      
      // Create RouteModel with comprehensive error handling
      RouteModel optimizedRoute;
      try {
        optimizedRoute = RouteModel.fromJson(processedData);
        _logDebug('RouteModel created successfully');
      } catch (e) {
        _logDebug('Error creating RouteModel from JSON: $e');
        _logDebug('Attempting manual route model creation...');
        
        // Manually construct RouteModel with fallback data
        optimizedRoute = _createFallbackRouteModel(processedData);
        _logDebug('Fallback RouteModel created');
      }
      
      setState(() {
        _optimizedRoute = optimizedRoute;
        _isOptimizing = false;
        _showMap = true; // Switch to map view
      });
      
      // Save route to database with error handling
      try {
        _logDebug('Saving route to database...');
        await _databaseService.createRoute(processedData);
        _logDebug('Route saved to database successfully');
      } catch (dbError) {
        _logDebug('Warning: Failed to save route to database: $dbError');
        // Don't fail the entire operation if database save fails
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Closest water supply found successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logDebug('Error in route optimization: $e');
      setState(() {
        _errorMessage = _getUserFriendlyErrorMessage(e.toString());
        _isOptimizing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getUserFriendlyErrorMessage(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  // Test API connectivity
  Future<bool> _testApiConnectivity() async {
    try {
      _logDebug('Testing API connectivity...');
      // This is a simple test - you might want to implement a dedicated health check endpoint
      final healthResponse = await _apiService.testConnection();
      _logDebug('API connectivity test result: $healthResponse');
      return healthResponse;
    } catch (e) {
      _logDebug('API connectivity test failed: $e');
      return false;
    }
  }
  
  // Process route data with enhanced validation
  Map<String, dynamic> _processRouteData(Map<String, dynamic> data) {
    _logDebug('Processing route data...');
    var result = Map<String, dynamic>.from(data);
    
    // Ensure required fields exist
    if (!result.containsKey('id') || result['id'] == null) {
      result['id'] = 'route-${DateTime.now().millisecondsSinceEpoch}';
    }
    
    if (!result.containsKey('adminId') || result['adminId'] == null) {
      result['adminId'] = _authService.currentUser?.uid ?? '';
    }
    
    if (!result.containsKey('reportIds') || result['reportIds'] == null) {
      result['reportIds'] = _selectedReports.map((r) => r.id).toList();
    }
    
    if (!result.containsKey('totalDistance') || result['totalDistance'] == null) {
      result['totalDistance'] = 0.0;
    }
    
    // Convert timestamps with better error handling
    try {
      result['createdAt'] = DateTime.now();
      result['updatedAt'] = DateTime.now();
    } catch (e) {
      _logDebug('Error setting timestamps: $e');
      result['createdAt'] = DateTime.now();
      result['updatedAt'] = DateTime.now();
    }
    
    // Validate and fix points array
    if (!result.containsKey('points') || result['points'] == null) {
      result['points'] = [];
    }
    
    // Validate and fix segments array
    if (!result.containsKey('segments') || result['segments'] == null) {
      result['segments'] = [];
    }
    
    _logDebug('Route data processing completed');
    return result;
  }
  
  // Create fallback route model when JSON parsing fails
  RouteModel _createFallbackRouteModel(Map<String, dynamic> data) {
    _logDebug('Creating fallback route model...');
    
    return RouteModel(
      id: data['id']?.toString() ?? 'fallback-${DateTime.now().millisecondsSinceEpoch}',
      adminId: data['adminId']?.toString() ?? _authService.currentUser?.uid ?? '',
      reportIds: _selectedReports.map((r) => r.id).toList(),
      points: [], // Empty for now
      segments: [], // Empty for now
      totalDistance: _getTotalDistanceFromData(data),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  // Extract total distance from data
  double _getTotalDistanceFromData(Map<String, dynamic> data) {
    try {
      if (data.containsKey('totalDistance')) {
        return double.tryParse(data['totalDistance'].toString()) ?? 0.0;
      }
      if (data.containsKey('total_distance')) {
        return double.tryParse(data['total_distance'].toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      _logDebug('Error extracting total distance: $e');
      return 0.0;
    }
  }
  
  // Convert technical error messages to user-friendly ones
  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('Not Found') || error.contains('404')) {
      return 'The water supply service is currently unavailable. Please try again later.';
    } else if (error.contains('Connection') || error.contains('network')) {
      return 'Please check your internet connection and try again.';
    } else if (error.contains('timeout') || error.contains('Timeout')) {
      return 'The request took too long. Please try again.';
    } else if (error.contains('server') || error.contains('500')) {
      return 'The server is experiencing issues. Please try again in a few minutes.';
    } else if (error.contains('water supplies')) {
      return 'No water supplies found in your area. Try selecting different locations.';
    } else {
      return 'Unable to find water supplies. Please try again or contact support.';
    }
  }
  
  void _toggleReportSelection(ReportModel report) {
    setState(() {
      if (_isReportSelected(report)) {
        _selectedReports.removeWhere((r) => r.id == report.id);
        _logDebug('Deselected report: ${report.title}');
      } else {
        _selectedReports.add(report);
        _logDebug('Selected report: ${report.title}');
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
        _logDebug('Deselected all reports');
      } else {
        // Select all
        _selectedReports = List.from(_allReports);
        _logDebug('Selected all ${_selectedReports.length} reports');
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Try Again',
              onPressed: _loadInitialData,
              icon: Icons.refresh,
              type: CustomButtonType.primary,
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Check Connection',
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final isConnected = await _testApiConnectivity();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isConnected 
                          ? 'Connection successful!' 
                          : 'Cannot connect to server'),
                        backgroundColor: isConnected ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Connection test failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              type: CustomButtonType.outline,
            ),
          ],
        ),
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
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status information
                if (_selectedReports.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedReports.length} location${_selectedReports.length == 1 ? '' : 's'} selected',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Main action button
                CustomButton(
                  text: _optimizedRoute == null
                      ? 'Find Closest Water Supply'
                      : 'Recalculate Routes',
                  onPressed: _selectedReports.isEmpty ? null : _optimizeRoute,
                  icon: Icons.water_drop,
                  isFullWidth: true,
                  type: CustomButtonType.primary,
                ),
              ],
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