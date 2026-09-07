import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/firestore_batch_utils.dart';

void main() {
  group('FirestoreBatchUtils.chunk', () {
    test('empty list yields no chunks', () {
      expect(FirestoreBatchUtils.chunk(<int>[]), isEmpty);
    });

    test('list smaller than chunk size yields one chunk', () {
      final chunks = FirestoreBatchUtils.chunk(List.generate(10, (i) => i));
      expect(chunks, hasLength(1));
      expect(chunks.single, hasLength(10));
    });

    test('exactly chunkSize items yield exactly one chunk', () {
      final chunks = FirestoreBatchUtils.chunk(
        List.generate(FirestoreBatchUtils.chunkSize, (i) => i),
      );
      expect(chunks, hasLength(1));
    });

    test('501 items split as 450 + 51 (the flow6-05 failure case)', () {
      final chunks = FirestoreBatchUtils.chunk(List.generate(501, (i) => i));
      expect(chunks, hasLength(2));
      expect(chunks[0], hasLength(450));
      expect(chunks[1], hasLength(51));
    });

    test('1200 items split as 450 + 450 + 300 preserving order', () {
      final items = List.generate(1200, (i) => i);
      final chunks = FirestoreBatchUtils.chunk(items);
      expect(chunks.map((c) => c.length).toList(), [450, 450, 300]);
      expect(chunks.expand((c) => c).toList(), items);
    });

    test('every chunk stays at or under the Firestore 500-op limit', () {
      final chunks = FirestoreBatchUtils.chunk(List.generate(9999, (i) => i));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(500));
      }
    });

    test('custom size is honored', () {
      final chunks =
          FirestoreBatchUtils.chunk(List.generate(5, (i) => i), size: 2);
      expect(chunks.map((c) => c.length).toList(), [2, 2, 1]);
    });

    test('non-positive size throws', () {
      expect(
        () => FirestoreBatchUtils.chunk([1], size: 0),
        throwsArgumentError,
      );
    });
  });
}
