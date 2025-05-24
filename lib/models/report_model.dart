// lib/models/report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum WaterQualityState {
  highPh,       // 'HIGH_PH'
  highPhTemp,   // 'HIGH_PH; HIGH_TEMP'
  lowPh,        // 'LOW_PH'
  lowTemp,      // 'LOW_TEMP'
  lowTempHighPh,// 'LOW_TEMP;HIGH_PH'
  optimum,      // 'OPTIMUM'
  unknown       // Default fallback
}



class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint({
    required this.latitude,
    required this.longitude,
  });

 // In the GeoPoint class

factory GeoPoint.fromJson(Map<String, dynamic> json) {
  double lat = 0.0;
  double lng = 0.0;
  
  try {
    if (json.containsKey('latitude') && json['latitude'] != null) {
      lat = json['latitude'] is double
          ? json['latitude'] as double
          : (json['latitude'] as num).toDouble();
    }
    
    if (json.containsKey('longitude') && json['longitude'] != null) {
      lng = json['longitude'] is double
          ? json['longitude'] as double
          : (json['longitude'] as num).toDouble();
    }
  } catch (e) {
    print('Error parsing GeoPoint coordinates: $e');
    // Use defaults
  }
  
  return GeoPoint(
    latitude: lat,
    longitude: lng,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ReportModel {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String description;
  final GeoPoint location;
  final String address;
  final List<String> imageUrls;
  final WaterQualityState waterQuality;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.location,
    required this.address,
    required this.imageUrls,
    required this.waterQuality,
    required this.isResolved,
    required this.createdAt,
    required this.updatedAt,
  });

static WaterQualityState getStateFromString(String stateString) {
  switch (stateString.toUpperCase()) {
    case 'HIGH_PH':
      return WaterQualityState.highPh;
    case 'HIGH_PH; HIGH_TEMP':
      return WaterQualityState.highPhTemp;
    case 'LOW_PH':
      return WaterQualityState.lowPh;
    case 'LOW_TEMP':
      return WaterQualityState.lowTemp;
    case 'LOW_TEMP;HIGH_PH':
      return WaterQualityState.lowTempHighPh;
    case 'OPTIMUM':
      return WaterQualityState.optimum;
    default:
      return WaterQualityState.unknown;
  }
}

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      address: json['address'] as String,
      imageUrls: List<String>.from(json['imageUrls'] as List),
      waterQuality: WaterQualityState.values[json['waterQuality'] as int],
      isResolved: json['isResolved'] as bool,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'location': location.toJson(),
      'address': address,
      'imageUrls': imageUrls,
      'waterQuality': waterQuality.index,
      'isResolved': isResolved,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ReportModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? description,
    GeoPoint? location,
    String? address,
    List<String>? imageUrls,
    WaterQualityState? waterQuality,
    bool? isResolved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      imageUrls: imageUrls ?? this.imageUrls,
      waterQuality: waterQuality ?? this.waterQuality,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoutePoint {
  final String nodeId;
  final GeoPoint location;
  final String address;
  final String? label;

  RoutePoint({
    required this.nodeId,
    required this.location,
    required this.address,
    this.label,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      nodeId: json['nodeId'] as String,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      address: json['address'] as String,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'location': location.toJson(),
      'address': address,
      'label': label,
    };
  }
}

class RouteSegment {
  final RoutePoint from;
  final RoutePoint to;
  final double distance; // in kilometers
  final List<GeoPoint> polyline;

  RouteSegment({
    required this.from,
    required this.to,
    required this.distance,
    required this.polyline,
  });

 // In the RouteSegment class in route_model.dart:

factory RouteSegment.fromJson(Map<String, dynamic> json) {
  // Safely process polyline data
  List<GeoPoint> polylinePoints = [];
  if (json.containsKey('polyline') && json['polyline'] != null) {
    try {
      final polylineData = json['polyline'] as List<dynamic>;
      polylinePoints = polylineData.map((point) {
        if (point is Map<String, dynamic>) {
          try {
            return GeoPoint.fromJson(point);
          } catch (e) {
            print('Error creating GeoPoint from: $point');
            return GeoPoint(latitude: 0, longitude: 0);
          }
        } else {
          print('Polyline point is not a Map: $point');
          return GeoPoint(latitude: 0, longitude: 0);
        }
      }).toList();
    } catch (e) {
      print('Error processing polyline data: $e');
      // Provide an empty list as fallback
      polylinePoints = [];
    }
  }

  return RouteSegment(
    from: json.containsKey('from') && json['from'] != null
        ? RoutePoint.fromJson(json['from'] as Map<String, dynamic>)
        : RoutePoint(
            nodeId: '',
            location: GeoPoint(latitude: 0, longitude: 0),
            address: '',
          ),
    to: json.containsKey('to') && json['to'] != null
        ? RoutePoint.fromJson(json['to'] as Map<String, dynamic>)
        : RoutePoint(
            nodeId: '',
            location: GeoPoint(latitude: 0, longitude: 0),
            address: '',
          ),
    distance: json.containsKey('distance') && json['distance'] != null
        ? (json['distance'] is double 
            ? json['distance'] as double
            : (json['distance'] as num).toDouble())
        : 0.0,
    polyline: polylinePoints,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'from': from.toJson(),
      'to': to.toJson(),
      'distance': distance,
      'polyline': polyline.map((point) => point.toJson()).toList(),
    };
  }
}
