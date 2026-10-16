// The Firestore snapshot types are annotated @sealed. Test doubles are the
// one place implementing them is fine (mockito-generated mocks do the same).
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/history_screen.dart';

/// Regression tests for History Undo (device QA 2026-10-16).
///
/// The history list was assigned straight from `QuerySnapshot.docs`, so its
/// runtime type was `List<QueryDocumentSnapshot>`. Undo re-fetches the
/// restored reading with `DocumentReference.get()`, which returns a plain
/// `DocumentSnapshot`, and inserting that threw
/// "type '_JsonDocumentSnapshot' is not a subtype of type
/// '_JsonQueryDocumentSnapshot' of 'element'". The user saw "Could not
/// restore recording." although the server-side restore had succeeded.
/// The HistoryScreen widget test is quarantined (arch-2), so these tests
/// pin the list handling directly.
class _QueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDoc(this.id);

  @override
  final String id;
}

class _Doc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id);

  @override
  final String id;
}

List<QueryDocumentSnapshot> _queryPage(List<String> ids) =>
    <QueryDocumentSnapshot>[for (final id in ids) _QueryDoc(id)];

void main() {
  group('recordingListFrom', () {
    test('the raw docs list rejects a plain DocumentSnapshot (root cause)',
        () {
      // Compiles, because Dart lists are covariant - but fails at runtime.
      final List<DocumentSnapshot> raw = _queryPage(['a', 'b']);
      expect(() => raw.insert(0, _Doc('x')), throwsA(isA<TypeError>()));
    });

    test('returns a list that accepts a plain DocumentSnapshot', () {
      final list = recordingListFrom(_queryPage(['a', 'b']));
      expect(() => list.insert(1, _Doc('x')), returnsNormally);
      expect(list.map((d) => d.id), ['a', 'x', 'b']);
    });

    test('keeps the query order and is a copy', () {
      final page = _queryPage(['a', 'b', 'c']);
      final list = recordingListFrom(page);
      expect(list.map((d) => d.id), ['a', 'b', 'c']);
      list.removeAt(0);
      expect(page, hasLength(3));
    });
  });

  group('insertRestoredRecording', () {
    test('re-inserts the restored doc at its original index', () {
      final list = recordingListFrom(_queryPage(['a', 'c']));
      final inserted = insertRestoredRecording(list, _Doc('b'), 1);
      expect(inserted, isTrue);
      expect(list.map((d) => d.id), ['a', 'b', 'c']);
    });

    test('clamps an index past the end to an append', () {
      final list = recordingListFrom(_queryPage(['a']));
      expect(insertRestoredRecording(list, _Doc('z'), 5), isTrue);
      expect(list.map((d) => d.id), ['a', 'z']);
    });

    test('works on an empty list', () {
      final list = recordingListFrom(const <DocumentSnapshot>[]);
      expect(insertRestoredRecording(list, _Doc('only'), 3), isTrue);
      expect(list.map((d) => d.id), ['only']);
    });

    test('does not duplicate a doc that is already listed', () {
      final list = recordingListFrom(_queryPage(['a', 'b']));
      expect(insertRestoredRecording(list, _Doc('b'), 0), isFalse);
      expect(list.map((d) => d.id), ['a', 'b']);
    });
  });
}
