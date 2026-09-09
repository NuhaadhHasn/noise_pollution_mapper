import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/csv_builder.dart';

void main() {
  test('header has no User Email column', () {
    final csv = buildNoiseCsv([]);
    expect(
      csv.trim(),
      'Timestamp,Location,Latitude,Longitude,Decibel Level (dB),Sound Classification,Sound Type,Confidence (%),Device',
    );
    expect(csv, isNot(contains('User Email')));
  });

  test('writes one row per reading and escapes embedded quotes', () {
    final csv = buildNoiseCsv([
      {
        'timestamp': '2026-07-18 10:00:00',
        'location': 'Main "North" Gate',
        'latitude': 6.927,
        'longitude': 79.861,
        'decibelLevel': 72.4,
        'soundClass': 'Traffic',
        'soundType': 'Pollution',
        'confidence': '85.0',
        'device': 'Mobile Device',
      },
      {
        'timestamp': 'N/A',
        'location': null, // missing locationName
        'latitude': 0.0,
        'longitude': 0.0,
        'decibelLevel': 0.0,
        'soundClass': null,
        'soundType': null,
        'confidence': 'N/A',
        'device': 'Mobile Device',
      },
    ]);

    final lines = csv.trim().split('\n');
    expect(lines.length, 3); // header + 2 rows
    expect(lines[1], contains('"Main ""North"" Gate"'));
    expect(lines[1], contains('72.4'));
    expect(lines[2], contains('"Unknown"'));
    expect(lines[2], contains('"N/A"'));
  });
}
