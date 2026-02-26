import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save noise reading to Firestore (with optional sound classification data)
  Future<void> saveNoiseReading({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,        // e.g., "traffic", "construction", etc.
    String? soundType,         // "Pollution" or "Ambient"
    double? confidence,        // 0.0 - 1.0 (model confidence)
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final data = {
        'userId': user.uid,
        'userEmail': user.email,
        'decibelLevel': decibelLevel,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName ?? 'Unknown Location',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now(), // Client-side timestamp as fallback
        'deviceInfo': 'Mobile Device', // Generic placeholder - TODO: Implement device_info_plus for real device detection
      };

      // Add sound classification data if available
      if (soundClass != null) {
        data['soundClass'] = soundClass;
      }
      if (soundType != null) {
        data['soundType'] = soundType;
      }
      if (confidence != null) {
        data['confidence'] = confidence;
      }

      await _firestore.collection('noise_readings').add(data);

      final classInfo = soundClass != null
          ? ' [$soundClass - ${(confidence! * 100).toStringAsFixed(1)}%]'
          : '';
      AppLogger.info('Saved reading: $decibelLevel dB$classInfo at ($latitude, $longitude)');
    } catch (e) {
      AppLogger.error('Error saving reading', e);
    }
  }

  // Get all noise readings (for map view) - STREAM VERSION (continuous listening)
  Stream<QuerySnapshot> getNoiseReadings() {
    return _firestore
        .collection('noise_readings')
        .orderBy('timestamp', descending: true)
        .limit(100) // Last 100 readings
        .snapshots();
  }

  // Get all noise readings ONCE (for map view) - FIXED: No continuous listening
  Future<QuerySnapshot> getNoiseReadingsOnce() async {
    return await _firestore
        .collection('noise_readings')
        .orderBy('timestamp', descending: true)
        .limit(100) // Last 100 readings
        .get();
  }

  // Get user's readings (for analytics)
  Stream<QuerySnapshot> getUserReadings(String userId) {
    return _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get readings by location (for specific city)
  Future<List<Map<String, dynamic>>> getReadingsByLocation(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    // For now, get all readings and filter in code
    // In production, use GeoFirestore for geo queries
    final snapshot = await _firestore.collection('noise_readings').get();

    return snapshot.docs
        .map((doc) => doc.data())
        .toList();
  }

  // Get user's readings for a specific time period (for time-period analytics)
  // Uses isGreaterThan to match the existing composite index (userId ASC, timestamp DESC).
  Stream<QuerySnapshot> getUserReadingsByPeriod(String userId, DateTime since) {
    return _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // One-shot fetch for classification data — avoids the broadcast-stream race
  // condition where StreamBuilder consumes the first Firestore event before
  // newStream.first can subscribe to it.
  Future<QuerySnapshot> getUserReadingsByPeriodOnce(
      String userId, DateTime since) {
    return _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .get();
  }

  // Calculate statistics for a specific time period
  // orderBy must match the existing composite index (userId ASC, timestamp DESC).
  Future<Map<String, double>> calculateStatsByPeriod(DateTime since) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .get();

    final totalDocs = snapshot.docs.length;

    if (snapshot.docs.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0, 'count': 0};
    }

    // Null-safe: skip docs with missing/null decibelLevel instead of crashing
    final readings = snapshot.docs
        .map((doc) => (doc.data()['decibelLevel'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    if (readings.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0, 'count': totalDocs.toDouble()};
    }

    return {
      'avg': readings.reduce((a, b) => a + b) / readings.length,
      'min': readings.reduce((a, b) => a < b ? a : b),
      'max': readings.reduce((a, b) => a > b ? a : b),
      'count': readings.length.toDouble(),
      'totalDocs': totalDocs.toDouble(), // all docs in period, including unclassified
    };
  }

  // Calculate statistics
  Future<Map<String, double>> calculateStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (snapshot.docs.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0, 'count': 0};
    }

    final readings = snapshot.docs
        .map((doc) => (doc.data()['decibelLevel'] as num).toDouble())
        .toList();

    return {
      'avg': readings.reduce((a, b) => a + b) / readings.length,
      'min': readings.reduce((a, b) => a < b ? a : b),
      'max': readings.reduce((a, b) => a > b ? a : b),
      'count': readings.length.toDouble(),
    };
  }
}
