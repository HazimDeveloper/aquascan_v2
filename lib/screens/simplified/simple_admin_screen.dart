// lib/screens/simplified/simple_admin_screen.dart - FIX METHOD NAMES
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/role_selection_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';
import '../../widgets/common/custom_loader.dart';
import '../../widgets/simplified/openstreet_map_widget.dart';

class SimpleAdminScreen extends StatefulWidget {
  const SimpleAdminScreen({Key? key}) : super(key: key);

  @override
  _SimpleAdminScreenState createState() => _SimpleAdminScreenState();
}

class _SimpleAdminScreenState extends State<SimpleAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isLoadingRoutes = false;
  bool _backendConnected = false;
  
  GeoPoint? _currentLocation;
  List<Map<String, dynamic>> _allRoutes = [];
  Map<String, dynamic>? _csvDataInfo;
  String? _errorMessage;
  
  late LocationService _locationService;
  late ApiService _apiService;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _initializeWithAllData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// Initialize with ALL CSV data - FIXED METHOD NAMES
  Future<void> _initializeWithAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendConnected = false;
    });
    
    try {
      print('\n🚀 === LOADING ALL DATA (NO DISTANCE LIMITS) ===');
      
      // STEP 1: Test backend connection
      print('1️⃣ Testing backend connection...');
      final isConnected = await _apiService.testBackendConnection();
      
      if (!isConnected) {
        setState(() {
          _errorMessage = 'Backend server not running!\n\nPlease start Python server:\n1. cd backend_version_2\n2. python main.py\n3. Refresh this page';
          _isLoading = false;
          _backendConnected = false;
        });
        return;
      }
      
      setState(() {
        _backendConnected = true;
      });
      print('✅ Backend connected successfully');
      
      // STEP 2: Debug ALL CSV data - FIXED METHOD NAME
      print('2️⃣ Loading ALL CSV data...');
      await _debugCSVData(); // FIXED: Use method that exists
      
      // STEP 3: Get current location
      print('3️⃣ Getting current location...');
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        setState(() {
          _errorMessage = 'Cannot get your location.\n\nPlease:\n1. Enable location services\n2. Grant location permission\n3. Try again';
          _isLoading = false;
        });
        return;
      }
      
      final currentLocation = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      setState(() {
        _currentLocation = currentLocation;
      });
      
      print('✅ Location: ${position.latitude}, ${position.longitude}');
      
      // STEP 4: Load ALL CSV water supply data
      print('4️⃣ Loading ALL CSV water supply data...');
      await _loadAllCSVData();
      
      // STEP 5: Generate routes to ALL water supplies
      print('5️⃣ Generating routes to ALL water supplies...');
      await _loadAllPolylineRoutes();
      
      print('✅ === INITIALIZATION COMPLETE (ALL DATA LOADED) ===\n');
      
    } catch (e) {
      print('❌ Initialization failed: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e\n\nMake sure:\n1. Python server is running\n2. CSV file exists\n3. Try refreshing';
        _isLoading = false;
      });
    }
  }
  
  /// FIXED: Use correct method name for CSV data debugging
  Future<void> _debugCSVData() async {
    try {
      print('\n🔍 === CSV DATA DEBUG ===');
      
      // Use the correct method name from ApiService
      final csvData = await _apiService.getAllWaterSupplyPointsFromCSV();
      print('📊 Total water supplies: ${csvData['total'] ?? csvData['points']?.length ?? 0}');
      print('📂 Data source: ${csvData['data_source']}');
      
      final points = csvData['points'] as List<dynamic>? ?? [];
      print('\n📍 CSV data (first 3):');
      
      for (int i = 0; i < (points.length > 3 ? 3 : points.length); i++) {
        final point = points[i];
        print('${i + 1}. ${point['street_name']}');
        print('   Address: ${point['address']}');
        print('   Coords: ${point['latitude']}, ${point['longitude']}');
      }
      
      print('\n✅ CSV data loaded successfully!');
      print('=======================================\n');
      
    } catch (e) {
      print('❌ CSV debug failed: $e');
    }
  }
  
  /// Load ALL CSV data
  Future<void> _loadAllCSVData() async {
    try {
      // FIXED: Use correct method name
      final allCSVData = await _apiService.getAllWaterSupplyPointsFromCSV();
      
      setState(() {
        _csvDataInfo = allCSVData;
      });
      
      final points = allCSVData['points'] as List<dynamic>;
      final dataSource = allCSVData['data_source'] as String?;
      
      print('📊 ALL CSV Data loaded:');
      print('   Total points: ${points.length}');
      print('   Data source: $dataSource');
      print('   Coverage: ALL WATER SUPPLIES (no distance limit)');
      
      if (points.isNotEmpty) {
        print('   First point: ${points[0]['street_name']}');
        print('   Last point: ${points.last['street_name']}');
      }
      
    } catch (e) {
      print('❌ Failed to load ALL CSV data: $e');
      throw Exception('Cannot load ALL CSV data: $e');
    }
  }
  
  /// Load routes to ALL water supplies - FIXED METHOD NAME
  Future<void> _loadAllPolylineRoutes() async {
    if (_currentLocation == null) {
      throw Exception('Current location not available');
    }
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🗺️ Loading routes to ALL water supplies (no distance limit)...');
      
      // FIXED: Use correct method name from ApiService
      final result = await _apiService.getPolylineRoutesToWaterSupplies(
        _currentLocation!,
        'admin-all-data',
        maxRoutes: 50, // Get more routes since no distance limit
      );
      
      final routes = result['polyline_routes'] as List<dynamic>;
      
      setState(() {
        _allRoutes = routes.cast<Map<String, dynamic>>();
        _isLoadingRoutes = false;
        _isLoading = false;
      });
      
      print('✅ Loaded ${routes.length} routes to ALL water supplies');
      
      // Log route statistics
      if (routes.isNotEmpty) {
        final distances = routes.map((r) => r['distance'] as double? ?? 0.0).toList();
        distances.sort();
        
        print('📊 Route statistics:');
        print('   Shortest: ${distances.first.toStringAsFixed(1)} km');
        print('   Longest: ${distances.last.toStringAsFixed(1)} km');
        if (distances.isNotEmpty) {
          print('   Average: ${(distances.reduce((a, b) => a + b) / distances.length).toStringAsFixed(1)} km');
        }
        
        // Log first few routes
        for (int i = 0; i < (routes.length > 5 ? 5 : routes.length); i++) {
          final route = routes[i];
          final destDetails = route['destination_details'] as Map<String, dynamic>?;
          if (destDetails != null) {
            print('   ${i + 1}. ${destDetails['street_name']} - ${route['distance']} km');
          }
        }
      }
      
    } catch (e) {
      print('❌ Failed to load routes to all supplies: $e');
      setState(() {
        _errorMessage = 'Cannot load route data: $e\n\nThis might happen if:\n1. CSV file is empty\n2. No valid coordinates in CSV\n3. Backend processing error';
        _isLoadingRoutes = false;
        _isLoading = false;
      });
    }
  }
  
  /// Refresh ALL data
  Future<void> _refreshAllData() async {
    print('🔄 Refreshing ALL data (no limits)...');
    await _initializeWithAllData();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 8),
            Text('Admin - All Data'),
          ],
        ),
        backgroundColor: Colors.orange,
        actions: [
          // Backend status indicator
          Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _backendConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _backendConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: Colors.white,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  _backendConnected ? 'All Data' : 'Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Data count indicator
          if (_csvDataInfo != null)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(_csvDataInfo!['points'] as List<dynamic>?)?.length ?? _csvDataInfo!['total'] ?? 0} pts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
            tooltip: 'Refresh All Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
              );
            },
            tooltip: 'Switch Role',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.public),
              text: 'All Water Supplies',
            ),
            Tab(
              icon: Icon(Icons.add_circle),
              text: 'Create Report',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaterDropLoader(
                    message: 'Loading ALL water supplies...',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Getting ALL data from CSV (no distance limits)',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllDataMapTab(),
                    _buildReportTab(),
                  ],
                ),
    );
  }
  
  Widget _buildErrorView() {
    final isBackendError = _errorMessage!.contains('Backend') || _errorMessage!.contains('server');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBackendError ? Icons.cloud_off : Icons.error_outline,
              size: 80,
              color: isBackendError ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isBackendError ? 'Backend Server Offline' : 'Error Loading All Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isBackendError ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshAllData,
              icon: Icon(Icons.refresh),
              label: Text('Load All Data Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAllDataMapTab() {
    return Column(
      children: [
        // ALL data info card
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.all_inclusive,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ALL Water Supplies Loaded',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _csvDataInfo != null 
                                  ? 'All ${(_csvDataInfo!['points'] as List<dynamic>?)?.length ?? _csvDataInfo!['total'] ?? 0} points • ${_allRoutes.length} routes (no distance limit)'
                                  : 'Loading all data from CSV...',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingRoutes)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  
                  if (_csvDataInfo != null && _allRoutes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDataInfo(
                          'Total Points',
                          '${(_csvDataInfo!['points'] as List<dynamic>?)?.length ?? _csvDataInfo!['total'] ?? 0}',
                          Colors.blue,
                        ),
                        _buildDataInfo(
                          'Routes Shown',
                          _allRoutes.length.toString(),
                          Colors.green,
                        ),
                        _buildDataInfo(
                          'Closest',
                          _allRoutes.isNotEmpty 
                              ? '${_allRoutes[0]['distance']?.toStringAsFixed(1) ?? '?'} km'
                              : 'N/A',
                          Colors.red,
                        ),
                        _buildDataInfo(
                          'Coverage',
                          'All Areas',
                          Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        
        // OpenStreetMap with ALL data
        Expanded(
          child: _currentLocation != null && _allRoutes.isNotEmpty
              ? OpenStreetMapWidget(
                  currentLocation: _currentLocation!,
                  polylineRoutes: _allRoutes,
                  isLoading: _isLoadingRoutes,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentLocation == null) ...[
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                        SizedBox(height: 16),
                        Text('Getting your location...'),
                      ] else if (_allRoutes.isEmpty) ...[
                        Icon(Icons.water_drop_outlined, size: 80, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          'No Water Supplies Found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Check if CSV file has valid data',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshAllData,
                          icon: Icon(Icons.refresh),
                          label: Text('Retry Loading'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildDataInfo(String label, String value, Color color) {
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
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin report info
          Card(
            color: Colors.orange.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Report Creation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create reports with access to ALL water supply locations',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _backendConnected ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _backendConnected ? 'All Data' : 'Offline',
                          style: TextStyle(
                            color: Colors.white,
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
          ),
          
          const SizedBox(height: 24),
          
          // Create report button
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: _backendConnected 
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SimpleReportScreen(isAdmin: true),
                        ),
                      );
                    }
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Opacity(
                opacity: _backendConnected ? 1.0 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.add_circle,
                          size: 40,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create Admin Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _backendConnected 
                            ? 'Create reports with access to ALL water supply data'
                            : 'Backend required for report creation',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _backendConnected ? Colors.orange : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _backendConnected ? Icons.all_inclusive : Icons.offline_bolt,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _backendConnected ? 'All Data Access' : 'Offline',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Features unchanged...
          const Text(
            'All Data Features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildFeatureItem(
            icon: Icons.all_inclusive,
            title: 'Complete Dataset Access',
            description: 'Access to ALL water supply points in CSV database (no distance limits)',
            color: Colors.blue,
            isAvailable: _backendConnected,
          ),
          
          _buildFeatureItem(
            icon: Icons.public,
            title: 'Full Coverage Map',
            description: 'Interactive map showing ALL water supply locations regardless of distance',
            color: Colors.green,
            isAvailable: _backendConnected,
          ),
          
          _buildFeatureItem(
            icon: Icons.route,
            title: 'All Route Calculations',
            description: 'Calculate routes to any water supply in the entire database',
            color: Colors.orange,
            isAvailable: _backendConnected,
          ),
          
          _buildFeatureItem(
            icon: Icons.analytics,
            title: 'Complete Analytics',
            description: 'Full statistics and analysis across all available data points',
            color: Colors.purple,
            isAvailable: _backendConnected,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isAvailable,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isAvailable ? color : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isAvailable ? color : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                    if (!isAvailable)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'OFFLINE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: isAvailable ? AppTheme.textSecondaryColor : Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}