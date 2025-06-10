// lib/services/api_service.dart - ENHANCED with Multiple Routes and CSV Support
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

class GAOptimizationRequest {
  final String adminId;
  final GeoPoint currentLocation;
  final String destinationKeyword;
  final int maxRoutes;
  final int maxHops;
  final String optimizationMethod;
  final GAParameters gaConfig;
  
  GAOptimizationRequest({
    required this.adminId,
    required this.currentLocation,
    required this.destinationKeyword,
    this.maxRoutes = 10,
    this.maxHops = 8,
    this.optimizationMethod = 'genetic',
    required this.gaConfig,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'current_location': {
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
      },
      'destination_keyword': destinationKeyword,
      'max_routes': maxRoutes,
      'max_hops': maxHops,
      'optimization_method': optimizationMethod,
      'ga_config': gaConfig.toJson(),
    };
  }
}

class GAParameters {
  final int populationSize;
  final int maxGenerations;
  final int eliteSize;
  final double mutationRate;
  final double crossoverRate;
  final int tournamentSize;
  final int maxRouteLength;
  final double timeLimit;
  final int convergenceThreshold;
  
  GAParameters({
    this.populationSize = 50,
    this.maxGenerations = 100,
    this.eliteSize = 5,
    this.mutationRate = 0.1,
    this.crossoverRate = 0.8,
    this.tournamentSize = 3,
    this.maxRouteLength = 8,
    this.timeLimit = 30.0,
    this.convergenceThreshold = 15,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'population_size': populationSize,
      'max_generations': maxGenerations,
      'elite_size': eliteSize,
      'mutation_rate': mutationRate,
      'crossover_rate': crossoverRate,
      'tournament_size': tournamentSize,
      'max_route_length': maxRouteLength,
      'time_limit': timeLimit,
      'convergence_threshold': convergenceThreshold,
    };
  }
}

class GAOptimizationResult {
  final bool success;
  final String method;
  final int totalRoutes;
  final List<Map<String, dynamic>> routes;
  final Map<String, dynamic> optimizationStats;
  final double executionTimeSeconds;
  final Map<String, dynamic>? algorithmDetails;
  
  GAOptimizationResult({
    required this.success,
    required this.method,
    required this.totalRoutes,
    required this.routes,
    required this.optimizationStats,
    required this.executionTimeSeconds,
    this.algorithmDetails,
  });
  
  factory GAOptimizationResult.fromJson(Map<String, dynamic> json) {
    return GAOptimizationResult(
      success: json['success'] ?? false,
      method: json['method'] ?? 'Unknown',
      totalRoutes: json['total_routes'] ?? 0,
      routes: List<Map<String, dynamic>>.from(json['routes'] ?? []),
      optimizationStats: Map<String, dynamic>.from(json['optimization_stats'] ?? {}),
      executionTimeSeconds: (json['execution_time_seconds'] ?? 0.0).toDouble(),
      algorithmDetails: json['algorithm_details'] != null 
          ? Map<String, dynamic>.from(json['algorithm_details'])
          : null,
    );
  }
}

// NEW: Multiple Routes Request/Response Models
class MultipleRoutesRequest {
  final String adminId;
  final GeoPoint currentLocation;
  final int maxRoutes;
  final double maxDistance;
  final String routeType;
  
  MultipleRoutesRequest({
    required this.adminId,
    required this.currentLocation,
    this.maxRoutes = 5,
    this.maxDistance = 10.0, // km
    this.routeType = 'water_supply',
  });
  
  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'current_location': {
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
      },
      'max_routes': maxRoutes,
      'max_distance': maxDistance,
      'route_type': routeType,
    };
  }
}

class MultipleRoutesResult {
  final bool success;
  final List<Map<String, dynamic>> routes;
  final int shortestRouteIndex;
  final int totalFound;
  final String message;
  
  MultipleRoutesResult({
    required this.success,
    required this.routes,
    required this.shortestRouteIndex,
    required this.totalFound,
    required this.message,
  });
  
  factory MultipleRoutesResult.fromJson(Map<String, dynamic> json) {
    return MultipleRoutesResult(
      success: json['success'] ?? false,
      routes: List<Map<String, dynamic>>.from(json['routes'] ?? []),
      shortestRouteIndex: json['shortest_route_index'] ?? 0,
      totalFound: json['total_found'] ?? 0,
      message: json['message'] ?? '',
    );
  }
}

