import 'package:flutter/foundation.dart';

/// Shared app state to prevent duplicate operations across screens
class SharedAppState {
  // Track if location dialog already shown APP-WIDE (prevent duplicate dialogs)
  static bool locationDialogShown = false;

  /// Currently visible tab in MainAppShell's IndexedStack
  /// (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4).
  /// Screens hosted in the IndexedStack stay mounted when hidden, so they
  /// listen to this to react to being shown/hidden (dash-6).
  static final ValueNotifier<int> currentTabIndex = ValueNotifier<int>(2);

  // Reset flag (call when app restarts)
  static void reset() {
    locationDialogShown = false;
  }
}
