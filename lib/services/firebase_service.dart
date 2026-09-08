import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import '../models/offline_recording.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';

/// Outcome of a noise-reading save attempt (fb-1).
/// - [savedOnline]: written to Firestore.
/// - [queuedOffline]: stored in the local Hive queue for later sync.
/// - [failed]: nothing was persisted — callers MUST surface this to the user.
enum SaveOutcome { savedOnline, queuedOffline, failed }

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  final OfflineStorageService _offlineStorage = OfflineStorageService();

  /// Round a coordinate to 3 decimal places (~110 m grid).
  /// Applied when the 'anonymize_location' preference is enabled (flow6-03).
  static double roundCoordinate(double value) =>
      (value * 1000).roundToDouble() / 1000;

  /// Privacy-safe author label written to shared noise_readings docs (sec-2).
  /// Prefers the Auth displayName; falls back to a masked email
  /// (abc***@domain.com). Never returns a full raw email address.
  static String authorLabel({String? displayName, String? email}) {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (email == null || !email.contains('@')) return 'Anonymous';
    final parts = email.split('@');
    final local = parts[0];
    final prefix = local.length > 3 ? local.substring(0, 3) : local;
    return '$prefix***@${parts.sublist(1).join('@')}';
  }

  // Save noise reading to Firestore (with optional sound classification data).
  // Automatically handles offline mode by queuing for later sync.
  // Never throws — returns a SaveOutcome the caller must check (fb-1).
  Future<SaveOutcome> saveNoiseReading({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,
    String? soundType,
    double? confidence,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('[FirebaseService] No user logged in, cannot save');
      return SaveOutcome.failed;
    }

    // Honor the 'Anonymize Location' privacy setting at WRITE time (flow6-03).
    // Rounding happens here — before BOTH the online write and the offline
    // queue entry — so raw coordinates never leave the device when enabled.
    double lat = latitude;
    double lng = longitude;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('anonymize_location') ?? false) {
        lat = roundCoordinate(latitude);
        lng = roundCoordinate(longitude);
      }
    } catch (e) {
      AppLogger.warning(
          '[FirebaseService] Could not read privacy prefs, using raw coordinates: $e');
    }

    // Check connectivity with error handling
    bool isOnline = false;
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      isOnline = _isConnectedToInternet(connectivityResult);
    } catch (e) {
      // If connectivity check fails, assume offline
      AppLogger.warning(
          '[FirebaseService] Connectivity check failed, assuming offline: $e');
      isOnline = false;
    }

    if (isOnline) {
      try {
        // ONLINE: Save directly to Firebase
        await _saveToFirebase(
          decibelLevel: decibelLevel,
          latitude: lat,
          longitude: lng,
          locationName: locationName,
          soundClass: soundClass,
          soundType: soundType,
          confidence: confidence,
          userId: user.uid,
        );
        AppLogger.info(
            '[FirebaseService] Saved reading to Firebase: $decibelLevel dB');
        return SaveOutcome.savedOnline;
      } catch (e) {
        AppLogger.error(
            '[FirebaseService] Online save failed, falling back to offline queue',
            e);
        // Fall through to the offline queue below.
      }
    }

    // OFFLINE (or online save failed): queue in Hive for later sync
    try {
      await _saveOffline(
        decibelLevel: decibelLevel,
        latitude: lat,
        longitude: lng,
        locationName: locationName,
        soundClass: soundClass,
        soundType: soundType,
        confidence: confidence,
        userId: user.uid,
      );
      AppLogger.warning(
          '[FirebaseService] Queued reading for later sync: $decibelLevel dB');
      // offline-3: if the device believes it is online (a direct write just
      // failed transiently) kick a sync now rather than waiting for the next
      // offline→online transition. notifyQueued() self-guards on
      // _isInitialized && _isOnline && !_isSyncing, so this is a no-op on the
      // genuinely-offline path. Bounded by maxSyncAttempts.
      SyncService().notifyQueued();
      return SaveOutcome.queuedOffline;
    } catch (e) {
      AppLogger.error('[FirebaseService] Offline save also failed', e);
      return SaveOutcome.failed;
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
      // Privacy (sec-2): never store the raw email in the shared collection.
      // Field name kept as 'userEmail' for reader compatibility
      // (community_feed_screen.dart displays and re-masks it harmlessly).
      'userEmail': authorLabel(
        displayName: _auth.currentUser?.displayName,
        email: _auth.currentUser?.email,
      ),
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
      userId: userId,
      // Privacy (sec-2, playbook §4.2): queue the masked label so the
      // SyncService upload writes the same privacy-safe value as the
      // online path.
      userEmail: authorLabel(
        displayName: _auth.currentUser?.displayName,
        email: _auth.currentUser?.email,
      ),
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

  // Delete a single noise reading by document id.
  Future<void> deleteNoiseReading(String docId) {
    return _firestore.collection('noise_readings').doc(docId).delete();
  }

  // Restore a previously deleted reading (undo support). Re-writes the
  // original document data verbatim under the same id, preserving the
  // original timestamp/createdAt pair (project convention: dual timestamps).
  Future<void> restoreNoiseReading(String docId, Map<String, dynamic> data) {
    return _firestore.collection('noise_readings').doc(docId).set(data);
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
