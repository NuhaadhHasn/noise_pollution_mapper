import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/app_logger.dart';
import '../models/offline_recording.dart';
import 'offline_storage_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  final OfflineStorageService _offlineStorage = OfflineStorageService();

  // Save noise reading to Firestore (with optional sound classification data)
  // Automatically handles offline mode by queuing for later sync
  Future<void> saveNoiseReading({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,
    String? soundType,
    double? confidence,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.warning('[FirebaseService] No user logged in, cannot save');
        return;
      }

      // Check connectivity with error handling
      bool isOnline = false;
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        isOnline = _isConnectedToInternet(connectivityResult);
      } catch (e) {
        // If connectivity check fails, assume offline
        AppLogger.warning('[FirebaseService] Connectivity check failed, assuming offline: $e');
        isOnline = false;
      }

      if (isOnline) {
        // ONLINE: Save directly to Firebase
        await _saveToFirebase(
          decibelLevel: decibelLevel,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          soundClass: soundClass,
          soundType: soundType,
          confidence: confidence,
          userId: user.uid,
        );
        AppLogger.info('[FirebaseService] Saved reading to Firebase: $decibelLevel dB');
      } else {
        // OFFLINE: Save to Hive queue for later sync
        await _saveOffline(
          decibelLevel: decibelLevel,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          soundClass: soundClass,
          soundType: soundType,
          confidence: confidence,
          userId: user.uid,
        );
        AppLogger.warning('[FirebaseService] Offline! Queued reading for later sync: $decibelLevel dB');
      }
    } catch (e) {
      AppLogger.error('[FirebaseService] Error saving reading', e);
      // Fallback: Save offline even if online save failed
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _saveOffline(
            decibelLevel: decibelLevel,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            soundClass: soundClass,
            soundType: soundType,
            confidence: confidence,
            userId: user.uid,
          );
          AppLogger.info('[FirebaseService] Saved to offline queue (fallback): $decibelLevel dB');
        }
      } catch (fallbackError) {
        AppLogger.error('[FirebaseService] Fallback offline save also failed', fallbackError);
      }
    }
  }

  /// Check if connectivity results indicate internet connection
  bool _isConnectedToInternet(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return true;
      }
    }
    return false;
  }

  /// Save directly to Firebase (online mode)
  Future<void> _saveToFirebase({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,
    String? soundType,
    double? confidence,
    required String userId,
  }) async {
    final data = {
      'userId': userId,
      'userEmail': _auth.currentUser?.email,
      'decibelLevel': decibelLevel,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName ?? 'Unknown Location',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': DateTime.now(),
      'deviceInfo': 'Mobile Device',
    };

    if (soundClass != null) data['soundClass'] = soundClass;
    if (soundType != null) data['soundType'] = soundType;
    if (confidence != null) data['confidence'] = confidence;

    await _firestore.collection('noise_readings').add(data);
  }

  /// Save to offline queue (offline mode)
  Future<void> _saveOffline({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,
    String? soundType,
    double? confidence,
    required String userId,
  }) async {
    final recording = OfflineRecording(
      id: '${DateTime.now().millisecondsSinceEpoch}_$userId',
      decibelLevel: decibelLevel,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      timestamp: DateTime.now(),
      soundClass: soundClass,
      soundType: soundType,
      confidence: confidence,
      syncAttempts: 0,
      isSynced: false,
    );

    await _offlineStorage.saveOfflineRecording(recording);
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
  Future<QuerySnapshot> getNoiseReadingsOnce({int limit = 100}) async {
    return await _firestore
        .collection('noise_readings')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
  }

  // Get all noise readings for heatmap (with optional date range)
  Future<QuerySnapshot> getNoiseReadingsForHeatmap({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 500, // Limit for performance
  }) async {
    Query query = _firestore
        .collection('noise_readings')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    // Add time filters if provided
    if (startTime != null) {
      query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(startTime));
    }
    if (endTime != null) {
      query = query.where('timestamp', isLessThan: Timestamp.fromDate(endTime));
    }

    return await query.get();
  }

  // Get user's readings (for analytics)
  Stream<QuerySnapshot> getUserReadings(String userId) {
    return _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get user's readings with pagination (for infinite scroll)
  Future<QuerySnapshot> getUserReadingsPaginated({
    required String userId,
    required int limit,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  // Get total count of user's readings (for "Showing X of Y" display)
  Future<int> getUserReadingsCount(String userId) async {
    final snapshot = await _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
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
