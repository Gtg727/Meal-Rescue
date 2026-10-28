import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// An error whose [message] is safe and useful to show to the user.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Converts any thrown object into a short, understandable message.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  if (error is TimeoutException) {
    return 'The request timed out. Check your connection and try again.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
      case 'network-request-failed':
        return 'You appear to be offline. Check your connection and try again.';
      case 'not-found':
        return 'That item no longer exists.';
      case 'aborted':
        return 'Someone else updated this at the same time. Please try again.';
      case 'unauthenticated':
        return 'Please sign in again.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
