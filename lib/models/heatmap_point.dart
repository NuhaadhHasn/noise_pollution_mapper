import 'package:cloud_firestore/cloud_firestore.dart';

/// Heatmap point model for noise visualization
/// Represents a single point on the heatmap with intensity based on decibel level
class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double intensity; // 0.0 to 1.0 (based on dB level)
  final double weight; // For clustering/importance
  final double decibelLevel;
  final DateTime timestamp;
  final String? soundCategory;

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    this.weight = 1.0,
    required this.decibelLevel,
    required this.timestamp,
    this.soundCategory,
  });

  /// Create HeatmapPoint from Firestore document
  factory HeatmapPoint.fromFirestore(Map<String, dynamic> data) {
    final decibelLevel = (data['decibelLevel'] as num).toDouble();
    final latitude = (data['latitude'] as num).toDouble();
    final longitude = (data['longitude'] as num).toDouble();
    
    // Calculate intensity based on dB level (normalize to 0.0-1.0)
    // Range: 0-120 dB (typical urban noise: 30-100 dB)
    final intensity = _calculateIntensity(decibelLevel);
    
    // Weight based on recency (newer readings have higher weight)
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final weight = _calculateWeight(timestamp);

    return HeatmapPoint(
      latitude: latitude,
      longitude: longitude,
      intensity: intensity,
      weight: weight,
      decibelLevel: decibelLevel,
      timestamp: timestamp,
      soundCategory: data['soundCategory'] as String?,
    );
  }

  /// Calculate intensity from dB level
  /// Maps dB range (0-120) to intensity (0.0-1.0)
  /// Green (<50dB) = 0.0-0.4, Yellow (50-70dB) = 0.4-0.6, Red (>70dB) = 0.6-1.0
  static double _calculateIntensity(double decibelLevel) {
    // Clamp dB level to reasonable range (0-120)
    final clampedDb = decibelLevel.clamp(0, 120);
    
    // Normalize to 0.0-1.0
    return clampedDb / 120.0;
  }

  /// Calculate weight based on recency
  /// Newer readings have higher weight (more relevant)
  static double _calculateWeight(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    // Weight decreases over time
    // Last hour: 1.0, Last day: 0.5, Last week: 0.25, Older: 0.1
    if (difference.inHours < 1) {
      return 1.0;
    } else if (difference.inDays < 1) {
      return 0.7;
    } else if (difference.inDays < 7) {
      return 0.5;
    } else if (difference.inDays < 30) {
      return 0.3;
    } else {
      return 0.1;
    }
  }

  /// Get color based on decibel level
  /// Returns color value as integer (for Flutter)
  int getColorValue() {
    if (decibelLevel < 50) {
      // Green: Quiet areas
      return 0xFF4CAF50;
    } else if (decibelLevel < 70) {
      // Yellow/Orange: Moderate noise
      return 0xFFFF9800;
    } else {
      // Red: High noise
      return 0xFFF44336;
    }
  }

  @override
  String toString() {
    return 'HeatmapPoint(lat: $latitude, lon: $longitude, intensity: $intensity, dB: $decibelLevel)';
  }
}
