import 'dart:async';

import 'package:flutter/material.dart';

import 'app_logger.dart';

/// Minimum time an action SnackBar stays up while assistive navigation is
/// reported, so a screen-reader user can still reach the action.
const Duration assistiveMinimumDuration = Duration(seconds: 8);

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
/// * always lets the SnackBar time out. When assistive navigation is reported
///   ([MediaQuery.accessibleNavigationOf]), an action SnackBar stays up for at
///   least [assistiveMinimumDuration]. Owner decision 2026-10-16: on the
///   owner's phone an always-on accessibility service (AnyDesk) makes Flutter
///   report assistive navigation, and a SnackBar that never timed out followed
///   the user to other tabs and covered the record button;
/// * backs Flutter's own timer with a fallback that hides the SnackBar if it
///   is still showing one second after its timeout. The fallback is cancelled
///   as soon as the SnackBar closes, so it can never hide a newer one.
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
  final assistive = MediaQuery.accessibleNavigationOf(context);
  final effective =
      assistive && action != null && duration < assistiveMinimumDuration
          ? assistiveMinimumDuration
          : duration;
  AppLogger.debug('[ActionSnackBar] accessibleNavigation=$assistive '
      'duration=${effective.inSeconds}s');

  target.clearSnackBars();
  final controller = target.showSnackBar(
    SnackBar(
      content: content,
      action: action,
      duration: effective,
      persist: false,
      backgroundColor: backgroundColor,
      behavior: behavior,
    ),
  );

  final fallback = Timer(effective + const Duration(seconds: 1), () {
    if (target.mounted) {
      target.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    }
  });
  controller.closed.then((_) => fallback.cancel());
  return controller;
}
