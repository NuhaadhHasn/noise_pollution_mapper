/// Hive data model for offline noise recordings
/// Stored locally when device has no internet connection
/// Uses JSON serialization (toMap/fromMap) instead of Hive adapters
class OfflineRecording {
  final String id;
  final double decibelLevel;
  final double latitude;
  final double longitude;
  final String? locationName;
  final DateTime timestamp;
  final String? soundClass;
  final String? soundType;
  final double? confidence;
  final int syncAttempts;
  final String? syncError;
  final bool isSynced;

  OfflineRecording({
    required this.id,
    required this.decibelLevel,
    required this.latitude,
    required this.longitude,
    this.locationName,
    required this.timestamp,
    this.soundClass,
    this.soundType,
    this.confidence,
    this.syncAttempts = 0,
    this.syncError,
    this.isSynced = false,
  });

  /// Create from a map (for deserialization).
  /// Accepts `Map<dynamic, dynamic>` because Hive dynamic boxes return
  /// untyped maps for entries loaded from disk after an app restart
  /// (offline-1/flow2-1) — a `Map<String, dynamic>` parameter would throw
  /// an implicit-cast TypeError before the body even runs.
  factory OfflineRecording.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return OfflineRecording(
      id: map['id'] as String,
      decibelLevel: (map['decibelLevel'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationName: map['locationName'] as String?,
      // Hive persists DateTime natively; the String branch is defensive
      // for any entry that was serialized through JSON.
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp'] as DateTime
          : DateTime.parse(map['timestamp'] as String),
      soundClass: map['soundClass'] as String?,
      soundType: map['soundType'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      syncError: map['syncError'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }

  /// Convert to map (for serialization)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'decibelLevel': decibelLevel,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'timestamp': timestamp,
      'soundClass': soundClass,
      'soundType': soundType,
      'confidence': confidence,
      'syncAttempts': syncAttempts,
      'syncError': syncError,
      'isSynced': isSynced,
    };
  }

  /// Create a copy with updated fields
  OfflineRecording copyWith({
    String? id,
    double? decibelLevel,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? timestamp,
    String? soundClass,
    String? soundType,
    double? confidence,
    int? syncAttempts,
    String? syncError,
    bool? isSynced,
  }) {
    return OfflineRecording(
      id: id ?? this.id,
      decibelLevel: decibelLevel ?? this.decibelLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      timestamp: timestamp ?? this.timestamp,
      soundClass: soundClass ?? this.soundClass,
      soundType: soundType ?? this.soundType,
      confidence: confidence ?? this.confidence,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() {
    return 'OfflineRecording(id: $id, dB: $decibelLevel, location: $locationName, synced: $isSynced)';
  }
}
