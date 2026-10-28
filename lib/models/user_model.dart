import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import 'model_utils.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone = '',
    this.organizationName = '',
    this.defaultPickupArea = '',
    this.isVerified = false,
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String organizationName;
  final String defaultPickupArea;
  final bool isVerified;
  final DateTime? createdAt;

  bool get isProvider => role == AppRoles.provider;
  bool get isReceiver => role == AppRoles.receiver;
  bool get isAdmin => role == AppRoles.admin;

  /// Name shown to other users: organization if set, else the person's name.
  String get displayOrg =>
      organizationName.isNotEmpty ? organizationName : fullName;

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return UserModel(
      uid: doc.id,
      fullName: toStr(d['fullName']),
      email: toStr(d['email']),
      phone: toStr(d['phone']),
      role: toStr(d['role'], AppRoles.receiver),
      organizationName: toStr(d['organizationName']),
      defaultPickupArea: toStr(d['defaultPickupArea']),
      isVerified: d['isVerified'] == true,
      createdAt: toDate(d['createdAt']),
    );
  }

  /// Document written at registration. `isVerified` is always false here;
  /// the security rules reject anything else.
  Map<String, dynamic> toCreateMap() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'organizationName': organizationName,
        'defaultPickupArea': defaultPickupArea,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
