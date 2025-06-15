// lib/services/database_service.dart - LOCAL STORAGE VERSION
// Key changes: Handle local file paths instead of Firebase URLs

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:aquascan/models/route_model.dart';
import '../models/report_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool _debugMode = true; // Enable debugging
  
  // Helper method for debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      print('🔥 DatabaseService: $message');
    }
  }
  
  // REPORTS - Updated for local storage paths
  
  // Create a new report with local file path validation
  Future<String> createReport(ReportModel report) async {
    try {
      _logDebug('Creating new report with title: ${report.title}');
      
      // Validate local image paths before saving to database
      List<String> validatedImagePaths = [];
      if (report.imageUrls.isNotEmpty) {
        _logDebug('Report has ${report.imageUrls.length} image paths');
        
        for (int i = 0; i < report.imageUrls.length; i++) {
          final imagePath = report.imageUrls[i];
          if (imagePath.isNotEmpty) {
            // Check if it's a local file path
            if (imagePath.startsWith('/')) {
              // It's a local file path
              final file = File(imagePath);
              if (await file.exists()) {
                _logDebug('Local image ${i+1} is valid: $imagePath');
                validatedImagePaths.add(imagePath);
              } else {
                _logDebug('WARNING: Local image ${i+1} does not exist: $imagePath');
                // Still add it to database - file might be moved temporarily
                validatedImagePaths.add(imagePath);
              }
            } else if (imagePath.startsWith('http')) {
              // It's a URL (legacy Firebase URLs)
              _logDebug('Legacy URL ${i+1}: $imagePath');
              validatedImagePaths.add(imagePath);
            } else {
              _logDebug('WARNING: Unknown image path format: $imagePath');
              validatedImagePaths.add(imagePath);
            }
          } else {
            _logDebug('WARNING: Empty image path at index ${i+1}');
          }
        }
        
        _logDebug('Validated ${validatedImagePaths.length} paths out of ${report.imageUrls.length}');
      }
      
      // Create a copy of the report with validated paths
      final validatedReport = validatedImagePaths.length == report.imageUrls.length
          ? report
          : report.copyWith(imageUrls: validatedImagePaths);
      
      final reportRef = _firestore.collection('reports').doc();
      final reportWithId = validatedReport.copyWith(id: reportRef.id);
      
      _logDebug('Saving report to Firestore with ID: ${reportRef.id}');
      await reportRef.set(reportWithId.toJson());
      _logDebug('Report saved successfully with ${validatedImagePaths.length} local images');
      
      return reportRef.id;
    } catch (e) {
      _logDebug('Error creating report: $e');
      throw Exception('Failed to create report: $e');
    }
  }
  
  // Get a specific report with local path validation
  Future<ReportModel> getReport(String reportId) async {
    try {
      _logDebug('Fetching report with ID: $reportId');
      final doc = await _firestore.collection('reports').doc(reportId).get();
      
      if (doc.exists) {
        final reportData = doc.data()!;
        _logDebug('Report found');
        
        // Validate and log image paths
        if (reportData.containsKey('imageUrls')) {
          final imagePaths = reportData['imageUrls'] as List<dynamic>;
          _logDebug('Report has ${imagePaths.length} image paths');
          
          for (int i = 0; i < imagePaths.length; i++) {
            final imagePath = imagePaths[i].toString();
            _logDebug('Image ${i+1}: $imagePath');
            
            // Check if local file exists
            if (imagePath.startsWith('/')) {
              final file = File(imagePath);
              final exists = await file.exists();
              _logDebug('  Local file exists: $exists');
              
              if (exists) {
                final size = await file.length();
                _logDebug('  File size: ${(size / 1024).toStringAsFixed(2)} KB');
              }
            }
          }
        } else {
          _logDebug('Report has no imageUrls field');
        }
        
        return ReportModel.fromJson(reportData);
      } else {
        _logDebug('Report not found with ID: $reportId');
        throw Exception('Report not found');
      }
    } catch (e) {
      _logDebug('Error getting report: $e');
      throw Exception('Failed to get report: $e');
    }
  }
  
  // Get unresolved reports with local path verification
  Future<List<ReportModel>> getUnresolvedReportsList() async {
    try {
      _logDebug('Fetching unresolved reports');
      final snapshot = await _firestore
          .collection('reports')
          .where('isResolved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      
      _logDebug('Found ${snapshot.docs.length} unresolved reports');
      
      List<ReportModel> reports = [];
      int localImageCount = 0;
      int urlImageCount = 0;
      
      for (var doc in snapshot.docs) {
        try {
          final report = ReportModel.fromJson(doc.data());
          
          // Log report image paths and verify local files
          _logDebug('Report ${report.id}: ${report.title}');
          _logDebug('Report has ${report.imageUrls.length} images');
          
          for (int i = 0; i < report.imageUrls.length; i++) {
            final imagePath = report.imageUrls[i];
            if (imagePath.startsWith('/')) {
              localImageCount++;
              final file = File(imagePath);
              final exists = await file.exists();
              _logDebug('  Local image ${i+1}: exists=$exists, path=$imagePath');
            } else if (imagePath.startsWith('http')) {
              urlImageCount++;
              _logDebug('  URL image ${i+1}: $imagePath');
            }
          }
          
          reports.add(report);
        } catch (e) {
          _logDebug('Error parsing report ${doc.id}: $e');
          // Continue processing other reports
        }
      }
      
      _logDebug('Summary: $localImageCount local images, $urlImageCount URL images');
      return reports;
    } catch (e) {
      _logDebug('Error getting unresolved reports: $e');
      throw Exception('Failed to get unresolved reports: $e');
    }
  }
  
  // Get resolved reports with local path verification
  Future<List<ReportModel>> getResolvedReportsList() async {
    try {
      _logDebug('Fetching resolved reports');
      final snapshot = await _firestore
          .collection('reports')
          .where('isResolved', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      _logDebug('Found ${snapshot.docs.length} resolved reports');
      
      List<ReportModel> reports = [];
      for (var doc in snapshot.docs) {
        try {
          final report = ReportModel.fromJson(doc.data());
          reports.add(report);
        } catch (e) {
          _logDebug('Error parsing report ${doc.id}: $e');
          // Continue processing other reports
        }
      }
      
      return reports;
    } catch (e) {
      _logDebug('Error getting resolved reports: $e');
      throw Exception('Failed to get resolved reports: $e');
    }
  }
  
  // Mark a report as resolved
  Future<void> resolveReport(String reportId) async {
    try {
      _logDebug('Marking report as resolved: $reportId');
      await _firestore.collection('reports').doc(reportId).update({
        'isResolved': true,
        'updatedAt': DateTime.now(),
      });
      _logDebug('Report resolved successfully');
    } catch (e) {
      _logDebug('Error resolving report: $e');
      throw Exception('Failed to resolve report: $e');
    }
  }
  
  // Get all reports with enhanced local storage info
  Stream<List<ReportModel>> getReports() {
    _logDebug('Setting up stream for all reports');
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      _logDebug('Reports stream update: ${snapshot.docs.length} documents');
      List<ReportModel> reports = [];
      
      for (var doc in snapshot.docs) {
        try {
          final report = ReportModel.fromJson(doc.data());
          reports.add(report);
        } catch (e) {
          _logDebug('Error parsing report in stream ${doc.id}: $e');
          // Continue with other reports
        }
      }
      
      return reports;
    });
  }
  
  // Get reports by user
  Stream<List<ReportModel>> getUserReports(String userId) {
    _logDebug('Setting up stream for user reports: $userId');
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      _logDebug('User reports stream update: ${snapshot.docs.length} documents');
      List<ReportModel> reports = [];
      
      for (var doc in snapshot.docs) {
        try {
          reports.add(ReportModel.fromJson(doc.data()));
        } catch (e) {
          _logDebug('Error parsing user report in stream ${doc.id}: $e');
          // Continue with other reports
        }
      }
      
      return reports;
    });
  }
  
  // Get unresolved reports stream
  Stream<List<ReportModel>> getUnresolvedReports() {
    _logDebug('Setting up stream for unresolved reports');
    return _firestore
        .collection('reports')
        .where('isResolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      _logDebug('Unresolved reports stream update: ${snapshot.docs.length} documents');
      List<ReportModel> reports = [];
      
      for (var doc in snapshot.docs) {
        try {
          reports.add(ReportModel.fromJson(doc.data()));
        } catch (e) {
          _logDebug('Error parsing unresolved report in stream ${doc.id}: $e');
          // Continue with other reports
        }
      }
      
      return reports;
    });
  }
  
  // Update a report
  Future<void> updateReport(String reportId, Map<String, dynamic> data) async {
    try {
      _logDebug('Updating report: $reportId');
      data['updatedAt'] = DateTime.now();
      await _firestore.collection('reports').doc(reportId).update(data);
      _logDebug('Report updated successfully');
    } catch (e) {
      _logDebug('Error updating report: $e');
      throw Exception('Failed to update report: $e');
    }
  }

  // Delete a report (with local file cleanup option)
  Future<void> deleteReport(String reportId, {bool deleteLocalFiles = false}) async {
    try {
      _logDebug('Deleting report: $reportId');
      
      if (deleteLocalFiles) {
        // Get report first to access image paths
        try {
          final report = await getReport(reportId);
          _logDebug('Attempting to delete ${report.imageUrls.length} local files');
          
          for (final imagePath in report.imageUrls) {
            if (imagePath.startsWith('/')) {
              // It's a local file path
              final file = File(imagePath);
              if (await file.exists()) {
                await file.delete();
                _logDebug('Deleted local file: $imagePath');
              } else {
                _logDebug('Local file not found (already deleted?): $imagePath');
              }
            }
          }
        } catch (e) {
          _logDebug('Error deleting local files for report $reportId: $e');
          // Continue with database deletion even if file deletion fails
        }
      }
      
      await _firestore.collection('reports').doc(reportId).delete();
      _logDebug('Report deleted successfully from database');
    } catch (e) {
      _logDebug('Error deleting report: $e');
      throw Exception('Failed to delete report: $e');
    }
  }
  
  // NEW: Get local storage statistics for reports
  Future<Map<String, dynamic>> getLocalStorageStats() async {
    try {
      _logDebug('Calculating local storage statistics...');
      
      final snapshot = await _firestore.collection('reports').get();
      
      int totalReports = snapshot.docs.length;
      int reportsWithLocalImages = 0;
      int reportsWithUrlImages = 0;
      int totalLocalImages = 0;
      int totalUrlImages = 0;
      int existingLocalImages = 0;
      int missingLocalImages = 0;
      
      for (var doc in snapshot.docs) {
        try {
          final reportData = doc.data();
          final imageUrls = reportData['imageUrls'] as List<dynamic>? ?? [];
          
          bool hasLocalImages = false;
          bool hasUrlImages = false;
          
          for (final imagePath in imageUrls) {
            final pathStr = imagePath.toString();
            
            if (pathStr.startsWith('/')) {
              // Local file path
              totalLocalImages++;
              hasLocalImages = true;
              
              final file = File(pathStr);
              if (await file.exists()) {
                existingLocalImages++;
              } else {
                missingLocalImages++;
              }
            } else if (pathStr.startsWith('http')) {
              // URL (Firebase or other)
              totalUrlImages++;
              hasUrlImages = true;
            }
          }
          
          if (hasLocalImages) reportsWithLocalImages++;
          if (hasUrlImages) reportsWithUrlImages++;
          
        } catch (e) {
          _logDebug('Error processing report ${doc.id} in stats: $e');
        }
      }
      
      final stats = {
        'total_reports': totalReports,
        'reports_with_local_images': reportsWithLocalImages,
        'reports_with_url_images': reportsWithUrlImages,
        'total_local_images': totalLocalImages,
        'total_url_images': totalUrlImages,
        'existing_local_images': existingLocalImages,
        'missing_local_images': missingLocalImages,
        'local_image_integrity': totalLocalImages > 0 
            ? (existingLocalImages / totalLocalImages * 100).toStringAsFixed(1)
            : '0.0',
      };
      
      _logDebug('Local storage stats: $stats');
      return stats;
      
    } catch (e) {
      _logDebug('Error calculating local storage stats: $e');
      return {
        'total_reports': 0,
        'reports_with_local_images': 0,
        'reports_with_url_images': 0,
        'total_local_images': 0,
        'total_url_images': 0,
        'existing_local_images': 0,
        'missing_local_images': 0,
        'local_image_integrity': '0.0',
      };
    }
  }
  
  // NEW: Verify and repair local image paths in database
  Future<Map<String, dynamic>> verifyAndRepairLocalImages() async {
    try {
      _logDebug('Starting local image verification and repair...');
      
      final snapshot = await _firestore.collection('reports').get();
      
      int totalReports = snapshot.docs.length;
      int reportsProcessed = 0;
      int imagesVerified = 0;
      int imagesRepaired = 0;
      int imagesRemoved = 0;
      List<String> repairedReports = [];
      
      for (var doc in snapshot.docs) {
        try {
          final reportData = doc.data();
          final imageUrls = reportData['imageUrls'] as List<dynamic>? ?? [];
          
          List<String> validImagePaths = [];
          bool needsRepair = false;
          
          for (final imagePath in imageUrls) {
            final pathStr = imagePath.toString();
            
            if (pathStr.startsWith('/')) {
              // Local file path - verify existence
              final file = File(pathStr);
              if (await file.exists()) {
                validImagePaths.add(pathStr);
                imagesVerified++;
              } else {
                _logDebug('Missing local file in report ${doc.id}: $pathStr');
                needsRepair = true;
                imagesRemoved++;
                // Don't add to validImagePaths - effectively removes it
              }
            } else if (pathStr.startsWith('http')) {
              // URL - keep as is
              validImagePaths.add(pathStr);
              imagesVerified++;
            } else if (pathStr.isNotEmpty) {
              // Unknown format but not empty - keep with warning
              _logDebug('Unknown image path format in ${doc.id}: $pathStr');
              validImagePaths.add(pathStr);
              imagesVerified++;
            }
          }
          
          // Update report if repair is needed
          if (needsRepair) {
            await _firestore.collection('reports').doc(doc.id).update({
              'imageUrls': validImagePaths,
              'updatedAt': DateTime.now(),
            });
            
            repairedReports.add(doc.id);
            imagesRepaired++;
            _logDebug('Repaired report ${doc.id}: removed ${imageUrls.length - validImagePaths.length} missing images');
          }
          
          reportsProcessed++;
          
        } catch (e) {
          _logDebug('Error processing report ${doc.id} during repair: $e');
        }
      }
      
      final result = {
        'total_reports': totalReports,
        'reports_processed': reportsProcessed,
        'images_verified': imagesVerified,
        'images_repaired': imagesRepaired,
        'images_removed': imagesRemoved,
        'repaired_reports_count': repairedReports.length,
        'repaired_report_ids': repairedReports,
      };
      
      _logDebug('Verification and repair complete: $result');
      return result;
      
    } catch (e) {
      _logDebug('Error during local image verification: $e');
      throw Exception('Failed to verify local images: $e');
    }
  }
  
  // ROUTES - Keep existing functionality unchanged
  
  // Create a new route
  Future<String> createRoute(Map<String, dynamic> routeData) async {
    try {
      _logDebug('Creating new route');
      final routeRef = _firestore.collection('routes').doc();
      final routeId = routeData['id'] ?? routeRef.id;
      
      // Add ID if not provided
      if (!routeData.containsKey('id') || routeData['id'] == null) {
        routeData['id'] = routeId;
      }
      
      // Convert timestamps
      if (routeData.containsKey('createdAt') && 
          !(routeData['createdAt'] is firestore.Timestamp)) {
        if (routeData['createdAt'] is DateTime) {
          routeData['createdAt'] = firestore.Timestamp.fromDate(routeData['createdAt']);
        } else if (routeData['createdAt'] is String) {
          routeData['createdAt'] = firestore.Timestamp.fromDate(
            DateTime.parse(routeData['createdAt']));
        } else {
          routeData['createdAt'] = firestore.Timestamp.now();
        }
      } else if (!routeData.containsKey('createdAt')) {
        routeData['createdAt'] = firestore.Timestamp.now();
      }
      
      if (routeData.containsKey('updatedAt') && 
          !(routeData['updatedAt'] is firestore.Timestamp)) {
        if (routeData['updatedAt'] is DateTime) {
          routeData['updatedAt'] = firestore.Timestamp.fromDate(routeData['updatedAt']);
        } else if (routeData['updatedAt'] is String) {
          routeData['updatedAt'] = firestore.Timestamp.fromDate(
            DateTime.parse(routeData['updatedAt']));
        } else {
          routeData['updatedAt'] = firestore.Timestamp.now();
        }
      } else if (!routeData.containsKey('updatedAt')) {
        routeData['updatedAt'] = firestore.Timestamp.now();
      }
      
      _logDebug('Saving route to Firestore with ID: $routeId');
      await _firestore.collection('routes').doc(routeId).set(routeData);
      _logDebug('Route saved successfully');
      
      return routeId;
    } catch (e) {
      _logDebug('Error creating route: $e');
      throw Exception('Failed to create route: $e');
    }
  }
  
  // Get a specific route
  Future<RouteModel> getRoute(String routeId) async {
    try {
      _logDebug('Fetching route with ID: $routeId');
      final doc = await _firestore.collection('routes').doc(routeId).get();
      
      if (doc.exists) {
        _logDebug('Route found');
        return RouteModel.fromJson(doc.data()!);
      } else {
        _logDebug('Route not found with ID: $routeId');
        throw Exception('Route not found');
      }
    } catch (e) {
      _logDebug('Error getting route: $e');
      throw Exception('Failed to get route: $e');
    }
  }
  
  // Get all routes
  Stream<List<RouteModel>> getRoutes() {
    _logDebug('Setting up stream for all routes');
    return _firestore
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      _logDebug('Routes stream update: ${snapshot.docs.length} documents');
      
      List<RouteModel> routes = [];
      for (var doc in snapshot.docs) {
        try {
          routes.add(RouteModel.fromJson(doc.data()));
        } catch (e) {
          _logDebug('Error parsing route in stream ${doc.id}: $e');
          // Continue with other routes
        }
      }
      
      return routes;
    });
  }
}