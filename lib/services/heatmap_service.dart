import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/heatmap_point.dart';
import '../utils/app_logger.dart';

/// Service for generating and managing heatmap data
/// Converts Firestore noise readings into heatmap points for visualization
class HeatmapService {
  /// Convert Firestore QuerySnapshot to list of HeatmapPoints
  List<HeatmapPoint> convertToHeatmapPoints(QuerySnapshot snapshot) {
    try {
      final points = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return HeatmapPoint.fromFirestore(data);
          })
          .where((point) => 
              point.latitude != 0.0 && 
              point.longitude != 0.0) // Filter out invalid coordinates
          .toList();
      
      AppLogger.info('[HeatmapService] Converted ${points.length} readings to heatmap points');
      return points;
    } catch (e) {
      AppLogger.error('[HeatmapService] Error converting to heatmap points', e);
      return [];
    }
  }

  /// Filter heatmap points by time range
  List<HeatmapPoint> filterByTimeRange(
    List<HeatmapPoint> points, {
    DateTime? startTime,
    DateTime? endTime,
  }) {
    if (startTime == null && endTime == null) {
      return points; // No filter applied
    }

    final now = DateTime.now();
    final effectiveStart = startTime ?? DateTime(2000); // Far past
    final effectiveEnd = endTime ?? now;

    final filtered = points.where((point) {
      return point.timestamp.isAfter(effectiveStart) &&
             point.timestamp.isBefore(effectiveEnd);
    }).toList();

    AppLogger.info('[HeatmapService] Filtered to ${filtered.length} points in time range');
    return filtered;
  }

  /// Get predefined time range presets
  Map<String, Duration> getTimeRangePresets() {
    return {
      '1 Hour': const Duration(hours: 1),
      '1 Day': const Duration(days: 1),
      '1 Week': const Duration(days: 7),
      '1 Month': const Duration(days: 30),
      'All Time': const Duration(days: 36500), // ~100 years
    };
  }

  /// Calculate time boundaries for preset
  Map<String, DateTime> getTimeRangeBoundaries(String preset) {
    final now = DateTime.now();
    final duration = getTimeRangePresets()[preset] ?? const Duration(days: 30);
    
    return {
      'start': now.subtract(duration),
      'end': now,
    };
  }

  /// Filter points by decibel level range
  List<HeatmapPoint> filterByDecibelRange(
    List<HeatmapPoint> points, {
    double minDb = 0.0,
    double maxDb = 120.0,
  }) {
    return points.where((point) {
      return point.decibelLevel >= minDb && 
             point.decibelLevel <= maxDb;
    }).toList();
  }

  /// Filter points by sound category
  List<HeatmapPoint> filterBySoundCategory(
    List<HeatmapPoint> points, {
    String? category,
  }) {
    if (category == null || category == 'All') {
      return points;
    }

    return points.where((point) {
      return point.soundCategory == category;
    }).toList();
  }

  /// Calculate statistics for heatmap points
  Map<String, dynamic> calculateStatistics(List<HeatmapPoint> points) {
    if (points.isEmpty) {
      return {
        'count': 0,
        'avgDb': 0.0,
        'maxDb': 0.0,
        'minDb': 0.0,
      };
    }

    final decibels = points.map((p) => p.decibelLevel).toList();
    final sum = decibels.reduce((a, b) => a + b);

    return {
      'count': points.length,
      'avgDb': sum / points.length,
      'maxDb': decibels.reduce((a, b) => a > b ? a : b),
      'minDb': decibels.reduce((a, b) => a < b ? a : b),
      'quietPoints': points.where((p) => p.decibelLevel < 50).length,
      'moderatePoints': points.where((p) => 
          p.decibelLevel >= 50 && p.decibelLevel < 70).length,
      'loudPoints': points.where((p) => p.decibelLevel >= 70).length,
    };
  }

  /// Generate gradient colors for heatmap
  /// Returns map of intensity values to colors
  Map<double, int> getGradientColors() {
    return {
      0.0: 0xFF4CAF50,      // Green: < 50 dB (quiet)
      0.25: 0xFF8BC34A,     // Light Green
      0.4: 0xFFFFEB3B,      // Yellow: ~50 dB
      0.5: 0xFFFFC107,      // Amber
      0.6: 0xFFFF9800,      // Orange: ~70 dB
      0.75: 0xFFFF5722,     // Deep Orange
      1.0: 0xFFF44336,      // Red: > 70 dB (loud)
    };
  }
}