// NEW: Water Supply Point Model
class WaterSupplyPoint {
  final String id;
  final String streetName;
  final String address;
  final String pointOfInterest;
  final String additionalInfo;
  final double latitude;
  final double longitude;
  final double? distanceFromUser;
  
  WaterSupplyPoint({
    required this.id,
    required this.streetName,
    required this.address,
    required this.pointOfInterest,
    required this.additionalInfo,
    required this.latitude,
    required this.longitude,
    this.distanceFromUser,
  });
  
  factory WaterSupplyPoint.fromJson(Map<String, dynamic> json) {
    return WaterSupplyPoint(
      id: json['id']?.toString() ?? '',
      streetName: json['street_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      pointOfInterest: json['point_of_interest']?.toString() ?? '',
      additionalInfo: json['additional_info']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceFromUser: (json['distance_from_user'] as num?)?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'street_name': streetName,
      'address': address,
      'point_of_interest': pointOfInterest,
      'additional_info': additionalInfo,
      'latitude': latitude,
      'longitude': longitude,
      if (distanceFromUser != null) 'distance_from_user': distanceFromUser,
    };
  }
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
      print('🔗 Testing API connection to: $baseUrl');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      print('🔗 Connection test response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('✅ API connection successful');
        return true;
      } else if (response.statusCode == 404) {
        // Try root endpoint
        try {
          final rootResponse = await http.get(
            Uri.parse(baseUrl),
            headers: _headers,
          ).timeout(const Duration(seconds: 5));
          
          print('🔗 Root endpoint response: ${rootResponse.statusCode}');
          return rootResponse.statusCode == 200;
        } catch (e) {
          print('❌ Root endpoint test failed: $e');
          return false;
        }
      } else {
        print('❌ API connection failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ API connection test error: $e');
      return false;
    }
  }

