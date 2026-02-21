import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/theme/app_theme.dart';

// Unit tests for App Theme
void main() {
  group('App Theme Tests', () {
    test('AppTheme class has required color constants', () {
      // Test that theme colors are defined
      expect(AppTheme.primaryPurple, isA<Color>());
      expect(AppTheme.darkBackground, isA<Color>());
      expect(AppTheme.cardBackground, isA<Color>());
      expect(AppTheme.textWhite, isA<Color>());
      expect(AppTheme.textGray, isA<Color>());
    });

    test('Theme has noise level colors', () {
      expect(AppTheme.lowNoise, isA<Color>());
      expect(AppTheme.moderateNoise, isA<Color>());
      expect(AppTheme.highNoise, isA<Color>());
    });

    test('Theme colors are not null', () {
      expect(AppTheme.primaryPurple, isNotNull);
      expect(AppTheme.darkBackground, isNotNull);
      expect(AppTheme.cardBackground, isNotNull);
    });

    test('Dark theme can be generated', () {
      final theme = AppTheme.generateDarkTheme(AppTheme.primaryPurple);
      expect(theme, isA<ThemeData>());
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.primaryColor, equals(AppTheme.primaryPurple));
    });

    test('Light theme can be generated', () {
      final theme = AppTheme.generateLightTheme(AppTheme.primaryPurple);
      expect(theme, isA<ThemeData>());
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.primaryColor, equals(AppTheme.primaryPurple));
    });

    test('Theme colors map is not empty', () {
      expect(AppTheme.themeColors, isNotEmpty);
      expect(AppTheme.themeColors.length, greaterThan(5));
    });

    test('Each theme color has a name and color', () {
      AppTheme.themeColors.forEach((name, color) {
        expect(name, isNotNull);
        expect(name, isA<String>());
        expect(name.length, greaterThan(0));
        expect(color, isA<Color>());
      });
    });

    test('Theme colors include standard options', () {
      expect(AppTheme.themeColors.containsKey('Purple'), isTrue);
      expect(AppTheme.themeColors.containsKey('Green'), isTrue);
      expect(AppTheme.themeColors.containsKey('Blue'), isTrue);
    });

    test('Generated themes have proper color schemes', () {
      final darkTheme = AppTheme.generateDarkTheme(Colors.purple);
      final lightTheme = AppTheme.generateLightTheme(Colors.blue);

      expect(darkTheme.colorScheme.primary, isNotNull);
      expect(lightTheme.colorScheme.primary, isNotNull);
      expect(darkTheme.scaffoldBackgroundColor, equals(AppTheme.darkBackground));
      expect(lightTheme.scaffoldBackgroundColor, equals(AppTheme.lightBackground));
    });
  });
}
