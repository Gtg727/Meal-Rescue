import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Holds the signed-in Firebase user and their Firestore profile.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service, this._notifications) {
    _authSub = _service.authStateChanges().listen(_onAuthChanged);
  }

  final AuthService _service;
  final NotificationService _notifications;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserModel?>? _profileSub;

  User? user;
  UserModel? profile;

  /// False until the first auth/profile result is known (shows a splash).
  bool initialized = false;
  String? profileError;

  bool get isSignedIn => user != null;

  void _onAuthChanged(User? u) {
    _profileSub?.cancel();
    user = u;
    profile = null;
    profileError = null;
    if (u == null) {
      initialized = true;
      notifyListeners();
      return;
    }
    _profileSub = _service.watchProfile(u.uid).listen(
      (p) {
        profile = p;
        profileError = null;
        initialized = true;
        if (p != null) _notifications.init(p.uid);
        notifyListeners();
      },
      onError: (Object e) {
        profileError = friendlyError(e);
        initialized = true;
        notifyListeners();
      },
    );
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String phone = '',
    String organizationName = '',
  }) =>
      _service.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        phone: phone,
        organizationName: organizationName,
      );

  Future<void> login(String email, String password) =>
      _service.login(email, password);

  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String organizationName,
    required String defaultPickupArea,
  }) async {
    final uid = profile?.uid;
    if (uid == null) throw AppException('You are not signed in.');
    await _service.updateProfile(
      uid,
      fullName: fullName,
      phone: phone,
      organizationName: organizationName,
      defaultPickupArea: defaultPickupArea,
    );
  }

  Future<void> signOut() async {
    await _notifications.clear();
    await _service.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
