// lib/services/api_service.dart - FIXED to work with your real backend
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:aquascan/models/route_model.dart' show RouteModel;
import 'package:aquascan/utils/water_quality_utils.dart';
import '../models/report_model.dart';

class WaterQualityResult {
  final WaterQualityState quality;
  final double confidence;
  
  WaterQualityResult({
    required this.quality,
    required this.confidence,
  });
}

class WaterAnalysisResult {
  final WaterQualityState waterQuality;
  final String originalClass;
  final double confidence;
  
  WaterAnalysisResult({
    required this.waterQuality,
    required this.originalClass,
    required this.confidence,
  });
}

class ApiService {
  final String baseUrl;
  
  ApiService({required this.baseUrl});
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };
  
  // Test API connectivity
  Future<bool> testConnection() async {
    try {
      print('Testing API connection to: $baseUrl');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      print('Connection test response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('API connection successful');
        return true;
      } else if (response.statusCode == 404) {
        // Try root endpoint
        try {
          final rootResponse = await http.get(
            Uri.parse(baseUrl),
            headers: _headers,
          ).timeout(const Duration(seconds: 5));
          
          print('Root endpoint response: ${rootResponse.statusCode}');
          return rootResponse.statusCode == 200;
        } catch (e) {
          print('Root endpoint test failed: $e');
          return false;
        }
      } else {
        print('API connection failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('API connection test error: $e');
      return false;
    }
  }

  Future<WaterAnalysisResult> analyzeWaterQualityWithConfidence(File imageFile) async {
    try {
      print('Sending image for water quality analysis to $baseUrl/analyze');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: 'water_image.jpg',
      );
      
      request.files.add(multipartFile);
      
      print('Sending request to analyze water quality...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Received response: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('Response data: $data');
        
        WaterQualityState qualityState = WaterQualityState.unknown;
        double confidenceScore = 0.0;
        String originalClass = "UNKNOWN";
        
        if (data['success'] == true) {
          if (data.containsKey('confidence') && data['confidence'] != null) {
            confidenceScore = double.tryParse(data['confidence'].toString()) ?? 0.0;
          }
          
          if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
            originalClass = data['water_quality_class'].toString();
            print('Water quality class from backend: $originalClass');
            qualityState = WaterQualityUtils.mapWaterQualityClass(originalClass);
            print('Mapped to enum value: $qualityState');
          } 
          else if (data.containsKey('water_quality_index')) {
            final qualityIndex = int.tryParse(data['water_quality_index'].toString()) ?? 4;
            if (qualityIndex >= 0 && qualityIndex < WaterQualityState.values.length) {
              qualityState = WaterQualityState.values[qualityIndex];
              originalClass = qualityState.toString().split('.').last.toUpperCase();
            } else {
              print('Warning: Invalid water_quality_index $qualityIndex');
              qualityState = WaterQualityState.unknown;
            }
          } else {
            print('Warning: No quality information in response');
            qualityState = WaterQualityState.unknown;
          }
        } else {
          print('Error analyzing image: ${data['message']}');
          qualityState = WaterQualityState.unknown;
        }
        
        return WaterAnalysisResult(
          waterQuality: qualityState,
          originalClass: originalClass,
          confidence: confidenceScore,
        );
      } else {
        print('Failed to analyze image: ${responseBody}');
        throw Exception('Failed to analyze image: ${responseBody}');
      }
    } catch (e) {
      print('Error analyzing water quality: $e');
      return WaterAnalysisResult(
        waterQuality: WaterQualityState.unknown,
        originalClass: "ERROR",
        confidence: 0.0,
      );
    }
  }
  
  // MAIN ROUTE OPTIMIZATION - Fixed to work with your backend
  Future<Map<String, dynamic>> getOptimizedRoute(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    try {
      print('🚀 Starting route optimization with your backend...');
      print('📍 Start location: ${startLocation.latitude}, ${startLocation.longitude}');
      print('📊 Reports count: ${reports.length}');
      print('👤 Admin ID: $adminId');
      
      if (reports.isEmpty) {
        throw Exception('No reports provided for route optimization');
      }
      
      if (adminId.isEmpty) {
        throw Exception('Admin ID is required for route optimization');
      }
      
      // STEP 1: Try the new genetic algorithm endpoint (your main backend feature)
      print('🧬 Attempting GA optimization...');
      final gaResult = await _tryGeneticAlgorithmOptimization(reports, startLocation, adminId);
      if (gaResult != null) {
        print('✅ GA optimization successful');
        return gaResult;
      }
      
      // STEP 2: Try the standard route optimization endpoint  
      print('🔄 Trying standard route optimization...');
      final standardResult = await _tryStandardOptimization(reports, startLocation, adminId);
      if (standardResult != null) {
        print('✅ Standard optimization successful');
        return standardResult;
      }
      
      // STEP 3: Try finding nearest points directly
      print('📍 Trying nearest points lookup...');
      final nearestResult = await _tryNearestPointsLookup(startLocation, adminId, reports);
      if (nearestResult != null) {
        print('✅ Nearest points lookup successful');
        return nearestResult;
      }
      
      // If all real attempts fail, this indicates a backend issue
      throw Exception('Backend services are not responding properly. Please check if the Python server is running and has water supply data.');
      
    } catch (e) {
      print('💥 Route optimization error: $e');
      
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw Exception('Request timeout. Please check your internet connection and try again.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Failed to find water supplies: $e');
      }
    }
  }
  
  // Try Genetic Algorithm optimization (your main backend feature)
  Future<Map<String, dynamic>?> _tryGeneticAlgorithmOptimization(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    try {
      final requestData = {
        'admin_id': adminId,
        'current_location': {
          'latitude': startLocation.latitude,
          'longitude': startLocation.longitude,
        },
        'destination_keyword': 'water',
        'max_routes': 10,
        'max_hops': 8,
        'optimization_method': 'genetic',
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route-genetic'),
        headers: _headers,
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 30));
      
      print('🧬 GA Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('🧬 GA Response data: ${data.keys.toList()}');
        
        if (data['success'] == true && data.containsKey('routes') && data['routes'] != null) {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            print('✅ GA found ${routes.length} routes');
            return _convertGAResponseToRouteData(routes[0], requestData, reports);
          }
        }
        
        // Check if there's an error message that can help us debug
        if (data.containsKey('message')) {
          print('🧬 GA message: ${data['message']}');
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ GA optimization failed: $e');
      return null;
    }
  }
  
  // Try standard route optimization 
  Future<Map<String, dynamic>?> _tryStandardOptimization(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    try {
      final requestData = {
        'admin_id': adminId,
        'current_location': {
          'latitude': startLocation.latitude,
          'longitude': startLocation.longitude,
        },
        'destination_keyword': 'water',
        'max_routes': 10,
        'max_hops': 8,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route-advanced'),
        headers: _headers,
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 30));
      
      print('📥 Standard response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data.containsKey('routes') && data['routes'] != null) {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            print('✅ Standard optimization found ${routes.length} routes');
            return _convertRouteResponseToRouteData(routes[0], requestData, reports);
          }
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ Standard optimization failed: $e');
      return null;
    }
  }
  
  // Try nearest points lookup
  Future<Map<String, dynamic>?> _tryNearestPointsLookup(
    GeoPoint startLocation,
    String adminId,
    List<ReportModel> reports,
  ) async {
    try {
      final requestData = {
        'current_location': {
          'latitude': startLocation.latitude,
          'longitude': startLocation.longitude,
        },
        'max_points': 10,
        'max_distance': 5.0,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/find-nearest-points'),
        headers: _headers,
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 15));
      
      print('📍 Nearest points response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data.containsKey('nearest_points')) {
          final nearestPoints = data['nearest_points'] as List;
          if (nearestPoints.isNotEmpty) {
            print('✅ Found ${nearestPoints.length} nearest points');
            return _createRouteFromNearestPoints(nearestPoints, startLocation, adminId, reports);
          }
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ Nearest points lookup failed: $e');
      return null;
    }
  }
  
  // Convert GA response to route data
  Map<String, dynamic> _convertGAResponseToRouteData(
    Map<String, dynamic> gaRoute, 
    Map<String, dynamic> requestData,
    List<ReportModel> reports,
  ) {
    print('🔄 Converting GA response to route data');
    
    // Extract route information from GA response
    final List<Map<String, dynamic>> routePoints = [];
    final List<Map<String, dynamic>> routeSegments = [];
    
    // Add start point
    routePoints.add({
      'nodeId': 'start',
      'location': requestData['current_location'],
      'address': 'Current Location',
      'label': 'Start',
    });
    
    // Add destination point from GA route
    if (gaRoute.containsKey('destination_point')) {
      final destPoint = gaRoute['destination_point'];
      routePoints.add({
        'nodeId': 'ga-destination',
        'location': {
          'latitude': destPoint['latitude'],
          'longitude': destPoint['longitude'],
        },
        'address': destPoint['address'] ?? 'Water Supply Point',
        'label': 'Water Supply',
      });
      
      // Create route segment
      routeSegments.add({
        'from': routePoints[0],
        'to': routePoints[1],
        'distance': gaRoute['total_distance'] ?? 0.0,
        'mode': 'transit',
        'polyline': [
          requestData['current_location'],
          {
            'latitude': destPoint['latitude'],
            'longitude': destPoint['longitude'],
          },
        ],
      });
    }
    
    return {
      'id': 'ga-route-${DateTime.now().millisecondsSinceEpoch}',
      'adminId': requestData['admin_id'],
      'reportIds': reports.map((r) => r.id).toList(),
      'points': routePoints,
      'segments': routeSegments,
      'totalDistance': gaRoute['total_distance']?.toDouble() ?? 0.0,
      'walkingDistance': gaRoute['walking_distance']?.toDouble() ?? 0.0,
      'transitDistance': gaRoute['route_distance']?.toDouble() ?? 0.0,
      'algorithm': 'Genetic Algorithm',
      'fitnessScore': gaRoute['fitness_score'],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  // Convert standard route response to route data
  Map<String, dynamic> _convertRouteResponseToRouteData(
    Map<String, dynamic> route, 
    Map<String, dynamic> requestData,
    List<ReportModel> reports,
  ) {
    print('🔄 Converting standard route response to route data');
    
    final List<Map<String, dynamic>> segments = [];
    final dynamic routeSegments = route['segments'];
    
    if (routeSegments != null && routeSegments is List) {
      for (final segment in routeSegments) {
        if (segment is Map<String, dynamic>) {
          List<Map<String, dynamic>> polyline = [];
          if (segment['polyline'] != null && segment['polyline'] is List) {
            for (final point in segment['polyline']) {
              if (point is Map<String, dynamic>) {
                polyline.add({
                  'latitude': point['latitude'] ?? 0.0,
                  'longitude': point['longitude'] ?? 0.0,
                });
              }
            }
          }
          
          segments.add({
            'from': segment['from'] ?? {},
            'to': segment['to'] ?? {},
            'distance': segment['distance'] ?? 0.0,
            'mode': segment['mode'] ?? 'transit',
            'polyline': polyline,
          });
        }
      }
    }
    
    return {
      'id': 'route-${DateTime.now().millisecondsSinceEpoch}',
      'adminId': requestData['admin_id'],
      'reportIds': reports.map((r) => r.id).toList(),
      'points': route['points'] ?? [],
      'segments': segments,
      'totalDistance': route['total_distance']?.toDouble() ?? 0.0,
      'walkingDistance': route['walking_distance']?.toDouble() ?? 0.0,
      'transitDistance': route['route_distance']?.toDouble() ?? 0.0,
      'algorithm': 'Standard Route Optimization',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  // Create route from nearest points
  Map<String, dynamic> _createRouteFromNearestPoints(
    List<dynamic> nearestPoints, 
    GeoPoint startLocation, 
    String adminId, 
    List<ReportModel> reports
  ) {
    print('📍 Creating route from ${nearestPoints.length} nearest points');
    
    final List<Map<String, dynamic>> routePoints = [];
    final List<Map<String, dynamic>> routeSegments = [];
    
    // Add start point
    routePoints.add({
      'nodeId': 'start',
      'location': {
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      },
      'address': 'Current Location',
      'label': 'Start',
    });
    
    // Add the closest water supply point
    final closestPoint = nearestPoints[0];
    final waterSupplyLocation = {
      'latitude': closestPoint['latitude'] ?? closestPoint['location']['latitude'],
      'longitude': closestPoint['longitude'] ?? closestPoint['location']['longitude'],
    };
    
    routePoints.add({
      'nodeId': 'supply-closest',
      'location': waterSupplyLocation,
      'address': closestPoint['address'] ?? closestPoint['name'] ?? 'Water Supply Point',
      'label': 'Closest Water Supply',
    });
    
    // Create a segment from start to water supply
    routeSegments.add({
      'from': routePoints[0],
      'to': routePoints[1],
      'distance': closestPoint['distance_km'] ?? _calculateDistance(
        startLocation.latitude,
        startLocation.longitude,
        waterSupplyLocation['latitude'],
        waterSupplyLocation['longitude'],
      ),
      'mode': 'transit',
      'polyline': [
        {
          'latitude': startLocation.latitude,
          'longitude': startLocation.longitude,
        },
        waterSupplyLocation,
      ],
    });
    
    final totalDistance = routeSegments.fold(0.0, (sum, segment) => sum + (segment['distance'] as double));
    
    return {
      'id': 'nearest-route-${DateTime.now().millisecondsSinceEpoch}',
      'adminId': adminId,
      'reportIds': reports.map((r) => r.id).toList(),
      'points': routePoints,
      'segments': routeSegments,
      'totalDistance': totalDistance,
      'walkingDistance': Math.min(0.5, totalDistance * 0.2),
      'transitDistance': totalDistance,
      'algorithm': 'Nearest Points',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  // Helper: Calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    final double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * (Math.pi / 180);
  }
  
  WaterQualityState mapWaterQualityClass(String waterQualityClass) {
    String className = waterQualityClass.toUpperCase();
    
    if (className.contains('OPTIMUM')) {
      return WaterQualityState.optimum;
    } else if (className.contains('LOW_TEMP') && !className.contains('HIGH_PH')) {
      return WaterQualityState.lowTemp;
    } else if (className.contains('LOW_PH') || className.contains('HIGH_PH')) {
      return WaterQualityState.lowPh;
    } else if (className.contains('HIGH_TEMP') || 
               (className.contains('LOW_TEMP') && className.contains('HIGH_PH'))) {
      return WaterQualityState.lowTempHighPh;
    } else {
      return WaterQualityState.unknown;
    }
  }

  Future<WaterQualityState> analyzeWaterQuality(File imageFile) async {
    try {
      print('Sending image for water quality analysis to $baseUrl/analyze');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: 'water_image.jpg',
      );
      
      request.files.add(multipartFile);
      
      print('Sending request to analyze water quality...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Received response: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('Response data: $data');
        
        if (data['success'] == true) {
          if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
            final String waterQualityClass = data['water_quality_class'].toString();
            print('Water quality class from backend: $waterQualityClass');
            
            final WaterQualityState mappedState = mapWaterQualityClass(waterQualityClass);
            print('Mapped to enum value: $mappedState');
            return mappedState;
          } 
          else if (data.containsKey('water_quality_index')) {
            final qualityIndex = data['water_quality_index'] as int;
            
            if (qualityIndex >= 0 && qualityIndex < WaterQualityState.values.length) {
              return WaterQualityState.values[qualityIndex];
            } else {
              print('Warning: Invalid water_quality_index $qualityIndex');
              return WaterQualityState.unknown;
            }
          } else {
            print('Warning: No quality information in response');
            return WaterQualityState.unknown;
          }
        } else {
          print('Error analyzing image: ${data['message']}');
          return WaterQualityState.unknown;
        }
      } else {
        print('Failed to analyze image: ${responseBody}');
        throw Exception('Failed to analyze image: ${responseBody}');
      }
    } catch (e) {
      print('Error analyzing water quality: $e');
      return WaterQualityState.unknown;
    }
  }
}