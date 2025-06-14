// lib/screens/simplified/simple_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../screens/simplified/role_selection_screen.dart';
import '../../screens/simplified/simple_report_screen.dart';
import '../../widgets/common/custom_loader.dart';
import '../../widgets/simplified/polyline_map_widget.dart';

class SimpleAdminScreen extends StatefulWidget {
  const SimpleAdminScreen({Key? key}) : super(key: key);

  @override
  _SimpleAdminScreenState createState() => _SimpleAdminScreenState();
}

class _SimpleAdminScreenState extends State<SimpleAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isLoadingRoutes = false;
  GeoPoint? _currentLocation;
  List<Map<String, dynamic>> _polylineRoutes = [];
  String? _errorMessage;
  
  late LocationService _locationService;
  late ApiService _apiService;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _getCurrentLocationAndRoutes();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentLocationAndRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('🔍 Getting current location...');
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final currentLocation = GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        
        setState(() {
          _currentLocation = currentLocation;
        });
        
        print('📍 Location obtained: ${position.latitude}, ${position.longitude}');
        
        // Load polyline routes
        await _loadPolylineRoutes();
      } else {
        setState(() {
          _errorMessage = 'Could not get your location. Please check permissions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadPolylineRoutes() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🗺️ Loading polyline routes...');
      
      final result = await _apiService.getPolylineRoutesToWaterSupplies(
        _currentLocation!,
        'admin-test',
        maxRoutes: 8,
        maxDistance: 15.0,
      );
      
      if (result['success'] == true) {
        final routes = result['polyline_routes'] as List<dynamic>;
        
        setState(() {
          _polylineRoutes = routes.cast<Map<String, dynamic>>();
          _isLoadingRoutes = false;
          _isLoading = false;
        });
        
        print('✅ Loaded ${routes.length} polyline routes');
      } else {
        throw Exception(result['message'] ?? 'Failed to load routes');
      }
    } catch (e) {
      print('❌ Error loading routes: $e');
      setState(() {
        _errorMessage = 'Error loading routes: $e';
        _isLoadingRoutes = false;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 8),
            Text('Admin Mode'),
          ],
        ),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocationAndRoutes,
            tooltip: 'Refresh Routes',
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
              icon: Icon(Icons.map),
              text: 'Water Supply Map',
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
              child: WaterDropLoader(
                message: 'Loading water supply routes...',
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Map tab
                    _buildMapTab(),
                    
                    // Report creation tab
                    _buildReportTab(),
                  ],
                ),
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
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Map',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _getCurrentLocationAndRoutes,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
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
  
  Widget _buildMapTab() {
    return Column(
      children: [
        // Map info card
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
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
                          Icons.map,
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
                              'Water Supply Routes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _polylineRoutes.isNotEmpty 
                                  ? '${_polylineRoutes.length} routes found to water supplies'
                                  : 'Loading routes...',
                              style: TextStyle(
                                color: Colors.orange.shade800,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                    ],
                  ),
                  
                  if (_polylineRoutes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildRouteInfo(
                          'Shortest Route',
                          '${_polylineRoutes.isNotEmpty ? _polylineRoutes[0]['distance']?.toStringAsFixed(1) ?? '?' : '?'} km',
                          Colors.red,
                        ),
                        _buildRouteInfo(
                          'Total Routes',
                          _polylineRoutes.length.toString(),
                          Colors.orange,
                        ),
                        _buildRouteInfo(
                          'Max Distance',
                          '15.0 km',
                          Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        
        // Map widget
        Expanded(
          child: _currentLocation != null
              ? PolylineMapWidget(
                  currentLocation: _currentLocation!,
                  polylineRoutes: _polylineRoutes,
                  isLoading: _isLoadingRoutes,
                )
              : Center(
                  child: Text(
                    'Getting your location...',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildRouteInfo(String label, String value, Color color) {
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
              child: Row(
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
                          'Create detailed reports with admin privileges and enhanced features',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SimpleReportScreen(isAdmin: true),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
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
                      'Create detailed reports with admin privileges and enhanced metadata',
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
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Admin Report',
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
          
          const SizedBox(height: 24),
          
          // Admin features info
          const Text(
            'Admin Features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildFeatureItem(
            icon: Icons.map,
            title: 'Polyline Route Map',
            description: 'View multiple colored routes to water supply points on an interactive map',
            color: Colors.blue,
          ),
          
          _buildFeatureItem(
            icon: Icons.admin_panel_settings,
            title: 'Enhanced Reports',
            description: 'Create reports with admin metadata and priority settings',
            color: Colors.orange,
          ),
          
          _buildFeatureItem(
            icon: Icons.photo_library,
            title: 'Multiple Photos',
            description: 'Upload up to 10 high-quality evidence photos per report',
            color: Colors.green,
          ),
          
          _buildFeatureItem(
            icon: Icons.psychology,
            title: 'AI Analysis',
            description: 'Advanced water quality analysis with confidence scoring',
            color: Colors.purple,
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
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