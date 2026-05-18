import 'package:flutter/material.dart';

import '../app_navigator.dart';

/// Dialogues et snacks via le [Navigator] racine (fiable sur carte / bottom sheet Web).
class AppDialogs {
  AppDialogs._();

  static BuildContext? get rootContext => appNavigatorKey.currentContext;

  static Future<T?> show<T>({
    required Widget Function(BuildContext dialogContext) builder,
    bool barrierDismissible = true,
  }) {
    final ctx = rootContext;
    if (ctx == null) return Future<T?>.value(null);
    return showDialog<T>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  static void runNextFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  static void snack(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final ctx = rootContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : null,
        duration: duration,
      ),
    );
  }
}