  // Water Quality Analysis
  Future<WaterAnalysisResult> analyzeWaterQualityWithConfidence(File imageFile) async {
    try {
      print('🔬 Sending image for water quality analysis to $baseUrl/analyze');
      
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
      
      print('📤 Sending request to analyze water quality...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('📥 Received response: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('🔬 Response data: $data');
        
        WaterQualityState qualityState = WaterQualityState.unknown;
        double confidenceScore = 0.0;
        String originalClass = "UNKNOWN";
        
        if (data['success'] == true) {
          if (data.containsKey('confidence') && data['confidence'] != null) {
            confidenceScore = double.tryParse(data['confidence'].toString()) ?? 0.0;
          }
          
          if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
            originalClass = data['water_quality_class'].toString();
            print('🏷️ Water quality class from backend: $originalClass');
            qualityState = WaterQualityUtils.mapWaterQualityClass(originalClass);
            print('🎯 Mapped to enum value: $qualityState');
          } 
          else if (data.containsKey('water_quality_index')) {
            final qualityIndex = int.tryParse(data['water_quality_index'].toString()) ?? 4;
            if (qualityIndex >= 0 && qualityIndex < WaterQualityState.values.length) {
              qualityState = WaterQualityState.values[qualityIndex];
              originalClass = qualityState.toString().split('.').last.toUpperCase();
            } else {
              print('⚠️ Warning: Invalid water_quality_index $qualityIndex');
              qualityState = WaterQualityState.unknown;
            }
          } else {
            print('⚠️ Warning: No quality information in response');
            qualityState = WaterQualityState.unknown;
          }
        } else {
          print('❌ Error analyzing image: ${data['message']}');
          qualityState = WaterQualityState.unknown;
        }
        
        return WaterAnalysisResult(
          waterQuality: qualityState,
          originalClass: originalClass,
          confidence: confidenceScore,
        );
      } else {
        print('❌ Failed to analyze image: ${responseBody}');
        throw Exception('Failed to analyze image: ${responseBody}');
      }
    } catch (e) {
      print('❌ Error analyzing water quality: $e');
      return WaterAnalysisResult(
        waterQuality: WaterQualityState.unknown,
        originalClass: "ERROR",
        confidence: 0.0,
      );
    }
  }
  
  // NEW: Get Water Supply Points from CSV
  Future<Map<String, dynamic>> getWaterSupplyPoints({
    int limit = 100,
    String? region,
  }) async {
    try {
      print('💧 Fetching water supply points from CSV...');
      
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      
      final uri = Uri.parse('$baseUrl/water-supply-points').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      
      print('💧 Water supply points response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('💧 Found ${data['total']} water supply points');
        return data;
      } else {
        throw Exception('Failed to get water supply points: ${response.body}');
      }
    } catch (e) {
      print('❌ Error getting water supply points: $e');
      throw Exception('Failed to get water supply points: $e');
    }
  }
  
  // NEW: Get Multiple Routes to Water Supplies
  Future<MultipleRoutesResult> getMultipleRoutesToWaterSupplies(
    GeoPoint startLocation,
    String adminId, {
    int maxRoutes = 5,
    double maxDistance = 10.0,
  }) async {
    try {
      print('🗺️ Getting multiple routes to water supplies...');
      print('📍 Start: ${startLocation.latitude}, ${startLocation.longitude}');
      print('🎯 Max routes: $maxRoutes, Max distance: ${maxDistance}km');
      
      final request = MultipleRoutesRequest(
        adminId: adminId,
        currentLocation: startLocation,
        maxRoutes: maxRoutes,
        maxDistance: maxDistance,
      );
      
      final response = await http.post(
        Uri.parse('$baseUrl/find-multiple-water-routes'),
        headers: _headers,
        body: json.encode(request.toJson()),
      ).timeout(const Duration(seconds: 30));
      
      print('🗺️ Multiple routes response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = MultipleRoutesResult.fromJson(data);
        
        print('✅ Found ${result.routes.length} routes');
        print('🎯 Shortest route index: ${result.shortestRouteIndex}');
        
        return result;
      } else {
        print('❌ Multiple routes failed: ${response.body}');
        // Fallback to mock data
        return _createMockMultipleRoutes(startLocation, maxRoutes);
      }
    } catch (e) {
      print('❌ Error getting multiple routes: $e');
      // Fallback to mock data
      return _createMockMultipleRoutes(startLocation, maxRoutes);
    }
  }
  
  // NEW: Find Nearest Water Supply Points
  Future<Map<String, dynamic>> findNearestWaterSupplies(
    GeoPoint currentLocation, {
    int maxPoints = 10,
    double maxDistance = 5.0,
  }) async {
    try {
      print('📍 Finding nearest water supplies...');
      
      final requestData = {
        'current_location': {
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
        },
        'max_points': maxPoints,
        'max_distance': maxDistance,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/find-nearest-points'),
        headers: _headers,
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 20));
      
      print('📍 Nearest points response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Found ${data['total_within_range']} nearby water supplies');
        return data;
      } else {
        print('❌ Nearest points failed: ${response.body}');
        return _createMockNearestPoints(currentLocation, maxPoints);
      }
    } catch (e) {
      print('❌ Error finding nearest points: $e');
      return _createMockNearestPoints(currentLocation, maxPoints);
    }
  }
  
  // NEW: Enhanced Route Optimization with CSV Data
  Future<Map<String, dynamic>> optimizeRouteWithCSVData(
    GeoPoint startLocation,
    String adminId,
    String destinationKeyword, {
    int maxRoutes = 3,
    GAParameters? gaParams,
  }) async {
    try {
      print('🚀 Optimizing route with CSV data...');
      
      final requestData = {
        'admin_id': adminId,
        'current_location': {
          'latitude': startLocation.latitude,
          'longitude': startLocation.longitude,
        },
        'destination_keyword': destinationKeyword,
        'max_routes': maxRoutes,
        'use_csv_data': true,
        'optimization_method': 'enhanced_ga',
        if (gaParams != null) 'ga_config': gaParams.toJson(),
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route-with-csv'),
        headers: _headers,
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 60));
      
      print('🚀 CSV route optimization response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ CSV route optimization successful');
        return data;
      } else {
        print('❌ CSV optimization failed: ${response.body}');
        throw Exception('CSV route optimization failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Error in CSV route optimization: $e');
      throw Exception('CSV route optimization failed: $e');
    }
  }
  
  // Mock data creators for fallback scenarios
  Map<String, dynamic> _createMockNearestPoints(GeoPoint location, int maxPoints) {
    print('🎭 Creating mock nearest points data...');
    
    final Math.Random random = Math.Random();
    final List<Map<String, dynamic>> mockPoints = [];
    
    // Create mock water supply points around the location
    for (int i = 0; i < Math.min(maxPoints, 8); i++) {
      final offsetLat = (random.nextDouble() - 0.5) * 0.02; // ~2km radius
      final offsetLng = (random.nextDouble() - 0.5) * 0.02;
      
      final pointLat = location.latitude + offsetLat;
      final pointLng = location.longitude + offsetLng;
      
      final distance = _calculateDistance(
        location.latitude, location.longitude,
        pointLat, pointLng,
      );
      
      mockPoints.add({
        'id': 'mock_water_${i + 1}',
        'street_name': 'Mock Water Point ${i + 1}',
        'address': 'Mock Address ${i + 1}, Test City',
        'point_of_interest': 'Mock Water Supply Station ${i + 1}',
        'additional_info': 'Mock water supply point for testing',
        'latitude': pointLat,
        'longitude': pointLng,
        'distance': distance,
        'estimated_travel_time': '${(distance * 2).round()} min',
      });
    }
    
    // Sort by distance
    mockPoints.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    return {
      'success': true,
      'nearest_points': mockPoints,
      'total_within_range': mockPoints.length,
      'total_available': 20,
      'message': 'Mock data - API service unavailable',
    };
  }
  
  MultipleRoutesResult _createMockMultipleRoutes(GeoPoint location, int maxRoutes) {
    print('🎭 Creating mock multiple routes data...');
    
    final Math.Random random = Math.Random();
    final List<Map<String, dynamic>> mockRoutes = [];
    
    // Create mock routes to different water supplies
    for (int i = 0; i < Math.min(maxRoutes, 5); i++) {
      final offsetLat = (random.nextDouble() - 0.5) * 0.03;
      final offsetLng = (random.nextDouble() - 0.5) * 0.03;
      
      final destinationLat = location.latitude + offsetLat;
      final destinationLng = location.longitude + offsetLng;
      
      final distance = _calculateDistance(
        location.latitude, location.longitude,
        destinationLat, destinationLng,
      );
      
      mockRoutes.add({
        'route_id': 'mock_route_${i + 1}',
        'destination': {
          'id': 'mock_dest_${i + 1}',
          'street_name': 'Mock Water Station ${i + 1}',
          'address': 'Mock Street ${i + 1}, Test Area',
          'point_of_interest': 'Community Water Access Point ${i + 1}',
          'latitude': destinationLat,
          'longitude': destinationLng,
        },
        'distance': distance,
        'estimated_time': '${(distance * 2.5).round()} min',
        'route_quality': 'good',
        'waypoints': [
          {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'name': 'Start Point',
            'address': 'Current Location',
          },
          {
            'latitude': destinationLat,
            'longitude': destinationLng,
            'name': 'Mock Water Station ${i + 1}',
            'address': 'Mock Street ${i + 1}, Test Area',
          },
        ],
      });
    }
    
    // Sort by distance to find shortest
    mockRoutes.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    return MultipleRoutesResult(
      success: true,
      routes: mockRoutes,
      shortestRouteIndex: 0, // First route is shortest after sorting
      totalFound: mockRoutes.length,
      message: 'Mock routes generated - API service unavailable',
    );
  }
  
  // ENHANCED: Main route optimization with GA parameters support
  Future<Map<String, dynamic>> getOptimizedRouteWithGA(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
    GAParameters gaParams,
  ) async {
    try {
      print('🚀 Starting GA route optimization with enhanced parameters...');
      print('📍 Start location: ${startLocation.latitude}, ${startLocation.longitude}');
      print('📊 Reports count: ${reports.length}');
      print('👤 Admin ID: $adminId');
      print('🧬 GA Parameters:');
      print('   Population: ${gaParams.populationSize}');
      print('   Generations: ${gaParams.maxGenerations}');
      print('   Mutation Rate: ${gaParams.mutationRate}');
      print('   Crossover Rate: ${gaParams.crossoverRate}');
      print('   Max Points: ${gaParams.maxRouteLength}');
      
      if (reports.isEmpty) {
        throw Exception('No reports provided for route optimization');
      }
      
      if (adminId.isEmpty) {
        throw Exception('Admin ID is required for route optimization');
      }
      
      // Create GA optimization request
      final gaRequest = GAOptimizationRequest(
        adminId: adminId,
        currentLocation: startLocation,
        destinationKeyword: 'water',
        maxRoutes: 1, // We want the best route
        maxHops: gaParams.maxRouteLength,
        optimizationMethod: 'genetic',
        gaConfig: gaParams,
      );
      
      // STEP 1: Try the enhanced genetic algorithm endpoint
      print('🧬 Attempting enhanced GA optimization...');
      final gaResult = await _tryEnhancedGeneticOptimization(gaRequest);
      if (gaResult != null) {
        print('✅ Enhanced GA optimization successful');
        return _convertGAResultToRouteData(gaResult, gaRequest, reports);
      }
      
      // STEP 2: Try the standard genetic algorithm endpoint  
      print('🔄 Trying standard GA optimization...');
      final standardGAResult = await _tryStandardGeneticOptimization(gaRequest);
      if (standardGAResult != null) {
        print('✅ Standard GA optimization successful');
        return _convertGAResultToRouteData(standardGAResult, gaRequest, reports);
      }
      
      // STEP 3: Try finding nearest points directly
      print('📍 Trying nearest points lookup...');
      final nearestResult = await _tryNearestPointsLookup(startLocation, adminId, reports);
      if (nearestResult != null) {
        print('✅ Nearest points lookup successful');
        return nearestResult;
      }
      
      // If all attempts fail, this indicates a backend issue
      throw Exception('GA optimization services are not responding properly. Please check if the Python server is running with genetic algorithm support.');
      
    } catch (e) {
      print('💥 GA Route optimization error: $e');
      
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw Exception('Request timeout. Please check your internet connection and try again.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Failed to optimize route with GA: $e');
      }
    }
  }
  
  // Try enhanced genetic algorithm optimization with full parameter support
  Future<GAOptimizationResult?> _tryEnhancedGeneticOptimization(GAOptimizationRequest request) async {
    try {
      print('🧬 Sending enhanced GA request...');
      print('   URL: $baseUrl/optimize-route-genetic');
      print('   Parameters: ${request.gaConfig.toJson()}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route-genetic'),
        headers: _headers,
        body: json.encode(request.toJson()),
      ).timeout(Duration(seconds: (request.gaConfig.timeLimit + 10).round()));
      
      print('🧬 Enhanced GA Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('🧬 Enhanced GA Response data keys: ${data.keys.toList()}');
        
        if (data['success'] == true) {
          final result = GAOptimizationResult.fromJson(data);
          
          if (result.routes.isNotEmpty) {
            print('✅ Enhanced GA found ${result.routes.length} routes');
            print('   Best fitness: ${result.optimizationStats['best_fitness']}');
            print('   Generations completed: ${result.algorithmDetails?['generations_completed']}');
            print('   Execution time: ${result.executionTimeSeconds}s');
            return result;
          }
        }
        
        // Check if there's an error message that can help us debug
        if (data.containsKey('message')) {
          print('🧬 Enhanced GA message: ${data['message']}');
        }
      } else {
        print('❌ Enhanced GA failed with status: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
      
      return null;
    } catch (e) {
      print('⚠️ Enhanced GA optimization failed: $e');
      return null;
    }
  }
  
  // Try standard genetic algorithm optimization
  Future<GAOptimizationResult?> _tryStandardGeneticOptimization(GAOptimizationRequest request) async {
    try {
      // Create a simplified request for standard endpoint
      final standardRequest = {
        'admin_id': request.adminId,
        'current_location': {
          'latitude': request.currentLocation.latitude,
          'longitude': request.currentLocation.longitude,
        },
        'destination_keyword': request.destinationKeyword,
        'max_routes': request.maxRoutes,
        'max_hops': request.maxHops,
        'optimization_method': 'genetic',
        'ga_config': request.gaConfig.toJson(),
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route-advanced'),
        headers: _headers,
        body: json.encode(standardRequest),
      ).timeout(Duration(seconds: (request.gaConfig.timeLimit + 10).round()));
      
      print('📥 Standard GA response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data.containsKey('routes') && data['routes'] != null) {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            print('✅ Standard GA found ${routes.length} routes');
            
            // Convert to GAOptimizationResult format
            return GAOptimizationResult(
              success: true,
              method: data['method'] ?? 'Standard Genetic Algorithm',
              totalRoutes: routes.length,
              routes: routes.cast<Map<String, dynamic>>(),
              optimizationStats: data['optimization_stats'] ?? {},
              executionTimeSeconds: (data['execution_time_seconds'] ?? 0.0).toDouble(),
              algorithmDetails: data['algorithm_details'],
            );
          }
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ Standard GA optimization failed: $e');
      return null;
    }
  }
  
  // Convert GA optimization result to route data format
  Map<String, dynamic> _convertGAResultToRouteData(
    GAOptimizationResult gaResult, 
    GAOptimizationRequest request,
    List<ReportModel> reports,
  ) {
    print('🔄 Converting GA result to route data');
    
    if (gaResult.routes.isEmpty) {
      throw Exception('No routes returned from GA optimization');
    }
    
    final bestRoute = gaResult.routes.first;
    
    // Extract route information from GA response
    final List<Map<String, dynamic>> routePoints = [];
    final List<Map<String, dynamic>> routeSegments = [];
    
    // Add start point
    routePoints.add({
      'nodeId': 'start',
      'location': {
        'latitude': request.currentLocation.latitude,
        'longitude': request.currentLocation.longitude,
      },
      'address': 'Current Location',
      'label': 'Start',
    });
    
    // Process route waypoints if available
    if (bestRoute.containsKey('waypoints') && bestRoute['waypoints'] is List) {
      final waypoints = bestRoute['waypoints'] as List;
      
      for (int i = 0; i < waypoints.length; i++) {
        final waypoint = waypoints[i];
        if (waypoint is Map<String, dynamic> && waypoint.containsKey('latitude')) {
          routePoints.add({
            'nodeId': 'water-supply-$i',
            'location': {
              'latitude': waypoint['latitude'],
              'longitude': waypoint['longitude'],
            },
            'address': waypoint['address'] ?? 'Water Supply Point ${i + 1}',
            'label': waypoint['name'] ?? 'Water Supply',
          });
        }
      }
    }
    
    // Create route segments between consecutive points
    for (int i = 0; i < routePoints.length - 1; i++) {
      routeSegments.add({
        'from': routePoints[i],
        'to': routePoints[i + 1],
        'distance': _calculateSegmentDistance(routePoints[i], routePoints[i + 1]),
        'mode': 'transit',
        'polyline': [
          routePoints[i]['location'],
          routePoints[i + 1]['location'],
        ],
      });
    }
    
    // Calculate total distance
    double totalDistance = 0.0;
    if (bestRoute.containsKey('total_distance')) {
      totalDistance = (bestRoute['total_distance'] as num).toDouble();
    } else {
      totalDistance = routeSegments.fold(0.0, (sum, segment) => sum + (segment['distance'] as double));
    }
    
    return {
      'id': 'ga-route-${DateTime.now().millisecondsSinceEpoch}',
      'adminId': request.adminId,
      'reportIds': reports.map((r) => r.id).toList(),
      'points': routePoints,
      'segments': routeSegments,
      'totalDistance': totalDistance,
      'walkingDistance': totalDistance * 0.1, // Estimate 10% walking
      'transitDistance': totalDistance * 0.9,
      'algorithm': gaResult.method,
      'optimization_stats': gaResult.optimizationStats,
      'algorithm_details': gaResult.algorithmDetails,
      'execution_time_seconds': gaResult.executionTimeSeconds,
      'fitness_score': gaResult.optimizationStats['best_fitness'],
      'generations_completed': gaResult.algorithmDetails?['generations_completed'],
      'convergence_status': gaResult.algorithmDetails?['convergence_status'],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  // Calculate distance between two route points
  double _calculateSegmentDistance(Map<String, dynamic> from, Map<String, dynamic> to) {
    final fromLoc = from['location'] as Map<String, dynamic>;
    final toLoc = to['location'] as Map<String, dynamic>;
    
    return _calculateDistance(
      fromLoc['latitude'],
      fromLoc['longitude'], 
      toLoc['latitude'],
      toLoc['longitude'],
    );
  }
  
  // Try nearest points lookup (fallback)
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
      'algorithm': 'Nearest Points Fallback',
      'optimization_stats': {
        'method': 'nearest_points',
        'points_found': nearestPoints.length,
      },
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  // Legacy method - now calls the enhanced GA version
  Future<Map<String, dynamic>> getOptimizedRoute(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    // Use default GA parameters for legacy calls
    final defaultGAParams = GAParameters();
    return await getOptimizedRouteWithGA(reports, startLocation, adminId, defaultGAParams);
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
    final result = await analyzeWaterQualityWithConfidence(imageFile);
    return result.waterQuality;
  }
}