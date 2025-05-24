// Updated database_service.dart with better error handling

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
  
  // REPORTS
  
  // Create a new report with improved validation
  Future<String> createReport(ReportModel report) async {
    try {
      _logDebug('Creating new report with title: ${report.title}');
      
      // Validate image URLs before saving to database
      List<String> validatedImageUrls = [];
      if (report.imageUrls.isNotEmpty) {
        _logDebug('Report has ${report.imageUrls.length} image URLs');
        
        for (int i = 0; i < report.imageUrls.length; i++) {
          final url = report.imageUrls[i];
          if (url.isNotEmpty && url.startsWith('http')) {
            _logDebug('Image URL ${i+1} is valid: $url');
            validatedImageUrls.add(url);
          } else {
            _logDebug('WARNING: Skipping invalid image URL: $url');
          }
        }
        
        _logDebug('Validated ${validatedImageUrls.length} URLs out of ${report.imageUrls.length}');
      }
      
      // Create a copy of the report with validated URLs
      final validatedReport = validatedImageUrls.length == report.imageUrls.length
          ? report
          : report.copyWith(imageUrls: validatedImageUrls);
      
      final reportRef = _firestore.collection('reports').doc();
      final reportWithId = validatedReport.copyWith(id: reportRef.id);
      
      _logDebug('Saving report to Firestore with ID: ${reportRef.id}');
      await reportRef.set(reportWithId.toJson());
      _logDebug('Report saved successfully');
      
      return reportRef.id;
    } catch (e) {
      _logDebug('Error creating report: $e');
      throw Exception('Failed to create report: $e');
    }
  }
  
  // Get a specific report with improved error handling
  Future<ReportModel> getReport(String reportId) async {
    try {
      _logDebug('Fetching report with ID: $reportId');
      final doc = await _firestore.collection('reports').doc(reportId).get();
      
      if (doc.exists) {
        final reportData = doc.data()!;
        _logDebug('Report found');
        
        // Log report data for debugging
        if (reportData.containsKey('imageUrls')) {
          final imageUrls = reportData['imageUrls'] as List<dynamic>;
          _logDebug('Report has ${imageUrls.length} image URLs');
          
          for (int i = 0; i < imageUrls.length; i++) {
            _logDebug('Image URL ${i+1}: ${imageUrls[i]}');
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
  
  // Get unresolved reports with improved error handling
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
      for (var doc in snapshot.docs) {
        try {
          final report = ReportModel.fromJson(doc.data());
          
          // Log report image URLs for debugging
          _logDebug('Report ${report.id}: ${report.title}');
          _logDebug('Report has ${report.imageUrls.length} images');
          
          if (report.imageUrls.isNotEmpty) {
            _logDebug('First image URL: ${report.imageUrls.first}');
          }
          
          reports.add(report);
        } catch (e) {
          _logDebug('Error parsing report ${doc.id}: $e');
          // Continue processing other reports
        }
      }
      
      return reports;
    } catch (e) {
      _logDebug('Error getting unresolved reports: $e');
      throw Exception('Failed to get unresolved reports: $e');
    }
  }
  
  // Get resolved reports with improved error handling
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
  
  // Get all reports
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
          reports.add(ReportModel.fromJson(doc.data()));
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
  
  // Get unresolved reports
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

  // Delete a report
  Future<void> deleteReport(String reportId) async {
    try {
      _logDebug('Deleting report: $reportId');
      await _firestore.collection('reports').doc(reportId).delete();
      _logDebug('Report deleted successfully');
    } catch (e) {
      _logDebug('Error deleting report: $e');
      throw Exception('Failed to delete report: $e');
    }
  }
  
  // ROUTES
  
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