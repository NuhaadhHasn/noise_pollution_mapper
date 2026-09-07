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
  StreamSubscription<User?>? _authSubscription;

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

      // offline-3: a fresh launch that is already online never fires an
      // offline→online transition, and neither does signing in. Listen to
      // auth state (fires immediately with the current user, including the
      // restored session at startup) and sync when a user is present.
      _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);

      // Belt-and-braces startup check for the case where auth restore has
      // already completed before this listener attaches.
      if (_isOnline && _storage.getPendingCount() > 0) {
        AppLogger.info(
          '[SyncService] Startup: pending recordings found while online. Starting sync...',
        );
        unawaited(syncOfflineRecordings());
      }
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
        _handleBackOnline();
      }
    } catch (e) {
      AppLogger.error('[SyncService] Error handling connectivity change', e);
      // Assume offline on error
      _isOnline = false;
    }
  }

  /// On connectivity restoration, give previously max-attempts-failed
  /// recordings another chance (offline-2/flow2-7), then sync anything
  /// pending. New connection == new circumstances, so the old failures
  /// are no longer meaningful.
  Future<void> _handleBackOnline() async {
    await _storage.resetFailedSyncAttempts(maxSyncAttempts);
    final pendingCount = _storage.getPendingCount();
    if (pendingCount > 0) {
      AppLogger.info(
        '[SyncService] Found $pendingCount pending recordings. Starting sync...',
      );
      await syncOfflineRecordings();
    }
  }

  /// Sync pending recordings when a user signs in (offline-3). The stream
  /// also fires once on listen with the restored session, covering startup.
  void _onAuthStateChanged(User? user) {
    if (user == null) return;
    if (_isOnline && _storage.getPendingCount() > 0) {
      AppLogger.info(
        '[SyncService] User ${user.uid} signed in with pending recordings. Starting sync...',
      );
      unawaited(syncOfflineRecordings());
    }
  }

  /// Called by FirebaseService after a recording was queued although the
  /// device believes it is online (fallback save after a failed direct
  /// write, offline-3). Kicks a sync instead of waiting for the next
  /// offline→online transition.
  void notifyQueued() {
    if (_isInitialized && _isOnline && !_isSyncing) {
      unawaited(syncOfflineRecordings());
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

          // Mark as synced in local storage. Only count it if the local
          // mark succeeded; otherwise it stays queued and the retry is
          // harmless because the upload is idempotent (same doc ID).
          final marked = await _storage.markAsSynced(recording.id);
          if (marked) {
            syncedCount++;
            AppLogger.info('[SyncService] Successfully synced: ${recording.id}');
          } else {
            AppLogger.warning(
              '[SyncService] Uploaded ${recording.id} but failed to mark it '
              'synced locally; it will be retried idempotently',
            );
          }
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
      'userEmail': recording.userEmail ?? _auth.currentUser?.email,
      'decibelLevel': recording.decibelLevel,
      'latitude': recording.latitude,
      'longitude': recording.longitude,
      'locationName': recording.locationName ?? 'Unknown Location',
      // fb-2/flow2-3: the true capture time, NOT the sync time. This is a
      // deliberate, documented deviation from the serverTimestamp
      // convention: serverTimestamp() here would stamp the moment of sync,
      // putting offline readings on the wrong day in analytics/history/
      // heatmap. createdAt keeps the client DateTime per the dual-write
      // convention, so readers that handle both fields stay correct.
      'timestamp': Timestamp.fromDate(recording.timestamp),
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

    // Deterministic document ID (offline-4/flow5-3): recording.id is unique
    // per reading, so a retry after a lost ack overwrites the same document
    // instead of creating a duplicate.
    await _firestore.collection('noise_readings').doc(recording.id).set(data);
  }

  /// Manually trigger sync (user-initiated). Explicit user intent resets
  /// the attempt counter on dead-lettered recordings so "Sync Now" always
  /// retries everything (offline-2/flow2-7).
  Future<int> triggerManualSync() async {
    if (!_isOnline) {
      AppLogger.warning('[SyncService] Cannot manually sync while offline');
      return 0;
    }
    await _storage.resetFailedSyncAttempts(maxSyncAttempts);
    return await syncOfflineRecordings();
  }

  /// Get current sync status
  Map<String, dynamic> getSyncStatus() {
    try {
      return {
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
        'pendingCount': getPendingCount(),
        'failedCount': _storage.getFailedCount(maxSyncAttempts),
        'lastSyncTime': _storage.getLastSyncTimeSync(), // Use sync version
      };
    } catch (e) {
      AppLogger.error('[SyncService] Error getting sync status', e);
      return {
        'isOnline': false,
        'isSyncing': false,
        'pendingCount': 0,
        'failedCount': 0,
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
    _authSubscription?.cancel();
    _storage.close();
    _isInitialized = false;
    AppLogger.info('[SyncService] Disposed');
  }
}
