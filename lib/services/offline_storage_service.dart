import 'package:hive_flutter/hive_flutter.dart';
import '../models/offline_recording.dart';
import '../utils/app_logger.dart';

/// Service for managing offline storage using Hive
/// Handles local storage of noise recordings when device is offline
class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  static const String _recordingsBoxName = 'recordings_queue';
  static const String _syncStatusBoxName = 'sync_status';

  Box<dynamic>? _recordingsBox;
  Box<dynamic>? _syncStatusBox;

  bool _isInitialized = false;

  /// Initialize Hive and open boxes
  Future<bool> initialize() async {
    if (_isInitialized) {
      AppLogger.debug('[OfflineStorage] Already initialized');
      return true;
    }

    try {
      AppLogger.info('[OfflineStorage] Initializing Hive...');

      // Initialize Hive Flutter
      await Hive.initFlutter();

      // Open boxes (using dynamic boxes, no adapters needed)
      _recordingsBox = await Hive.openBox(_recordingsBoxName);
      _syncStatusBox = await Hive.openBox(_syncStatusBoxName);

      _isInitialized = true;

      AppLogger.info(
        '[OfflineStorage] Initialized successfully. Queue: ${_recordingsBox!.length} recordings',
      );
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Initialization failed', e);
      return false;
    }
  }

  /// Save a recording to offline queue
  Future<bool> saveOfflineRecording(OfflineRecording recording) async {
    if (!_isInitialized) {
      AppLogger.warning('[OfflineStorage] Not initialized, cannot save');
      return false;
    }

    try {
      await _recordingsBox!.put(recording.id, recording.toMap());
      AppLogger.info('[OfflineStorage] Saved offline recording: ${recording.id}');
      
      // Log all recordings in queue for debugging
      final allKeys = _recordingsBox!.keys.toList();
      int pendingCount = 0;
      for (final key in allKeys) {
        final value = _recordingsBox!.get(key);
        if (value is Map && !(value['isSynced'] as bool? ?? false)) {
          pendingCount++;
        }
      }
      AppLogger.info('[OfflineStorage] Queue status: $pendingCount pending / ${allKeys.length} total');
      
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to save recording', e);
      return false;
    }
  }

  /// Get all queued recordings (not yet synced)
  List<OfflineRecording> getQueuedRecordings() {
    if (!_isInitialized) {
      AppLogger.warning('[OfflineStorage] Not initialized, cannot get queue');
      return [];
    }

    final recordings = _recordingsBox!.values
        .where((v) {
          if (v is Map) {
            return !(v['isSynced'] as bool? ?? false);
          }
          return false;
        })
        .map((v) => OfflineRecording.fromMap(v))
        .toList();

    AppLogger.debug(
      '[OfflineStorage] Getting queued recordings: ${recordings.length} pending',
    );
    return recordings;
  }

  /// Get all offline recordings (including synced)
  List<OfflineRecording> getAllOfflineRecordings() {
    if (!_isInitialized) {
      return [];
    }
    return _recordingsBox!.values
        .whereType<Map>()
        .map((v) => OfflineRecording.fromMap(v as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific recording by ID
  OfflineRecording? getRecording(String id) {
    if (!_isInitialized) return null;
    final data = _recordingsBox!.get(id);
    if (data is Map) {
      return OfflineRecording.fromMap(data as Map<String, dynamic>);
    }
    return null;
  }

  /// Mark a recording as synced
  Future<bool> markAsSynced(String id) async {
    if (!_isInitialized) return false;

    try {
      final data = _recordingsBox!.get(id);
      if (data == null || data is! Map) {
        AppLogger.warning('[OfflineStorage] Recording not found: $id');
        return false;
      }

      final map = Map<String, dynamic>.from(data);
      map['isSynced'] = true;
      await _recordingsBox!.put(id, map);

      AppLogger.info('[OfflineStorage] Marked as synced: $id');
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to mark as synced', e);
      return false;
    }
  }

  /// Update sync attempts and error for a recording
  Future<bool> updateSyncStatus(
    String id, {
    required int attempts,
    String? error,
  }) async {
    if (!_isInitialized) return false;

    try {
      final data = _recordingsBox!.get(id);
      if (data == null || data is! Map) return false;

      final map = Map<String, dynamic>.from(data);
      map['syncAttempts'] = attempts;
      if (error != null) map['syncError'] = error;
      await _recordingsBox!.put(id, map);

      AppLogger.debug(
        '[OfflineStorage] Updated sync status for $id: attempts=$attempts, error=$error',
      );
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to update sync status', e);
      return false;
    }
  }

  /// Delete a recording from the queue
  Future<bool> deleteRecording(String id) async {
    if (!_isInitialized) return false;

    try {
      await _recordingsBox!.delete(id);
      AppLogger.info('[OfflineStorage] Deleted recording: $id');
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to delete recording', e);
      return false;
    }
  }

  /// Clear all synced recordings from the queue
  Future<int> clearSyncedRecordings() async {
    if (!_isInitialized) return 0;

    try {
      final syncedIds = <String>[];
      for (final key in _recordingsBox!.keys.toList()) {
        final value = _recordingsBox!.get(key);
        if (value is Map && (value['isSynced'] as bool? ?? false)) {
          syncedIds.add(key.toString());
        }
      }

      for (final id in syncedIds) {
        await _recordingsBox!.delete(id);
      }

      AppLogger.info(
        '[OfflineStorage] Cleared ${syncedIds.length} synced recordings',
      );
      return syncedIds.length;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to clear synced recordings', e);
      return 0;
    }
  }

  /// Clear all recordings (for testing or reset)
  Future<bool> clearAllRecordings() async {
    if (!_isInitialized) return false;

    try {
      await _recordingsBox!.clear();
      AppLogger.warning('[OfflineStorage] Cleared ALL recordings');
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to clear all recordings', e);
      return false;
    }
  }

  /// Get count of pending recordings
  int getPendingCount() {
    if (!_isInitialized) return 0;
    
    int count = 0;
    try {
      for (final key in _recordingsBox!.keys.toList()) {
        final value = _recordingsBox!.get(key);
        if (value is Map && !(value['isSynced'] as bool? ?? false)) {
          count++;
        }
      }
    } catch (e) {
      AppLogger.error('[OfflineStorage] Error getting pending count', e);
      return 0;
    }
    
    AppLogger.debug('[OfflineStorage] Pending count: $count');
    return count;
  }

  /// Save sync status metadata
  Future<bool> saveSyncStatus(String key, dynamic value) async {
    if (!_isInitialized) return false;

    try {
      await _syncStatusBox!.put(key, value);
      return true;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to save sync status', e);
      return false;
    }
  }

  /// Get sync status metadata
  dynamic getSyncStatus(String key) {
    if (!_isInitialized) return null;
    return _syncStatusBox!.get(key);
  }

  /// Get last sync timestamp
  DateTime? getLastSyncTime() {
    final timestamp = getSyncStatus('last_sync_time');
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  /// Save last sync timestamp
  Future<bool> saveLastSyncTime(DateTime timestamp) async {
    return saveSyncStatus('last_sync_time', timestamp);
  }

  /// Close all boxes (cleanup)
  Future<void> close() async {
    if (!_isInitialized) return;

    try {
      await _recordingsBox?.close();
      await _syncStatusBox?.close();
      _isInitialized = false;
      AppLogger.info('[OfflineStorage] Closed all boxes');
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to close boxes', e);
    }
  }
}
