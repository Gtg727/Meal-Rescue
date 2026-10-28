import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/constants/app_constants.dart';

/// Stores this device's FCM token on the user's profile so Cloud Functions
/// (see /functions) can send informational push notifications.
///
/// Notifications are only hints: the database status stays authoritative.
class NotificationService {
  String? _uid;
  StreamSubscription<String>? _refreshSub;

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _save(uid, token);
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen((t) => _save(uid, t));
    } catch (_) {
      // Push is optional (P1). Ignore failures such as missing permission.
    }
  }

  /// Removes the token on sign out so a shared device stops receiving alerts.
  Future<void> clear() async {
    final uid = _uid;
    _uid = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(Collections.users)
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
    } catch (_) {}
  }

  Future<void> _save(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection(Collections.users)
          .doc(uid)
          .update({'fcmToken': token});
    } catch (_) {}
  }
}
