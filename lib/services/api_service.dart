// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
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
  // Base URL for our Python backend
  final String baseUrl;
  
  ApiService({required this.baseUrl});
  
  // Headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };
  
  // Utility function to convert API date formats to Timestamp objects
  Map<String, dynamic> convertApiDates(Map<String, dynamic> apiJson) {
    var result = Map<String, dynamic>.from(apiJson);
    
    // Check and convert date fields
    if (result.containsKey('createdAt') && !(result['createdAt'] is firestore.Timestamp)) {
      try {
        DateTime dateTime;
        if (result['createdAt'] is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(result['createdAt']);
        } else if (result['createdAt'] is String) {
          dateTime = DateTime.parse(result['createdAt']);
        } else {
          dateTime = DateTime.now();
        }
        result['createdAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print("Error converting createdAt: $e");
        result['createdAt'] = firestore.Timestamp.now();
      }
    }
    
    if (result.containsKey('updatedAt') && !(result['updatedAt'] is firestore.Timestamp)) {
      try {
        DateTime dateTime;
        if (result['updatedAt'] is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(result['updatedAt']);
        } else if (result['updatedAt'] is String) {
          dateTime = DateTime.parse(result['updatedAt']);
        } else {
          dateTime = DateTime.now();
        }
        result['updatedAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print("Error converting updatedAt: $e");
        result['updatedAt'] = firestore.Timestamp.now();
      }
    }
    
    return result;
  }
  
  // Apply date conversion to all objects in a list
  List<Map<String, dynamic>> convertListDates(List<dynamic> jsonList) {
    return jsonList.map((item) {
      if (item is Map<String, dynamic>) {
        return convertApiDates(item);
      }
      return <String, dynamic>{}; // Return empty map if item is not a Map
    }).toList();
  }
  
  // Process nested objects with dates
  Map<String, dynamic> processNestedObjects(Map<String, dynamic> data) {
    var result = Map<String, dynamic>.from(data);
    
    // Handle nested objects in points array
    if (result.containsKey('points') && result['points'] is List) {
      result['points'] = (result['points'] as List).map((point) {
        if (point is Map<String, dynamic>) {
          return point; // No dates in route points
        }
        return <String, dynamic>{}; // Return empty map if point is not a Map
      }).toList();
    }
    
    // Handle nested objects in segments array
    if (result.containsKey('segments') && result['segments'] is List) {
      result['segments'] = (result['segments'] as List).map((segment) {
        if (segment is Map<String, dynamic>) {
          // Recursively process 'from' and 'to' objects if they exist
          if (segment.containsKey('from') && segment['from'] is Map<String, dynamic>) {
            segment['from'] = segment['from']; // No dates in 'from'
          }
          if (segment.containsKey('to') && segment['to'] is Map<String, dynamic>) {
            segment['to'] = segment['to']; // No dates in 'to'
          }
          return segment;
        }
        return <String, dynamic>{}; // Return empty map if segment is not a Map
      }).toList();
    }
    
    return result;
  }
  
  // Helper method to convert timestamps
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    var result = Map<String, dynamic>.from(data);
    
    // Convert createdAt and updatedAt to Timestamp objects
    if (result.containsKey('createdAt')) {
      try {
        final timestamp = result['createdAt'];
        DateTime dateTime;
        if (timestamp is int) {
          // Milliseconds timestamp
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          // ISO string
          dateTime = DateTime.parse(timestamp);
        } else {
          // Unknown format, use current time
          dateTime = DateTime.now();
        }
        result['createdAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print('Error converting createdAt: $e');
        result['createdAt'] = firestore.Timestamp.now();
      }
    } else {
      // Provide a default if missing
      result['createdAt'] = firestore.Timestamp.now();
    }
    
    if (result.containsKey('updatedAt')) {
      try {
        final timestamp = result['updatedAt'];
        DateTime dateTime;
        if (timestamp is int) {
          // Milliseconds timestamp
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          // ISO string
          dateTime = DateTime.parse(timestamp);
        } else {
          // Unknown format, use current time
          dateTime = DateTime.now();
        }
        result['updatedAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print('Error converting updatedAt: $e');
        result['updatedAt'] = firestore.Timestamp.now();
      }
    } else {
      // Provide a default if missing
      result['updatedAt'] = firestore.Timestamp.now();
    }
    
    return result;
  }
  
  Future<WaterAnalysisResult> getWaterQualityAnalysis(String reportId) async {
  try {
    // In a real implementation, this would call an API endpoint with the report ID
    // For now, we'll simulate a response
    
    // Make HTTP request to get water quality data
    final response = await http.get(
      Uri.parse('$baseUrl/report-analysis/$reportId'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Get the water quality class and confidence
      final String waterQualityClass = data['water_quality_class'] ?? 'UNKNOWN';
      final double confidence = (data['confidence'] != null) 
          ? double.parse(data['confidence'].toString()) 
          : 0.0;
      
      // Map the class to our enum
      final WaterQualityState mappedState = WaterQualityUtils.mapWaterQualityClass(waterQualityClass);
      
      return WaterAnalysisResult(
        waterQuality: mappedState,
        originalClass: waterQualityClass,
        confidence: confidence,
      );
    } else {
      throw Exception('Failed to load water quality data');
    }
  } catch (e) {
    print('Error getting water quality analysis: $e');
    
    // If we can't connect to the API, return a mock result
    // In a real implementation, you might want to handle this differently
    final mockClasses = ['OPTIMUM', 'HIGH_PH', 'LOW_PH', 'LOW_TEMP', 'HIGH_PH; HIGH_TEMP', 'LOW_TEMP;HIGH_PH'];
    final randomClass = mockClasses[DateTime.now().microsecond % mockClasses.length];
    final mockConfidence = 70.0 + (DateTime.now().millisecond % 25);
    
    return WaterAnalysisResult(
      waterQuality: WaterQualityUtils.mapWaterQualityClass(randomClass),
      originalClass: randomClass,
      confidence: mockConfidence,
    );
  }
}

  // Map backend water quality classes to Flutter app's WaterQualityState enum
  WaterQualityState mapWaterQualityClass(String waterQualityClass) {
    // Convert to uppercase for case-insensitive comparison
    String className = waterQualityClass.toUpperCase();
    
    // Define the mapping
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
  
 Future<WaterAnalysisResult> analyzeWaterQualityWithConfidence(File imageFile) async {
  try {
    print('Sending image for water quality analysis to $baseUrl/analyze');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
    
    // Add image file
    final fileStream = http.ByteStream(imageFile.openRead());
    final fileLength = await imageFile.length();
    
    final multipartFile = http.MultipartFile(
      'image',
      fileStream,
      fileLength,
      filename: 'water_image.jpg',
    );
    
    request.files.add(multipartFile);
    
    // Send request
    print('Sending request to analyze water quality...');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    print('Received response: $responseBody');
    
    if (response.statusCode == 200) {
      final data = json.decode(responseBody);
      print('Response data: $data');
      
      // Default values
      WaterQualityState qualityState = WaterQualityState.unknown;
      double confidenceScore = 0.0;
      String originalClass = "UNKNOWN";
      
      // Check if the response has the expected structure
      if (data['success'] == true) {
        
        // Get confidence score
        if (data.containsKey('confidence') && data['confidence'] != null) {
          confidenceScore = double.tryParse(data['confidence'].toString()) ?? 0.0;
        }
        
        // Check if we have a water_quality_class in the response
        if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
          // Get original class string
          originalClass = data['water_quality_class'].toString();
          print('Water quality class from backend: $originalClass');
          
          // Map the class to our enum
          qualityState = WaterQualityUtils.mapWaterQualityClass(originalClass);
          print('Mapped to enum value: $qualityState');
        } 
        // Fallback to water_quality_index if no class
        else if (data.containsKey('water_quality_index')) {
          final qualityIndex = int.tryParse(data['water_quality_index'].toString()) ?? 4;
          
          // Make sure the index is valid for our enum
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
    // Return unknown quality with 0 confidence on error
    return WaterAnalysisResult(
      waterQuality: WaterQualityState.unknown,
      originalClass: "ERROR",
      confidence: 0.0,
    );
  }
}

  // Water quality analysis from image
  Future<WaterQualityState> analyzeWaterQuality(File imageFile) async {
    try {
      print('Sending image for water quality analysis to $baseUrl/analyze');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      
      // Add image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: 'water_image.jpg',
      );
      
      request.files.add(multipartFile);
      
      // Send request
      print('Sending request to analyze water quality...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Received response: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('Response data: $data');
        
        // Check if the response has the expected structure
        if (data['success'] == true) {
          
          // Check if we have a water_quality_class in the response
          if (data.containsKey('water_quality_class') && data['water_quality_class'] != null) {
            // Map the water quality class to our enum
            final String waterQualityClass = data['water_quality_class'].toString();
            print('Water quality class from backend: $waterQualityClass');
            
            final WaterQualityState mappedState = mapWaterQualityClass(waterQualityClass);
            print('Mapped to enum value: $mappedState');
            return mappedState;
          } 
          // Fallback to water_quality_index if no class
          else if (data.containsKey('water_quality_index')) {
            final qualityIndex = data['water_quality_index'] as int;
            
            // Make sure the index is valid for our enum
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
      // Return unknown on error
      return WaterQualityState.unknown;
    }
  }
  
  // Get optimized route for a set of reports
  // In api_service.dart - update the getOptimizedRoute method
Future<Map<String, dynamic>> getOptimizedRoute(
  List<ReportModel> reports,
  GeoPoint startLocation,
  String adminId,
) async {
  try {
    // Prepare request data
    final requestData = {
      'admin_id': adminId,
      'start_location': {
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      },
      'reports': reports.map((report) => {
        'id': report.id,
        'location': {
          'latitude': report.location.latitude,
          'longitude': report.location.longitude,
        },
        'address': report.address,
      }).toList(),
    };
    
    print('Finding closest water supplies for ${reports.length} reports');
    
    // Send request
    final response = await http.post(
      Uri.parse('$baseUrl/optimize-route'),
      headers: _headers,
      body: json.encode(requestData),
    );
    
    if (response.statusCode == 200) {
      print('Received successful response from water supply finder API');
      
      // Safely decode JSON
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } catch (e) {
        print('Error decoding JSON response: $e');
        print('Response content: ${response.body}');
        throw Exception('Invalid JSON response from server: $e');
      }
    } else {
      print('Received error response: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to find nearest water supplies: ${response.body}');
    }
  } catch (e) {
    print('Error finding water supplies: $e');
    throw Exception('Failed to find water supplies: $e');
  }
}
  
  // Ensure required fields are present in the data
  void _ensureRequiredFields(Map<String, dynamic> data) {
    // Check and provide defaults for critical fields
    if (!data.containsKey('id') || data['id'] == null) {
      data['id'] = 'route-${DateTime.now().millisecondsSinceEpoch}';
    }
    
    if (!data.containsKey('adminId') || data['adminId'] == null) {
      data['adminId'] = '';
    }
    
    if (!data.containsKey('reportIds') || data['reportIds'] == null) {
      data['reportIds'] = [];
    }
    
    if (!data.containsKey('points') || data['points'] == null) {
      data['points'] = [];
    }
    
    if (!data.containsKey('segments') || data['segments'] == null) {
      data['segments'] = [];
    }
    
    if (!data.containsKey('totalDistance') || data['totalDistance'] == null) {
      data['totalDistance'] = 0.0;
    }
    
    // Ensure createdAt and updatedAt (handled in _convertTimestamps)
  }
}