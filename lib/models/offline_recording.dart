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

  /// Create from a map (for deserialization)
  factory OfflineRecording.fromMap(Map<String, dynamic> map) {
    return OfflineRecording(
      id: map['id'] as String,
      decibelLevel: (map['decibelLevel'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationName: map['locationName'] as String?,
      timestamp: map['timestamp'] as DateTime,
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
