import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_logger.dart';

/// Utilities for committing Firestore writes over arbitrarily many
/// documents without hitting the 500-operation WriteBatch limit
/// (arch-4 / flow6-05). Firestore rejects a batch.commit() whose batch
/// holds more than 500 operations, and the dashboard writes a reading
/// every 5 seconds while recording — so >500 docs is the NORMAL case,
/// not the edge case.
class FirestoreBatchUtils {
  FirestoreBatchUtils._();

  /// Max operations per committed batch. Kept at 450 (not 500) as a
  /// safety margin per the project playbook.
  static const int chunkSize = 450;

  /// Pure helper: split [items] into consecutive sublists of at most
  /// [size] elements, preserving order. Exposed for unit testing.
  static List<List<T>> chunk<T>(List<T> items, {int size = chunkSize}) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }
    final chunks = <List<T>>[];
    for (var start = 0; start < items.length; start += size) {
      final end =
          (start + size < items.length) ? start + size : items.length;
      chunks.add(items.sublist(start, end));
    }
    return chunks;
  }

  /// Apply [applyOp] to every reference in [refs], committing one
  /// WriteBatch per chunk of at most [chunkSize] operations.
  ///
  /// Returns the number of operations committed. Throws on the first
  /// failed commit; chunks committed before the failure STAY committed,
  /// so callers must be idempotent / safe to re-run (deletes and
  /// same-value updates are).
  static Future<int> applyInChunks(
    FirebaseFirestore firestore,
    List<DocumentReference<Map<String, dynamic>>> refs,
    void Function(
      WriteBatch batch,
      DocumentReference<Map<String, dynamic>> ref,
    ) applyOp,
  ) async {
    var committed = 0;
    for (final part in chunk(refs)) {
      final batch = firestore.batch();
      for (final ref in part) {
        applyOp(batch, ref);
      }
      await batch.commit();
      committed += part.length;
      AppLogger.debug(
        '[FirestoreBatchUtils] Committed $committed/${refs.length} batched ops',
      );
    }
    return committed;
  }
}
