import 'package:flutter/material.dart';

/// Tiny wrapper around Navigator so screens do not repeat route boilerplate.
class AppRouter {
  static Future<T?> push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

  /// Returns to the root (AuthGate), which decides what to show.
  static void popToRoot(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);
}
