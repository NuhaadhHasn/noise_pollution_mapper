/// Builds the CSV document for the History export.
///
/// Top-level function so it can run on a background isolate via `compute()`
/// (perf-5) and be unit tested in isolation. [rows] must contain only
/// isolate-sendable primitives (String / num / null) — no Firestore types.
///
/// Privacy (fb-4 / uiux-3): there is deliberately NO email column.
String buildNoiseCsv(List<Map<String, Object?>> rows) {
  final csvData = StringBuffer();

  // CSV Header (includes sound classification fields; no user email)
  csvData.writeln(
      'Timestamp,Location,Latitude,Longitude,Decibel Level (dB),Sound Classification,Sound Type,Confidence (%),Device');

  for (final row in rows) {
    final location = _escape(row['location'] as String? ?? 'Unknown');
    final soundClass = _escape(row['soundClass'] as String? ?? 'N/A');
    final soundType = _escape(row['soundType'] as String? ?? 'N/A');
    csvData.writeln(
        '${row['timestamp']},"$location",${row['latitude']},${row['longitude']},${row['decibelLevel']},"$soundClass","$soundType",${row['confidence']},${row['device']}');
  }

  return csvData.toString();
}

/// Escape embedded double quotes for quoted CSV fields.
String _escape(String value) => value.replaceAll('"', '""');
