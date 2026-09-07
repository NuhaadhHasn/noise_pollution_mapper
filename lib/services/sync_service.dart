import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offline_recording.dart';
import 'offline_storage_service.dart';
import '../utils/app_logger.dart';

/// Service for monitoring connectivity and syncing offline data
/// Automatically uploads queued recordings when device comes online
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineStorageService _storage = OfflineStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;
  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Sync configuration
  static const int maxSyncAttempts = 3;
  static const Duration syncRetryDelay = Duration(seconds: 5);

  /// Initialize sync service and start monitoring connectivity
  Future<bool> initialize() async {
    if (_isInitialized) {
      AppLogger.debug('[SyncService] Already initialized');
      return true;
    }

    try {
      AppLogger.info('[SyncService] Initializing...');

      // Initialize storage
      final storageInitialized = await _storage.initialize();
      if (!storageInitialized) {
        AppLogger.error('[SyncService] Storage initialization failed');
        return false;
      }

      // Check initial connectivity with error handling
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        _isOnline = _isConnectedToInternet(connectivityResult);
      } catch (e) {
        AppLogger.warning('[SyncService] Connectivity check failed, assuming offline: $e');
        _isOnline = false;
      }
      
      AppLogger.info('[SyncService] Initial connectivity: ${_isOnline ? "Online" : "Offline"}');

      // Start listening to connectivity changes (stream emits List<ConnectivityResult>)
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
      );

      _isInitialized = true;
      AppLogger.info('[SyncService] Initialized successfully');
      return true;
    } catch (e) {
      AppLogger.error('[SyncService] Initialization failed', e);
      return false;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    try {
      final wasOnline = _isOnline;
      _isOnline = _isConnectedToInternet(results);

      AppLogger.info(
        '[SyncService] Connectivity changed: ${wasOnline ? "Online" : "Offline"} → ${_isOnline ? "Online" : "Offline"}',
      );

      // If we just came online and have pending recordings, trigger sync
      if (!wasOnline && _isOnline) {
        AppLogger.info('[SyncService] Back online! Checking for pending syncs...');
        final pendingCount = _storage.getPendingCount();
        if (pendingCount > 0) {
          AppLogger.info('[SyncService] Found $pendingCount pending recordings. Starting sync...');
          syncOfflineRecordings();
        }
      }
    } catch (e) {
      AppLogger.error('[SyncService] Error handling connectivity change', e);
      // Assume offline on error
      _isOnline = false;
    }
  }

  /// Check if connectivity results indicate internet connection
  bool _isConnectedToInternet(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    
    // Check if any connection type is available (excluding "none")
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return true;
      }
    }
    return false;
  }

  /// Sync all offline recordings to Firebase
  /// Returns number of successfully synced recordings
  Future<int> syncOfflineRecordings() async {
    if (!_isInitialized) {
      AppLogger.warning('[SyncService] Not initialized, cannot sync');
      return 0;
    }

    if (_isSyncing) {
      AppLogger.warning('[SyncService] Sync already in progress');
      return 0;
    }

    if (!_isOnline) {
      AppLogger.warning('[SyncService] Cannot sync while offline');
      return 0;
    }

    _isSyncing = true;
    int syncedCount = 0;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.warning('[SyncService] No user logged in, cannot sync');
        _isSyncing = false;
        return 0;
      }

      final queuedRecordings = _storage.getQueuedRecordings();
      AppLogger.info('[SyncService] Starting sync of ${queuedRecordings.length} recordings');

      if (queuedRecordings.isEmpty) {
        AppLogger.debug('[SyncService] No pending recordings to sync');
        _isSyncing = false;
        return 0;
      }

      for (final recording in queuedRecordings) {
        // Check if max attempts exceeded
        if (recording.syncAttempts >= maxSyncAttempts) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: Max sync attempts ($maxSyncAttempts) exceeded',
          );
          continue;
        }

        // Never upload another user's queued recording
        // (offline-6/flow2-2/flow5-2). Foreign entries stay queued until
        // their owner signs in; entries with no resolvable owner are
        // skipped so they are never mis-attributed.
        final ownerId = recording.userId;
        if (ownerId == null || ownerId != user.uid) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: queued by '
            '${ownerId ?? "unknown user"}, current user is ${user.uid}. '
            'Leaving in queue for its owner.',
          );
          continue;
        }

        try {
          AppLogger.debug('[SyncService] Syncing recording: ${recording.id}');

          // Save to Firebase under the recording owner's uid
          await _saveToFirebase(recording, ownerId);

          // Mark as synced in local storage
          await _storage.markAsSynced(recording.id);
          syncedCount++;

          AppLogger.info('[SyncService] Successfully synced: ${recording.id}');
        } catch (e) {
          // Update sync attempts
          final newAttempts = recording.syncAttempts + 1;
          await _storage.updateSyncStatus(
            recording.id,
            attempts: newAttempts,
            error: e.toString(),
          );

          AppLogger.error(
            '[SyncService] Failed to sync ${recording.id} (attempt $newAttempts/$maxSyncAttempts)',
            e,
          );

          // Wait before retry
          if (newAttempts < maxSyncAttempts) {
            await Future.delayed(syncRetryDelay);
          }
        }
      }

      // Save last sync time
      await _storage.saveLastSyncTime(DateTime.now());

      AppLogger.info('[SyncService] Sync complete: $syncedCount/${queuedRecordings.length} synced');

      // Clear old synced recordings (optional cleanup)
      if (syncedCount > 0) {
        final clearedCount = await _storage.clearSyncedRecordings();
        AppLogger.debug('[SyncService] Cleared $clearedCount old synced recordings');
      }
    } catch (e) {
      AppLogger.error('[SyncService] Sync failed with error', e);
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Save a single recording to Firebase
  Future<void> _saveToFirebase(OfflineRecording recording, String userId) async {
    final data = <String, dynamic>{
      'userId': userId,
      'decibelLevel': recording.decibelLevel,
      'latitude': recording.latitude,
      'longitude': recording.longitude,
      'locationName': recording.locationName ?? 'Unknown Location',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': recording.timestamp,
      'deviceInfo': 'Mobile Device',
    };

    // Add sound classification data if available
    if (recording.soundClass != null) {
      data['soundClass'] = recording.soundClass;
    }
    if (recording.soundType != null) {
      data['soundType'] = recording.soundType;
    }
    if (recording.confidence != null) {
      data['confidence'] = recording.confidence;
    }

    await _firestore.collection('noise_readings').add(data);
  }

  /// Manually trigger sync (user-initiated)
  Future<int> triggerManualSync() async {
    if (!_isOnline) {
      AppLogger.warning('[SyncService] Cannot manually sync while offline');
      return 0;
    }
    return await syncOfflineRecordings();
  }

  /// Get current sync status
  Map<String, dynamic> getSyncStatus() {
    try {
      return {
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
        'pendingCount': getPendingCount(),
        'lastSyncTime': _storage.getLastSyncTimeSync(), // Use sync version
      };
    } catch (e) {
      AppLogger.error('[SyncService] Error getting sync status', e);
      return {
        'isOnline': false,
        'isSyncing': false,
        'pendingCount': 0,
        'lastSyncTime': null,
      };
    }
  }

  /// Get pending recordings count
  int getPendingCount() {
    try {
      return _storage.getPendingCount();
    } catch (e) {
      AppLogger.error('[SyncService] Error getting pending count', e);
      return 0;
    }
  }

  /// Check if service is online
  bool isOnline() => _isOnline;

  /// Check if sync is in progress
  bool isSyncing() => _isSyncing;

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async => await _storage.getLastSyncTime();

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _storage.close();
    _isInitialized = false;
    AppLogger.info('[SyncService] Disposed');
  }
}
