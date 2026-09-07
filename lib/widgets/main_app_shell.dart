import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen_enhanced.dart';
import '../services/profile_sync_service.dart';
import '../utils/shared_app_state.dart';
import 'shared_bottom_navbar.dart';

class MainAppShell extends StatefulWidget {
  final int initialIndex;

  const MainAppShell({super.key, this.initialIndex = 2});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // dash-6 (cluster 05): publish the initial tab so IndexedStack children
    // (which stay mounted when hidden) can react to being shown/hidden.
    SharedAppState.currentTabIndex.value = widget.initialIndex;
    // settings-9/flow6-06: if the user completed an email-change
    // verification since last launch, copy the now-verified Auth email
    // onto their Firestore documents. Fire-and-forget; never blocks UI.
    unawaited(ProfileSyncService().reconcileUserEmail());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            MapViewScreen(isInAppShell: true),           // Index 0
            AnalyticsScreen(isInAppShell: true),         // Index 1
            DashboardScreen(isInAppShell: true),         // Index 2 (home)
            HistoryScreen(isInAppShell: true),           // Index 3
            SettingsScreenEnhanced(isInAppShell: true),  // Index 4
          ],
        ),
        bottomNavigationBar: SharedBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // dash-6 (cluster 05): MUST stay here — the Dashboard listens to
            // this notifier to stop recording when it is hidden by a tab
            // switch. Removing it is an invisible regression (no analyzer
            // error, no test failure).
            SharedAppState.currentTabIndex.value = index;
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
