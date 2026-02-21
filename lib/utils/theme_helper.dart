import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeHelper {
  // Check if current theme is dark
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Get scaffold background color
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  // Get card background color
  static Color getCardColor(BuildContext context) {
    return isDark(context) ? AppTheme.cardBackground : AppTheme.lightCardBackground;
  }

  // Get primary text color
  static Color getTextColor(BuildContext context) {
    return isDark(context) ? AppTheme.textWhite : AppTheme.textDark;
  }

  // Get secondary text color
  static Color getSecondaryTextColor(BuildContext context) {
    return isDark(context) ? AppTheme.textGray : AppTheme.textLightGray;
  }

  // Get primary color from theme
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  // Get icon color
  static Color getIconColor(BuildContext context) {
    return isDark(context) ? AppTheme.textGray : AppTheme.textDark;
  }

  // Get divider color
  static Color getDividerColor(BuildContext context) {
    return isDark(context)
        ? AppTheme.textGray.withValues(alpha: 0.2)
        : AppTheme.textLightGray.withValues(alpha: 0.3);
  }

  // Get button background color
  static Color getButtonColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  // Get button text color
  static Color getButtonTextColor(BuildContext context) {
    return Colors.white; // Always white on colored buttons for contrast
  }
}
