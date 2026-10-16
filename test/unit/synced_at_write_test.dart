import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/models/offline_recording.dart';
import 'package:noise_pollution_mapper/services/firebase_service.dart';
import 'package:noise_pollution_mapper/services/sync_service.dart';

// data-1: every noise_readings writer that firestore.rules validates with
// validReading() stamps `syncedAt` with FieldValue.serverTimestamp(), the
// SERVER upload time the web dashboard's delta sync keys on. The rules accept
// no other value (syncedAt == request.time). The email-propagation and
// delete-account anonymization updates deliberately do NOT carry it: the
// rules restrict them to exactly `userEmail`, and `userId` + `userEmail`.

/// The key whitelist of validReading(d) in firestore.rules, read from the
/// file itself, so a payload key the rules would reject fails here first.
Set<String> rulesReadingKeys() {
  final rules = File('firestore.rules').readAsStringSync();
  final list = RegExp(r'd\.keys\(\)\.hasOnly\(\[([^\]]*)\]\)').firstMatch(rules);
  expect(list, isNotNull, reason: 'validReading() key whitelist not found');
  return RegExp(r"'([^']+)'")
      .allMatches(list!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

Map<String, dynamic> classifiedOnline() => FirebaseService.onlineReadingData(
      userId: 'uid-a',
      userEmail: 'Alice',
      decibelLevel: 67.4,
      latitude: 6.9271,
      longitude: 79.8612,
      locationName: 'Colombo Fort',
      soundClass: 'Traffic',
      soundType: 'Pollution',
      confidence: 0.82,
      createdAt: DateTime(2026, 10, 16, 9, 30),
    );

OfflineRecording offlineRecording(DateTime capturedAt, {bool classified = true}) =>
    OfflineRecording(
      id: '${capturedAt.millisecondsSinceEpoch}_uid-a',
      decibelLevel: 72.9,
      latitude: 6.9271,
      longitude: 79.8612,
      locationName: 'Colombo Fort',
      timestamp: capturedAt,
      soundClass: classified ? 'Construction' : null,
      soundType: classified ? 'Pollution' : null,
      confidence: classified ? 0.64 : null,
      userId: 'uid-a',
      userEmail: 'ali***@example.com',
    );

void main() {
  final serverTimestamp = FieldValue.serverTimestamp();

  test('the rules whitelist syncedAt among the 13 reading keys', () {
    final keys = rulesReadingKeys();
    expect(keys, contains('syncedAt'));
    expect(keys, hasLength(13));
  });

  group('online save: FirebaseService.onlineReadingData (data-1)', () {
    test('stamps timestamp and syncedAt with serverTimestamp()', () {
      final data = classifiedOnline();
      expect(data['timestamp'], serverTimestamp);
      expect(data['syncedAt'], serverTimestamp);
    });

    test('a classified reading writes exactly the 13 keys the rules allow', () {
      expect(classifiedOnline().keys.toSet(), rulesReadingKeys());
    });

    test('an unclassified reading omits the classification keys but keeps syncedAt', () {
      final data = FirebaseService.onlineReadingData(
        userId: 'uid-a',
        userEmail: 'Alice',
        decibelLevel: 55,
        latitude: 6.9271,
        longitude: 79.8612,
        createdAt: DateTime(2026, 10, 16),
      );
      expect(data.keys, isNot(contains('soundClass')));
      expect(data.keys, isNot(contains('soundType')));
      expect(data.keys, isNot(contains('confidence')));
      expect(data['locationName'], 'Unknown Location');
      expect(data['syncedAt'], serverTimestamp);
      expect(rulesReadingKeys().containsAll(data.keys), isTrue);
    });
  });

  group('offline upload: SyncService.offlineReadingData (data-1)', () {
    final capturedAt = DateTime(2026, 10, 13, 8, 15);

    test('keeps the capture time in timestamp and stamps syncedAt with serverTimestamp()', () {
      final data = SyncService.offlineReadingData(
        offlineRecording(capturedAt),
        userId: 'uid-a',
        userEmail: 'ali***@example.com',
      );
      expect(data['timestamp'], Timestamp.fromDate(capturedAt));
      expect(data['createdAt'], capturedAt);
      expect(data['syncedAt'], serverTimestamp);
    });

    test('a classified upload writes exactly the 13 keys the rules allow', () {
      final data = SyncService.offlineReadingData(
        offlineRecording(capturedAt),
        userId: 'uid-a',
        userEmail: 'ali***@example.com',
      );
      expect(data.keys.toSet(), rulesReadingKeys());
    });

    test('a retry builds the same payload, re-stamping syncedAt', () {
      final recording = offlineRecording(capturedAt, classified: false);
      final first = SyncService.offlineReadingData(recording,
          userId: 'uid-a', userEmail: 'ali***@example.com');
      final retry = SyncService.offlineReadingData(recording,
          userId: 'uid-a', userEmail: 'ali***@example.com');
      expect(retry, equals(first));
      expect(retry['syncedAt'], serverTimestamp);
      expect(retry.keys, isNot(contains('soundClass')));
    });
  });

  group('history restore: FirebaseService.withSyncedAt (data-1)', () {
    final capturedAt = DateTime(2026, 10, 10, 18, 5);
    final uploadedAt = DateTime(2026, 10, 11, 7, 40);

    Map<String, dynamic> snapshotData({bool stamped = true}) => <String, dynamic>{
          'userId': 'uid-a',
          'userEmail': 'Alice',
          'decibelLevel': 64.2,
          'latitude': 6.9271,
          'longitude': 79.8612,
          'locationName': 'Colombo Fort',
          'timestamp': Timestamp.fromDate(capturedAt),
          'createdAt': Timestamp.fromDate(capturedAt),
          'deviceInfo': 'Mobile Device',
          if (stamped) 'syncedAt': Timestamp.fromDate(uploadedAt),
        };

    test('replaces the original syncedAt, which the rules would reject, with serverTimestamp()', () {
      final restored = FirebaseService.withSyncedAt(snapshotData());
      expect(restored['syncedAt'], serverTimestamp);
    });

    test('adds syncedAt to a reading written before data-1', () {
      final restored = FirebaseService.withSyncedAt(snapshotData(stamped: false));
      expect(restored['syncedAt'], serverTimestamp);
    });

    test('keeps every other field, including the original timestamp and createdAt', () {
      final original = snapshotData();
      final restored = FirebaseService.withSyncedAt(original);
      expect(restored.keys.toSet(), original.keys.toSet());
      for (final key in original.keys.where((k) => k != 'syncedAt')) {
        expect(restored[key], original[key], reason: key);
      }
    });

    test('leaves the snapshot data it was given unchanged', () {
      final original = snapshotData();
      FirebaseService.withSyncedAt(original);
      expect(original['syncedAt'], Timestamp.fromDate(uploadedAt));
    });
  });
}
