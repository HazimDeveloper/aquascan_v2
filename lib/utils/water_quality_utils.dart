
// lib/utils/water_quality_utils.dart
// Updated to use the new state classes from the backend

import '../models/report_model.dart';
import 'package:flutter/material.dart';

/// Utility class for water quality related functions
class WaterQualityUtils {
  /// Returns a user-friendly text representation of the water quality state
  static String getWaterQualityText(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'Optimum';
      case WaterQualityState.highPh:
        return 'High pH';
      case WaterQualityState.highPhTemp:
        return 'High pH & Temperature';
      case WaterQualityState.lowPh:
        return 'Low pH';
      case WaterQualityState.lowTemp:
        return 'Low Temperature';
      case WaterQualityState.lowTempHighPh:
        return 'Low Temp & High pH';
      case WaterQualityState.unknown:
      default:
        return 'Unknown';
    }
  }
  
  /// Returns a color representing the water quality state
  static Color getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.blue;
      case WaterQualityState.lowTemp:
        return Colors.green;
      case WaterQualityState.highPh:
        return Colors.orange;
      case WaterQualityState.lowPh:
        return Colors.orange.shade700;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
  
  /// Returns a detailed description of the water quality state
  static String getWaterQualityDescription(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'The water has optimal pH and temperature levels for general use.';
      case WaterQualityState.highPh:
        return 'The water has high pH levels and may be alkaline. May cause skin irritation or affect taste.';
      case WaterQualityState.highPhTemp:
        return 'The water has both high pH and temperature. Not recommended for direct use.';
      case WaterQualityState.lowPh:
        return 'The water has low pH levels and may be acidic. May cause corrosion or affect taste.';
      case WaterQualityState.lowTemp:
        return 'The water has lower than optimal temperature but otherwise may be suitable for use.';
      case WaterQualityState.lowTempHighPh:
        return 'The water has low temperature and high pH levels. Use with caution.';
      case WaterQualityState.unknown:
      default:
        return 'The water quality could not be determined from the provided image.';
    }
  }
  
  /// Maps backend API water quality classes to the app's WaterQualityState enum
  static WaterQualityState mapWaterQualityClass(String waterQualityClass) {
    // Trim and standardize the input
    final className = waterQualityClass.trim().toUpperCase();
    
    if (className.contains('OPTIMUM')) {
      return WaterQualityState.optimum;
    } else if (className.contains('HIGH_PH') && className.contains('HIGH_TEMP')) {
      return WaterQualityState.highPhTemp;
    } else if (className.contains('LOW_TEMP') && className.contains('HIGH_PH')) {
      return WaterQualityState.lowTempHighPh;
    } else if (className.contains('HIGH_PH')) {
      return WaterQualityState.highPh;
    } else if (className.contains('LOW_PH')) {
      return WaterQualityState.lowPh;
    } else if (className.contains('LOW_TEMP')) {
      return WaterQualityState.lowTemp;
    } else {
      return WaterQualityState.unknown;
    }
  }
  
  /// Returns an icon for the water quality state
  static IconData getWaterQualityIcon(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Icons.check_circle;
      case WaterQualityState.lowTemp:
        return Icons.ac_unit;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Icons.science;
      case WaterQualityState.highPhTemp:
        return Icons.whatshot;
      case WaterQualityState.lowTempHighPh:
        return Icons.warning;
      case WaterQualityState.unknown:
      default:
        return Icons.help_outline;
    }
  }
}