import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../models/user_model.dart';

/// Admin-only operations. The security rules only allow these for users whose
/// profile role is "admin" (assign that role manually in the Firebase console).
class AdminService {
  AdminService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<UserModel>> watchUsers() =>
      _db.collection(Collections.users).snapshots().map((s) {
        final list = s.docs.map(UserModel.fromDoc).toList()
          ..sort((a, b) => a.fullName.toLowerCase()
              .compareTo(b.fullName.toLowerCase()));
        return list;
      });

  Future<void> setVerified(String uid, bool verified) async {
    try {
      await _db
          .collection(Collections.users)
          .doc(uid)
          .update({'isVerified': verified});
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Removes a reported listing: cancels the listing and every active
  /// reservation on it, and releases all held portions.
  Future<void> takedownListing(String donationId) async {
    try {
      final reservations = await _db
          .collection(Collections.reservations)
          .where('donationId', isEqualTo: donationId)
          .get();
      final batch = _db.batch();
      for (final doc in reservations.docs) {
        final status = doc.data()['status'];
        if (ReservationStatus.active.contains(status)) {
          batch.update(doc.reference, {
            'status': ReservationStatus.cancelled,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      batch.update(_db.collection(Collections.donations).doc(donationId), {
        'status': DonationStatus.cancelled,
        'pendingPortions': 0,
        'reservedPortions': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }
}
