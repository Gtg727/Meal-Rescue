import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(Collections.users).doc(uid);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Emits null while the profile document does not exist yet.
  Stream<UserModel?> watchProfile(String uid) => _userRef(uid)
      .snapshots()
      .map((s) => s.exists ? UserModel.fromDoc(s) : null);

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String phone = '',
    String organizationName = '',
  }) async {
    if (!AppRoles.selectable.contains(role)) {
      throw AppException('Please choose a valid account type.');
    }
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }

    final user = cred.user!;
    try {
      final profile = UserModel(
        uid: user.uid,
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        role: role,
        organizationName: organizationName.trim(),
      );
      await _userRef(user.uid)
          .set(profile.toCreateMap())
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Do not leave an auth account without a profile behind.
      try {
        await user.delete();
      } catch (_) {}
      throw AppException(
          'Could not finish creating your account. Please try again.');
    }
    try {
      await user.updateDisplayName(fullName.trim());
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException(_authMessage(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Only permitted fields can be changed (see firestore.rules). The role
  /// and verification flag are never written from the client.
  Future<void> updateProfile(
    String uid, {
    required String fullName,
    required String phone,
    required String organizationName,
    required String defaultPickupArea,
  }) async {
    try {
      await _userRef(uid).update({
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'organizationName': organizationName.trim(),
        'defaultPickupArea': defaultPickupArea.trim(),
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  Future<void> saveFcmToken(String uid, String? token) async {
    await _userRef(uid).update({'fcmToken': token ?? FieldValue.delete()});
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
