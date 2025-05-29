// lib/screens/admin/route_optimization_screen.dart - ENHANCED with GA Parameters
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
  bool _showAdvancedSettings = false;
  List<ReportModel> _allReports = [];
  List<ReportModel> _selectedReports = [];
  RouteModel? _optimizedRoute;
  GeoPoint? _currentLocation;
  String _errorMessage = '';
  
  // Genetic Algorithm Parameters (matching Python system_tester)
  int _populationSize = 50;
  int _generations = 100;
  double _mutationRate = 0.1;
  double _crossoverRate = 0.8;
  int _maxPoints = 8;
  
  // GA Results tracking
  double? _bestFitness;
  double? _averageFitness;
  int? _completedGenerations;
  String? _algorithmDetails;
  List<double> _fitnessHistory = [];
  
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
      _bestFitness = null;
      _averageFitness = null;
      _completedGenerations = null;
      _algorithmDetails = null;
      _fitnessHistory.clear();
    });
    
    try {
      _logDebug('Starting GA route optimization...');
      _logDebug('GA Parameters:');
      _logDebug('  Population Size: $_populationSize');
      _logDebug('  Generations: $_generations');
      _logDebug('  Mutation Rate: $_mutationRate');
      _logDebug('  Crossover Rate: $_crossoverRate');
      _logDebug('  Max Points: $_maxPoints');
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
      
      // Call API to optimize route with GA parameters
      _logDebug('Calling API service for GA route optimization...');
      final routeData = await _getOptimizedRouteWithGA(
        _selectedReports,
        _currentLocation!,
        _authService.currentUser!.uid,
      );
      
      _logDebug('Received route data from GA API');
      _logDebug('Route data keys: ${routeData.keys.toList()}');
      
      // Process API response with enhanced error handling
      final processedData = _processRouteData(routeData);
      _logDebug('Route data processed successfully');
      
      // Extract GA-specific results
      _extractGAResults(routeData);
      
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
      
      // Show success message with GA results
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GA Route optimization completed!'),
                if (_bestFitness != null)
                  Text('Best Fitness: ${_bestFitness!.toStringAsFixed(4)}'),
                if (_completedGenerations != null)
                  Text('Generations: $_completedGenerations/$_generations'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _logDebug('Error in GA route optimization: $e');
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
  
  // Enhanced GA route optimization call with proper API integration
  Future<Map<String, dynamic>> _getOptimizedRouteWithGA(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    // Build GA configuration from UI parameters
    final gaParams = GAParameters(
      populationSize: _populationSize,
      maxGenerations: _generations,
      mutationRate: _mutationRate,
      crossoverRate: _crossoverRate,
      maxRouteLength: _maxPoints,
      timeLimit: 60.0, // Give more time for complex optimizations
      convergenceThreshold: 15,
      eliteSize: (_populationSize * 0.1).round(), // 10% elite
      tournamentSize: 3,
    );
    
    _logDebug('Calling enhanced API service with GA parameters:');
    _logDebug('  Population Size: ${gaParams.populationSize}');
    _logDebug('  Generations: ${gaParams.maxGenerations}');
    _logDebug('  Mutation Rate: ${gaParams.mutationRate}');
    _logDebug('  Crossover Rate: ${gaParams.crossoverRate}');
    _logDebug('  Max Points: ${gaParams.maxRouteLength}');
    _logDebug('  Time Limit: ${gaParams.timeLimit}');
    
    // Call the enhanced API service method
    final response = await _apiService.getOptimizedRouteWithGA(
      reports,
      startLocation,
      adminId,
      gaParams,
    );
    
    return response;
  }
  
  // Extract GA-specific results from the API response
  void _extractGAResults(Map<String, dynamic> routeData) {
    try {
      // Extract optimization stats
      if (routeData.containsKey('optimization_stats')) {
        final stats = routeData['optimization_stats'] as Map<String, dynamic>;
        
        _bestFitness = stats['best_fitness']?.toDouble();
        _averageFitness = stats['average_fitness']?.toDouble();
        _completedGenerations = stats['generations_completed']?.toInt();
        
        // Extract fitness history if available
        if (stats.containsKey('fitness_history') && stats['fitness_history'] is List) {
          _fitnessHistory = (stats['fitness_history'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
        }
      }
      
      // Extract algorithm details
      if (routeData.containsKey('algorithm_details')) {
        final details = routeData['algorithm_details'] as Map<String, dynamic>;
        
        final populationSize = details['population_size'] ?? _populationSize;
        final generations = details['generations_completed'] ?? _completedGenerations ?? 0;
        final evaluations = details['evaluations_performed'] ?? 0;
        final convergenceStatus = details['convergence_status'] ?? 'completed';
        
        _algorithmDetails = 'Pop: $populationSize, Gen: $generations, Eval: $evaluations, Status: $convergenceStatus';
      }
      
      // Extract fitness score from route if available
      if (routeData.containsKey('fitness_score')) {
        _bestFitness = routeData['fitness_score']?.toDouble();
      }
      
      _logDebug('GA Results extracted:');
      _logDebug('  Best Fitness: $_bestFitness');
      _logDebug('  Average Fitness: $_averageFitness');
      _logDebug('  Completed Generations: $_completedGenerations');
      _logDebug('  Fitness History Length: ${_fitnessHistory.length}');
      _logDebug('  Algorithm Details: $_algorithmDetails');
      
    } catch (e) {
      _logDebug('Error extracting GA results: $e');
    }
  }
  
  // Test API connectivity
  Future<bool> _testApiConnectivity() async {
    try {
      _logDebug('Testing API connectivity...');
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
      _resetGAResults();
    });
  }
  
  void _resetGAResults() {
    _bestFitness = null;
    _averageFitness = null;
    _completedGenerations = null;
    _algorithmDetails = null;
    _fitnessHistory.clear();
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
      _resetGAResults();
    });
  }
  
  void _showFitnessEvolutionChart() {
    if (_fitnessHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fitness evolution data available. Please run optimization first.'),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Fitness Evolution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildFitnessChart(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Best Fitness',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _bestFitness?.toStringAsFixed(4) ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'Generations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${_completedGenerations ?? 0}/$_generations',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFitnessChart() {
    if (_fitnessHistory.isEmpty) {
      return const Center(
        child: Text('No fitness data available'),
      );
    }
    
    return CustomPaint(
      size: Size.infinite,
      painter: FitnessChartPainter(_fitnessHistory),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GA Route Optimization'),
        actions: [
          // Toggle view button
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: _toggleViewMode,
            tooltip: _showMap ? 'Show List' : 'Show Map',
          ),
          
          // Show fitness evolution
          if (_fitnessHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.show_chart),
              onPressed: _showFitnessEvolutionChart,
              tooltip: 'Show Fitness Evolution',
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
          // GA Results panel (if available)
          if (_bestFitness != null || _completedGenerations != null)
            _buildGAResultsPanel(),
          
          // Map takes the remaining space
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
  
  Widget _buildGAResultsPanel() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Genetic Algorithm Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_fitnessHistory.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.show_chart, size: 16),
                    label: const Text('Chart'),
                    onPressed: _showFitnessEvolutionChart,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Best Fitness
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Best Fitness',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _bestFitness?.toStringAsFixed(4) ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Generations
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Generations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${_completedGenerations ?? 0}/$_generations',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Population
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Population',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _populationSize.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Distance
                if (_optimizedRoute != null)
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Distance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${_optimizedRoute!.totalDistance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildListView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // GA Parameters panel
          _buildGAParametersPanel(),
          
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
  
  Widget _buildGAParametersPanel() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with toggle
          InkWell(
            onTap: () {
              setState(() {
                _showAdvancedSettings = !_showAdvancedSettings;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Genetic Algorithm Parameters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showAdvancedSettings 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable parameters section
          if (_showAdvancedSettings) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Population Size
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Population Size',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Number of routes in each generation',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _populationSize.toDouble(),
                              min: 20,
                              max: 200,
                              divisions: 18,
                              label: _populationSize.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _populationSize = value.round();
                                  _resetGAResults();
                                });
                              },
                            ),
                            Text(
                              _populationSize.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Generations
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Generations',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Number of evolution cycles',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _generations.toDouble(),
                              min: 50,
                              max: 500,
                              divisions: 18,
                              label: _generations.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _generations = value.round();
                                  _resetGAResults();
                                });
                              },
                            ),
                            Text(
                              _generations.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mutation Rate
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mutation Rate',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Probability of random changes',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _mutationRate,
                              min: 0.01,
                              max: 0.5,
                              divisions: 49,
                              label: _mutationRate.toStringAsFixed(2),
                              onChanged: (value) {
                                setState(() {
                                  _mutationRate = value;
                                  _resetGAResults();
                                });
                              },
                            ),
                            Text(
                              '${(_mutationRate * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Crossover Rate
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Crossover Rate',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Probability of combining routes',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _crossoverRate,
                              min: 0.1,
                              max: 1.0,
                              divisions: 18,
                              label: _crossoverRate.toStringAsFixed(2),
                              onChanged: (value) {
                                setState(() {
                                  _crossoverRate = value;
                                  _resetGAResults();
                                });
                              },
                            ),
                            Text(
                              '${(_crossoverRate * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Max Points
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Max Points',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Maximum water points in route',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _maxPoints.toDouble(),
                              min: 3,
                              max: 15,
                              divisions: 12,
                              label: _maxPoints.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _maxPoints = value.round();
                                  _resetGAResults();
                                });
                              },
                            ),
                            Text(
                              _maxPoints.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quick presets
                  const Text(
                    'Quick Presets',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _populationSize = 30;
                              _generations = 50;
                              _mutationRate = 0.2;
                              _crossoverRate = 0.7;
                              _maxPoints = 5;
                              _resetGAResults();
                            });
                          },
                          child: const Text('Fast'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _populationSize = 50;
                              _generations = 100;
                              _mutationRate = 0.1;
                              _crossoverRate = 0.8;
                              _maxPoints = 8;
                              _resetGAResults();
                            });
                          },
                          child: const Text('Balanced'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _populationSize = 100;
                              _generations = 200;
                              _mutationRate = 0.05;
                              _crossoverRate = 0.9;
                              _maxPoints = 12;
                              _resetGAResults();
                            });
                          },
                          child: const Text('Quality'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Running Genetic Algorithm...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pop: $_populationSize, Gen: $_generations, Mut: ${(_mutationRate * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
                            '${_selectedReports.length} location${_selectedReports.length == 1 ? '' : 's'} selected • Pop: $_populationSize • Gen: $_generations',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Main action button
                CustomButton(
                  text: _optimizedRoute == null
                      ? 'Optimize with Genetic Algorithm'
                      : 'Re-optimize Route',
                  onPressed: _selectedReports.isEmpty ? null : _optimizeRoute,
                  icon: Icons.psychology,
                  isFullWidth: true,
                  type: CustomButtonType.primary,
                ),
                
                // Quick settings toggle
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: Icon(
                    _showAdvancedSettings 
                        ? Icons.keyboard_arrow_up 
                        : Icons.settings,
                    size: 16,
                  ),
                  label: Text(
                    _showAdvancedSettings ? 'Hide Settings' : 'GA Settings',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _showAdvancedSettings = !_showAdvancedSettings;
                    });
                  },
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

// Custom painter for fitness evolution chart
class FitnessChartPainter extends CustomPainter {
  final List<double> fitnessHistory;
  
  FitnessChartPainter(this.fitnessHistory);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (fitnessHistory.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    // Calculate scaling factors
    final maxFitness = fitnessHistory.reduce((a, b) => a > b ? a : b);
    final minFitness = fitnessHistory.reduce((a, b) => a < b ? a : b);
    final fitnessRange = maxFitness - minFitness;
    
    if (fitnessRange == 0) return;
    
    // Draw the fitness evolution line
    for (int i = 0; i < fitnessHistory.length; i++) {
      final x = (i / (fitnessHistory.length - 1)) * size.width;
      final normalizedFitness = (fitnessHistory[i] - minFitness) / fitnessRange;
      final y = size.height - (normalizedFitness * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0;
    
    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Vertical grid lines
    for (int i = 0; i <= 4; i++) {
      final x = (i / 4) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Draw data points
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < fitnessHistory.length; i += max(1, fitnessHistory.length ~/ 20)) {
      final x = (i / (fitnessHistory.length - 1)) * size.width;
      final normalizedFitness = (fitnessHistory[i] - minFitness) / fitnessRange;
      final y = size.height - (normalizedFitness * size.height);
      
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}