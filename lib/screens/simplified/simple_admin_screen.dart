// lib/screens/simplified/simple_admin_screen.dart - REDESIGNED WITH LARGE MAP
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

class _SimpleAdminScreenState extends State<SimpleAdminScreen> 
    with TickerProviderStateMixin {
  AnimationController? _animationController;
  AnimationController? _panelController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _panelAnimation;
  
  bool _isLoading = false;
  bool _isLoadingRoutes = false;
  bool _backendConnected = false;
  
  GeoPoint? _currentLocation;
  List<Map<String, dynamic>> _allRoutes = [];
  Map<String, dynamic>? _csvDataInfo;
  String? _errorMessage;
  
  late LocationService _locationService;
  late ApiService _apiService;
  
  // UI state
  bool _showInfoPanel = true;
  bool _showSystemStats = false;
  bool _isInfoPanelExpanded = false;
  bool _showCreateReportPanel = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize animations after controllers are ready
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    
    _panelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _panelController!,
      curve: Curves.easeOutBack,
    ));
    
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    // Start animations and initialization
    _initializeAdminDashboard();
    _animationController?.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    _panelController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeAdminDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendConnected = false;
    });
    
    try {
      print('\n🚀 === ADMIN DASHBOARD INITIALIZATION ===');
      
      // Step 1: Test backend connection
      print('1️⃣ Testing backend connection...');
      final isConnected = await _apiService.testBackendConnection();
      
      setState(() {
        _backendConnected = isConnected;
      });
      
      if (!isConnected) {
        setState(() {
          _errorMessage = 'Backend server offline';
          _isLoading = false;
        });
        return;
      }
      
      print('✅ Backend connected successfully');
      
      // Step 2: Get current location
      print('2️⃣ Getting admin location...');
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        setState(() {
          _errorMessage = 'Cannot access location services';
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
      
      // Step 3: Load CSV data
      print('3️⃣ Loading water supply data...');
      await _loadCSVData();
      
      // Step 4: Generate routes
      print('4️⃣ Generating route network...');
      await _loadRouteNetwork();
      
      print('✅ === ADMIN DASHBOARD READY ===\n');
      
    } catch (e) {
      print('❌ Admin dashboard initialization failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadCSVData() async {
    try {
      final csvData = await _apiService.getAllWaterSupplyPointsFromCSV();
      setState(() {
        _csvDataInfo = csvData;
      });
      
      final points = csvData['points'] as List<dynamic>;
      print('📊 Loaded ${points.length} water supply points');
      
    } catch (e) {
      print('❌ Failed to load CSV data: $e');
      throw Exception('Cannot load water supply data: $e');
    }
  }
  
  Future<void> _loadRouteNetwork() async {
    if (_currentLocation == null) {
      throw Exception('Current location not available');
    }
    
    setState(() {
      _isLoadingRoutes = true;
    });
    
    try {
      print('🗺️ Loading complete route network...');
      
      final result = await _apiService.getPolylineRoutesToWaterSupplies(
        _currentLocation!,
        'admin-dashboard',
        maxRoutes: 50,
      );
      
      final routes = result['polyline_routes'] as List<dynamic>;
      
      setState(() {
        _allRoutes = routes.cast<Map<String, dynamic>>();
        _isLoadingRoutes = false;
        _isLoading = false;
      });
      
      print('✅ Loaded ${routes.length} route networks');
      
      // Show info panel after routes are loaded
      if (_allRoutes.isNotEmpty) {
        _panelController?.forward();
      }
      
    } catch (e) {
      print('❌ Failed to load route network: $e');
      setState(() {
        _errorMessage = 'Cannot load route network: $e';
        _isLoadingRoutes = false;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _refreshDashboard() async {
    print('🔄 Refreshing admin dashboard...');
    await _initializeAdminDashboard();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _fadeAnimation != null ? FadeTransition(
        opacity: _fadeAnimation!,
        child: Stack(
          children: [
            // MAIN MAP - Full screen background
            _buildFullScreenMap(),
            
            // TOP STATUS BAR
            _buildTopStatusBar(),
            
            // FLOATING ACTION BUTTON - Create Report
            _buildCreateReportFAB(),
            
            // INFO PANEL - Bottom overlay
            if (_showInfoPanel && _allRoutes.isNotEmpty)
              _buildInfoPanel(),
            
            // SYSTEM STATS PANEL - Top right overlay
            if (_showSystemStats)
              _buildSystemStatsPanel(),
            
            // CREATE REPORT PANEL - Right side overlay
            if (_showCreateReportPanel)
              _buildCreateReportPanel(),
            
            // LOADING OVERLAY
            if (_isLoading) _buildLoadingOverlay(),
            
            // ERROR OVERLAY
            if (_errorMessage != null && !_isLoading) _buildErrorOverlay(),
          ],
        ),
      ) : Stack(
        children: [
          // MAIN MAP - Full screen background
          _buildFullScreenMap(),
          
          // TOP STATUS BAR
          _buildTopStatusBar(),
          
          // FLOATING ACTION BUTTON - Create Report
          _buildCreateReportFAB(),
          
          // INFO PANEL - Bottom overlay
          if (_showInfoPanel && _allRoutes.isNotEmpty)
            _buildInfoPanel(),
          
          // SYSTEM STATS PANEL - Top right overlay
          if (_showSystemStats)
            _buildSystemStatsPanel(),
          
          // CREATE REPORT PANEL - Right side overlay
          if (_showCreateReportPanel)
            _buildCreateReportPanel(),
          
          // LOADING OVERLAY
          if (_isLoading) _buildLoadingOverlay(),
          
          // ERROR OVERLAY
          if (_errorMessage != null && !_isLoading) _buildErrorOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildFullScreenMap() {
    if (_currentLocation == null || _allRoutes.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.blue.shade50,
            ],
          ),
        ),
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
              Text(
                'Loading Map...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return OpenStreetMapWidget(
      currentLocation: _currentLocation!,
      polylineRoutes: _allRoutes,
      isLoading: _isLoadingRoutes,
    );
  }
  
  Widget _buildTopStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,  // Reduced padding
          left: 12,  // Reduced from 16
          right: 12, // Reduced from 16
          bottom: 4, // Reduced from 8
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),  // Reduced opacity
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // ADMIN BADGE - Made smaller
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16), // Reduced from 20
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 6, // Reduced from 8
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 14), // Reduced
                    SizedBox(width: 4), // Reduced
                    Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10, // Reduced
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8), // Reduced from 12
              
              // CONNECTION STATUS - Made smaller
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced
                decoration: BoxDecoration(
                  color: _backendConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(10), // Reduced from 12
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4, // Reduced
                      height: 4, // Reduced
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4), // Reduced
                    Text(
                      _backendConnected ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9, // Reduced
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // ACTION BUTTONS - Made smaller
              Row(
                children: [
                  _buildTopActionButton(
                    icon: _showSystemStats ? Icons.analytics : Icons.analytics_outlined,
                    onPressed: () {
                      setState(() {
                        _showSystemStats = !_showSystemStats;
                      });
                    },
                    isActive: _showSystemStats,
                  ),
                  
                  const SizedBox(width: 6), // Reduced
                  
                  _buildTopActionButton(
                    icon: Icons.refresh,
                    onPressed: _refreshDashboard,
                  ),
                  
                  const SizedBox(width: 6), // Reduced
                  
                  _buildTopActionButton(
                    icon: Icons.more_vert,
                    onPressed: _showMainMenu,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2), // Reduced opacity
      borderRadius: BorderRadius.circular(6), // Reduced from 8
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6), // Reduced from 8
          child: Icon(
            icon,
            color: Colors.white,
            size: 18, // Reduced from 20
          ),
        ),
      ),
    );
  }
  
  Widget _buildCreateReportFAB() {
    // Calculate bottom position based on panel state
    double bottomPosition = 16;
    if (_showInfoPanel && _allRoutes.isNotEmpty) {
      bottomPosition = _isInfoPanelExpanded ? 280 : 140; // Adjust based on panel height
    }
    
    return Positioned(
      bottom: bottomPosition,
      left: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // INFO TOGGLE FAB - Made smaller
          FloatingActionButton(
            mini: true,
            heroTag: "info_toggle",
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange,
            onPressed: () {
              setState(() {
                _showInfoPanel = !_showInfoPanel;
              });
              if (_showInfoPanel) {
                _panelController?.forward();
              } else {
                _panelController?.reverse();
              }
            },
            child: Icon(_showInfoPanel ? Icons.info : Icons.info_outline, size: 18), // Smaller icon
          ),
          
          const SizedBox(height: 8), // Reduced spacing
          
          // MAIN CREATE REPORT FAB - Compact design
          Container(
            height: 48, // Fixed height for consistency
            child: FloatingActionButton.extended(
              heroTag: "create_report",
              onPressed: _backendConnected ? () {
                setState(() {
                  _showCreateReportPanel = !_showCreateReportPanel;
                });
              } : null,
              backgroundColor: _backendConnected ? Colors.orange : Colors.grey,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add_circle, size: 20), // Smaller icon
              label: Text(
                'Report',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Smaller text
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: _panelAnimation != null ? AnimatedBuilder(
        animation: _panelAnimation!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _panelAnimation!.value) * 200),
            child: child,
          );
        },
        child: _buildInfoPanelContent(),
      ) : _buildInfoPanelContent(),
    );
  }
  
  Widget _buildInfoPanelContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Reduced radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Reduced shadow
            blurRadius: 15, // Reduced blur
            offset: Offset(0, -3), // Reduced offset
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // COMPACT PANEL HEADER
          GestureDetector(
            onTap: () {
              setState(() {
                _isInfoPanelExpanded = !_isInfoPanelExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12), // Reduced padding
              child: Column(
                children: [
                  // DRAG HANDLE
                  Container(
                    width: 30, // Smaller handle
                    height: 3, // Thinner handle
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  const SizedBox(height: 8), // Reduced spacing
                  
                  // COMPACT HEADER INFO
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6), // Smaller padding
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6), // Smaller radius
                        ),
                        child: Icon(Icons.water_drop, color: Colors.white, size: 16), // Smaller icon
                      ),
                      const SizedBox(width: 8), // Reduced spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Water Supply Network',
                              style: TextStyle(
                                fontSize: 14, // Smaller text
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_allRoutes.length} routes • Real-time data',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11, // Smaller text
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isInfoPanelExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 18, // Smaller icon
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // COMPACT EXPANDABLE CONTENT
          if (_isInfoPanelExpanded) _buildCompactExpandedContent(),
        ],
      ),
    );
  }
  
  Widget _buildCompactExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), // Reduced padding
      child: Column(
        children: [
          Container(height: 1, color: Colors.grey.shade300), // Thinner divider
          const SizedBox(height: 12), // Reduced spacing
          
          // COMPACT QUICK STATS ROW
          Row(
            children: [
              Expanded(child: _buildCompactStat('Data Points', '${(_csvDataInfo?['points'] as List<dynamic>?)?.length ?? 0}', Colors.blue)),
              Expanded(child: _buildCompactStat('Routes', '${_allRoutes.length}', Colors.green)),
              Expanded(child: _buildCompactStat('Coverage', 'All Areas', Colors.purple)),
              Expanded(child: _buildCompactStat('Status', _backendConnected ? 'Online' : 'Offline', _backendConnected ? Colors.green : Colors.red)),
            ],
          ),
          
          const SizedBox(height: 12), // Reduced spacing
          
          // COMPACT SHORTEST ROUTE INFO
          if (_allRoutes.isNotEmpty) _buildCompactShortestRouteInfo(),
        ],
      ),
    );
  }
  
  Widget _buildCompactStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14, // Smaller text
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2), // Reduced spacing
        Text(
          label,
          style: TextStyle(
            fontSize: 9, // Smaller text
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildCompactShortestRouteInfo() {
    final shortestRoute = _allRoutes.first;
    
    return Container(
      padding: const EdgeInsets.all(10), // Reduced padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(8), // Smaller radius
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.green, size: 16), // Smaller icon
          const SizedBox(width: 6), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shortest Route',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 12, // Smaller text
                  ),
                ),
                Text(
                  '${shortestRoute['distance']?.toStringAsFixed(1) ?? '?'} km • ${shortestRoute['travel_time'] ?? '?'}',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 10, // Smaller text
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandedPanelContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // QUICK STATS ROW
          Row(
            children: [
              Expanded(child: _buildQuickStat('Data Points', '${(_csvDataInfo?['points'] as List<dynamic>?)?.length ?? 0}', Colors.blue)),
              Expanded(child: _buildQuickStat('Routes', '${_allRoutes.length}', Colors.green)),
              Expanded(child: _buildQuickStat('Coverage', 'All Areas', Colors.purple)),
              Expanded(child: _buildQuickStat('Status', _backendConnected ? 'Online' : 'Offline', _backendConnected ? Colors.green : Colors.red)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // SHORTEST ROUTE INFO
          if (_allRoutes.isNotEmpty) _buildShortestRouteInfo(),
        ],
      ),
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
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildShortestRouteInfo() {
    final shortestRoute = _allRoutes.first;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shortest Route',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${shortestRoute['distance']?.toStringAsFixed(1) ?? '?'} km • ${shortestRoute['travel_time'] ?? '?'}',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSystemStatsPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60, // Avoid top status bar
      right: 12,
      child: Container(
        width: 200, // Reduced width
        padding: const EdgeInsets.all(12), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), // Slightly transparent
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15), // Reduced shadow
              blurRadius: 8, // Reduced blur
              offset: Offset(0, 3), // Reduced offset
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.orange, size: 16), // Smaller icon
                const SizedBox(width: 6), // Reduced spacing
                Text(
                  'System Stats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Smaller text
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showSystemStats = false),
                  child: Icon(Icons.close, size: 14, color: Colors.grey), // Smaller close button
                ),
              ],
            ),
            
            const SizedBox(height: 8), // Reduced spacing
            Container(height: 1, color: Colors.grey.shade300), // Thinner divider
            const SizedBox(height: 8),
            
            _buildStatRow('Backend', _backendConnected ? 'Connected' : 'Offline', _backendConnected ? Colors.green : Colors.red),
            _buildStatRow('Location', _currentLocation != null ? 'Active' : 'Inactive', _currentLocation != null ? Colors.green : Colors.orange),
            _buildStatRow('Routes', '${_allRoutes.length}', Colors.blue),
            _buildStatRow('Data Points', '${(_csvDataInfo?['points'] as List<dynamic>?)?.length ?? 0}', Colors.purple),
            _buildStatRow('Status', _isLoadingRoutes ? 'Loading...' : 'Ready', _isLoadingRoutes ? Colors.orange : Colors.green),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2), // Reduced padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11, // Smaller text
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11, // Smaller text
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreateReportPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60, // Avoid top status bar
      bottom: _showInfoPanel ? 160 : 80, // Avoid bottom elements
      right: 12,
      child: Container(
        width: 260, // Reduced width
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50,
              Colors.orange.shade100.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12), // Reduced radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15), // Reduced shadow
              blurRadius: 10, // Reduced blur
              offset: Offset(0, 3), // Reduced offset
            ),
          ],
        ),
        child: Column(
          children: [
            // COMPACT HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // Reduced padding
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(6), // Reduced radius
                  ),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 16), // Smaller icon
                ),
                const SizedBox(width: 8), // Reduced spacing
                Expanded(
                  child: Text(
                    'Admin Report',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Smaller text
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showCreateReportPanel = false),
                  child: Icon(Icons.close, size: 14, color: Colors.grey), // Smaller close
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // COMPACT CONTENT
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60, // Smaller icon container
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(15), // Reduced radius
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10, // Reduced blur
                          offset: Offset(0, 3), // Reduced offset
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_circle,
                      size: 30, // Smaller icon
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 12), // Reduced spacing
                  
                  Text(
                    'Create Admin Report',
                    style: TextStyle(
                      fontSize: 16, // Smaller title
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8), // Reduced spacing
                  
                  Text(
                    'Enhanced AI analysis with admin-level data access.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12, // Smaller description
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _backendConnected ? () {
                        setState(() => _showCreateReportPanel = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SimpleReportScreen(isAdmin: true),
                          ),
                        );
                      } : null,
                      icon: Icon(Icons.admin_panel_settings, size: 16), // Smaller icon
                      label: Text(
                        'Start Creating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12, // Smaller text
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _backendConnected ? Colors.orange : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8), // Reduced padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Reduced radius
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaterDropLoader(message: 'Initializing Admin Dashboard...'),
              const SizedBox(height: 16),
              Text(
                'Loading water supply network and route data',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Dashboard Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      ),
                      icon: Icon(Icons.arrow_back),
                      label: Text('Go Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _refreshDashboard,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Admin Menu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.orange),
              title: Text('Refresh Dashboard'),
              onTap: () {
                Navigator.pop(context);
                _refreshDashboard();
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: Colors.blue),
              title: Text('System Statistics'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showSystemStats = !_showSystemStats);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Switch Role'),
              onTap: () {
                Navigator.pop(context);
                _showRoleSwitchDialog();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showRoleSwitchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Switch Role'),
            ],
          ),
          content: const Text(
            'Are you sure you want to leave the admin dashboard and return to role selection?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Switch Role'),
            ),
          ],
        );
      },
    );
  }
}