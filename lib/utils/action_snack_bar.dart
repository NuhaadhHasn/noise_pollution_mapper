import 'package:flutter/material.dart';

/// Shows a SnackBar in place of any SnackBar that is already showing or
/// queued, and returns its controller.
///
/// Device QA 2026-10-16 (a1-3): since Flutter 3.35, [SnackBar.persist]
/// defaults to true whenever an action is set, so an action SnackBar never
/// times out, whatever its `duration`. Successive "Recording deleted / Undo"
/// SnackBars therefore queued up behind the first one, and the Undo on screen
/// belonged to an EARLIER deletion than the one the user had just made.
///
/// This helper:
/// * clears the current and queued SnackBars first, so the action on screen
///   always belongs to the newest event;
/// * keeps an action SnackBar up only while an assistive technology is
///   navigating the app ([MediaQuery.accessibleNavigationOf]), because a
///   screen-reader user needs time to reach the action. Otherwise it times
///   out after [duration], as the call sites intend. This is the rule
///   Flutter applied before 3.35.
///
/// [messenger] may be passed when the caller captured it before an async
/// gap; [context] is still used to read the accessibility setting.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showActionSnackBar(
  BuildContext context, {
  required Widget content,
  required SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  Color? backgroundColor,
  SnackBarBehavior? behavior,
  ScaffoldMessengerState? messenger,
}) {
  final target = messenger ?? ScaffoldMessenger.of(context);
  final persist = action != null && MediaQuery.accessibleNavigationOf(context);
  target.clearSnackBars();
  return target.showSnackBar(
    SnackBar(
      content: content,
      action: action,
      duration: duration,
      persist: persist,
      backgroundColor: backgroundColor,
      behavior: behavior,
    ),
  );
}
