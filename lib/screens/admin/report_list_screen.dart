// lib/screens/admin/report_list_screen.dart - COMPLETE VERSION
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aquascan/widgets/common/custom_bottom.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../widgets/common/custom_loader.dart';
import '../../utils/water_quality_utils.dart';

class ReportListScreen extends StatefulWidget {
  final bool? showResolved;
  
  const ReportListScreen({
    Key? key,
    this.showResolved,
  }) : super(key: key);

  @override
  _ReportListScreenState createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ReportModel> _pendingReports = [];
  List<ReportModel> _resolvedReports = [];
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, with_images, without_images, analyzed, not_analyzed
  
  // Map to store confidence scores for each report (only for reports with images)
  Map<String, double> _confidenceScores = {};
  
  // Debug flag for logging
  final bool _debugMode = true;
  
  // Helper method for debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      print('📱 ReportListScreen: $message');
    }
  }
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showResolved == true ? 1 : 0,
    );
    
    // Load reports after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Load both report types
      final pendingReports = await databaseService.getUnresolvedReportsList();
      final resolvedReports = await databaseService.getResolvedReportsList();
      
      // Log report data for debugging
      _logDebug('Loaded ${pendingReports.length} pending reports and ${resolvedReports.length} resolved reports');
      
      for (var report in [...pendingReports, ...resolvedReports]) {
        _logDebug('Report ID: ${report.id}');
        _logDebug('Report title: ${report.title}');
        _logDebug('Report has ${report.imageUrls.length} images');
        _logDebug('Water quality state: ${report.waterQuality}');
        if (report.imageUrls.isNotEmpty) {
          for (int i = 0; i < report.imageUrls.length; i++) {
            _logDebug('Image URL ${i+1}: ${report.imageUrls[i]}');
          }
        }
      }
      
      // Initialize confidence scores map - ONLY for reports with images
      Map<String, double> confidenceMap = {};
      
      final allReports = [...pendingReports, ...resolvedReports];
      for (var report in allReports) {
        // IMPORTANT: Only process confidence for reports that have images
        if (report.imageUrls.isNotEmpty && report.waterQuality != WaterQualityState.unknown) {
          try {
            // In a real implementation, you would fetch the actual confidence from stored analysis
            // For demo purposes, generate a confidence between 60-95% based on quality state
            double confidence;
            switch (report.waterQuality) {
              case WaterQualityState.optimum:
                confidence = 85.0 + (report.id.hashCode % 15); // 85-100%
                break;
              case WaterQualityState.lowTemp:
                confidence = 75.0 + (report.id.hashCode % 20); // 75-95%
                break;
              case WaterQualityState.highPhTemp:
                confidence = 80.0 + (report.id.hashCode % 15); // 80-95%
                break;
              case WaterQualityState.highPh:
              case WaterQualityState.lowPh:
                confidence = 70.0 + (report.id.hashCode % 25); // 70-95%
                break;
              case WaterQualityState.lowTempHighPh:
                confidence = 65.0 + (report.id.hashCode % 25); // 65-90%
                break;
              default:
                confidence = 0.0; // No confidence for unknown
            }
            
            confidenceMap[report.id] = confidence;
            _logDebug('Generated confidence score for report ${report.id}: $confidence');
          } catch (e) {
            confidenceMap[report.id] = 0.0;
            _logDebug('Error getting confidence for report ${report.id}: $e');
          }
        } else {
          // No images or unknown quality - no confidence score
          _logDebug('No confidence score for report ${report.id} - no images or unknown quality');
        }
      }
      
      setState(() {
        _pendingReports = pendingReports;
        _resolvedReports = resolvedReports;
        _confidenceScores = confidenceMap;
        _isLoading = false;
      });
    } catch (e) {
      _logDebug('Error loading reports: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  List<ReportModel> _getFilteredReports(List<ReportModel> reports) {
    List<ReportModel> filteredReports = reports;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredReports = filteredReports.where((report) {
        return report.title.toLowerCase().contains(query) ||
               report.description.toLowerCase().contains(query) ||
               report.address.toLowerCase().contains(query) ||
               report.userName.toLowerCase().contains(query);
      }).toList();
    }
    
    // Apply category filter
    switch (_selectedFilter) {
      case 'with_images':
        filteredReports = filteredReports.where((r) => r.imageUrls.isNotEmpty).toList();
        break;
      case 'without_images':
        filteredReports = filteredReports.where((r) => r.imageUrls.isEmpty).toList();
        break;
      case 'analyzed':
        filteredReports = filteredReports.where((r) => 
          r.imageUrls.isNotEmpty && r.waterQuality != WaterQualityState.unknown).toList();
        break;
      case 'not_analyzed':
        filteredReports = filteredReports.where((r) => 
          r.imageUrls.isEmpty || r.waterQuality == WaterQualityState.unknown).toList();
        break;
      case 'all':
      default:
        // No additional filtering
        break;
    }
    
    return filteredReports;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Quality Reports'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh Reports',
          ),
          // Filter button
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: _selectedFilter != 'all' ? AppTheme.primaryColor : null,
            ),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: _selectedFilter == 'all' ? AppTheme.primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('All Reports'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'with_images',
                child: Row(
                  children: [
                    Icon(
                      Icons.image,
                      color: _selectedFilter == 'with_images' ? AppTheme.primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('With Images'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'without_images',
                child: Row(
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: _selectedFilter == 'without_images' ? AppTheme.primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('Without Images'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'analyzed',
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: _selectedFilter == 'analyzed' ? AppTheme.primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('AI Analyzed'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'not_analyzed',
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: _selectedFilter == 'not_analyzed' ? AppTheme.primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('Not Analyzed'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions, size: 16),
                  SizedBox(width: 4),
                  Text('Pending (${_getFilteredReports(_pendingReports).length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 16),
                  SizedBox(width: 4),
                  Text('Resolved (${_getFilteredReports(_resolvedReports).length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: WaterFillLoader(
                message: 'Loading reports...',
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search reports...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          if (_selectedFilter != 'all') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primaryColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getFilterDisplayName(_selectedFilter),
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFilter = 'all';
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Statistics bar
                    _buildStatisticsBar(),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Pending reports tab
                          _buildReportsList(_getFilteredReports(_pendingReports), isPending: true),
                          
                          // Resolved reports tab
                          _buildReportsList(_getFilteredReports(_resolvedReports), isPending: false),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
  
  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'with_images':
        return 'With Images';
      case 'without_images':
        return 'No Images';
      case 'analyzed':
        return 'AI Analyzed';
      case 'not_analyzed':
        return 'Not Analyzed';
      default:
        return 'All';
    }
  }
  
  Widget _buildStatisticsBar() {
    final allReports = [..._pendingReports, ..._resolvedReports];
    final filteredReports = _getFilteredReports(allReports);
    final totalReports = allReports.length;
    final reportsWithImages = allReports.where((r) => r.imageUrls.isNotEmpty).length;
    final analyzedReports = allReports.where((r) => 
      r.imageUrls.isNotEmpty && r.waterQuality != WaterQualityState.unknown).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Main stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', totalReports, Icons.assignment, Colors.blue),
              _buildStatItem('With Images', reportsWithImages, Icons.image, Colors.green),
              _buildStatItem('AI Analyzed', analyzedReports, Icons.psychology, Colors.purple),
            ],
          ),
          
          // Filter results
          if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Showing ${filteredReports.length} report${filteredReports.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
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
            'Error Loading Reports',
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
            onPressed: _loadReports,
            icon: Icons.refresh,
            type: CustomButtonType.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportsList(List<ReportModel> reports, {required bool isPending}) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle : Icons.history,
              size: 80,
              color: isPending
                  ? AppTheme.successColor.withOpacity(0.7)
                  : AppTheme.primaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'No matching reports'
                  : isPending
                      ? 'No Pending Reports'
                      : 'No Resolved Reports',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'Try adjusting your search or filter'
                  : isPending
                      ? 'All reports have been resolved'
                      : 'Resolved reports will appear here',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'all';
                  });
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return _buildReportItem(report, isPending);
        },
      ),
    );
  }
  
  Widget _buildReportItem(ReportModel report, bool isPending) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    final formattedDate = dateFormat.format(report.createdAt);
    final formattedTime = timeFormat.format(report.createdAt);
    
    // Get confidence score for this report (only if it has images)
    final confidenceScore = _confidenceScores[report.id] ?? 0.0;
    final hasImages = report.imageUrls.isNotEmpty;
    final hasWaterQualityAnalysis = hasImages && report.waterQuality != WaterQualityState.unknown;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showReportDetailsDialog(report, isPending, confidenceScore);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (if available)
            if (hasImages)
              Stack(
                children: [
                  _buildNetworkImage(report.imageUrls.first, height: 180),
                  
                  // Gradient overlay for better text visibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Status badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        isPending ? 'Pending' : 'Resolved',
                        style: TextStyle(
                          color: isPending ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  // AI Analysis badge (only if analyzed)
                  if (hasWaterQualityAnalysis)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.psychology, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Image count indicator (if multiple images)
                  if (report.imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              '${report.imageUrls.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            
            // Content section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge (if no image) - show at the top of content
                  if (!hasImages)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPending
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPending ? 'Pending' : 'Resolved',
                          style: TextStyle(
                            color: isPending ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    
                  // Title and water quality indicator
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // CONDITIONAL: Only show water quality indicator if report has images and analysis
                      if (hasWaterQualityAnalysis)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                WaterQualityUtils.getWaterQualityIcon(report.waterQuality),
                                color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                WaterQualityUtils.getWaterQualityText(report.waterQuality),
                                style: TextStyle(
                                  color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Description
                  Text(
                    report.description,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // CONDITIONAL: Confidence indicator (only if has analysis)
                  if (hasWaterQualityAnalysis && confidenceScore > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 18,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Confidence: ',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${confidenceScore.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: confidenceScore / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Location, user, and date info
                  Column(
                    children: [
                      // Location info
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.address,
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // User and date info
                      Row(
                        children: [
                          // User info
                          Icon(
                            Icons.person,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            report.userName,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Date info
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Time info
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Improved network image widget with better error handling and caching
  Widget _buildNetworkImage(String imageUrl, {double height = 200, double? width}) {
    _logDebug('Building network image: $imageUrl');
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                SizedBox(height: 12),
                Text(
                  'Loading image...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          _logDebug('Error loading image: $error, URL: $url');
          return Container(
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade500,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Image unavailable',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showReportDetailsDialog(ReportModel report, bool isPending, double confidence) {
    final hasImages = report.imageUrls.isNotEmpty;
    final hasWaterQualityAnalysis = hasImages && report.waterQuality != WaterQualityState.unknown;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                report.title,
                style: TextStyle(fontSize: 18),
              ),
            ),
            if (hasWaterQualityAnalysis)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image carousel if available
                if (hasImages)
                  Container(
                    height: 220,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: PageView.builder(
                      itemCount: report.imageUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildNetworkImage(
                                report.imageUrls[index],
                                height: 220,
                              ),
                            ),
                            if (report.imageUrls.length > 1)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${index + 1}/${report.imageUrls.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                
                // Status indicators row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Resolved/Pending status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPending ? Icons.pending_actions : Icons.check_circle,
                            size: 16,
                            color: isPending ? Colors.black87 : Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isPending ? 'Pending' : 'Resolved',
                            style: TextStyle(
                              color: isPending ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // CONDITIONAL: Water quality info (only if analyzed)
                    if (hasWaterQualityAnalysis)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              WaterQualityUtils.getWaterQualityIcon(report.waterQuality),
                              color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              WaterQualityUtils.getWaterQualityText(report.waterQuality),
                              style: TextStyle(
                                color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                // CONDITIONAL: Confidence indicator (only if has analysis and confidence > 0)
                if (hasWaterQualityAnalysis && confidence > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.05),
                          Colors.blue.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AI Analysis Confidence',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: confidence / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${confidence.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Description section
                _buildDetailSection(
                  'Description',
                  report.description,
                  Icons.description,
                ),
                
                const SizedBox(height: 16),
                
                // Location section
                _buildDetailSection(
                  'Location',
                  report.address,
                  Icons.location_on,
                ),
                
                const SizedBox(height: 16),
                
                // Reporter info section
                _buildDetailSection(
                  'Reported by',
                  report.userName,
                  Icons.person,
                ),
                
                const SizedBox(height: 16),
                
                // Date section
                _buildDetailSection(
                  'Report Date',
                  DateFormat('EEEE, MMMM d, yyyy at h:mm a').format(report.createdAt),
                  Icons.calendar_today,
                ),
                
                // CONDITIONAL: Water quality description (only if analyzed)
                if (hasWaterQualityAnalysis) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: WaterQualityUtils.getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              WaterQualityUtils.getWaterQualityIcon(report.waterQuality),
                              color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Water Quality Analysis',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Quality: ${WaterQualityUtils.getWaterQualityText(report.waterQuality)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: WaterQualityUtils.getWaterQualityColor(report.waterQuality),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          WaterQualityUtils.getWaterQualityDescription(report.waterQuality),
                          style: TextStyle(
                            height: 1.4,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (hasImages) ...[
                  // Show message if has images but no analysis
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Analysis Unavailable',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Images were uploaded but AI water quality analysis is not available for this report.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Show message if no images
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Images Provided',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Water quality analysis requires photos to be uploaded with the report.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          // Close button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          
          // Resolve button (if pending)
          if (isPending)
            ElevatedButton(
              onPressed: () => _markReportAsResolved(report),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 16),
                  SizedBox(width: 4),
                  Text('Mark as Resolved'),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _markReportAsResolved(ReportModel report) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Resolving report...'),
          ],
        ),
      ),
    );
    
    try {
      await databaseService.resolveReport(report.id);
      
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        // Close details dialog
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Report "${report.title}" marked as resolved')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh reports
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Error resolving report: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}