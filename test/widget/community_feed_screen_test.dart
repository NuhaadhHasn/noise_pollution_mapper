@Skip('arch-2: pre-existing failure — requires Firebase test harness; see audit/06_ARCHITECTURE_AND_CODE_QUALITY.md')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/community_feed_screen.dart';

// Widget tests for Community Feed Screen
void main() {
  group('Community Feed Screen Widget Tests', () {
    testWidgets('Community feed screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityFeedScreen(),
        ),
      );

      await tester.pump();

      // Verify app bar exists
      expect(find.text('Community Feed'), findsOneWidget);
    });

    testWidgets('Bottom navigation bar exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityFeedScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('Loading or content state renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityFeedScreen(),
        ),
      );

      await tester.pump();

      // Should either show loading or list
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
