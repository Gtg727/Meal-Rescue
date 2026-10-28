import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../models/donation_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';

class ReportService {
  ReportService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.reports);

  Future<void> submit({
    required DonationModel donation,
    required UserModel reporter,
    required String reason,
    String details = '',
  }) async {
    try {
      await _db.runTransaction((tx) async {
        tx.set(_col.doc(), {
          'donationId': donation.id,
          'donationTitle': donation.title,
          'reporterId': reporter.uid,
          'reporterName': reporter.fullName,
          'reason': reason,
          'details': details.trim(),
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Admin only (enforced by security rules). Newest first.
  Stream<List<ReportModel>> watchAll() => _col.snapshots().map((s) {
        final list = s.docs.map(ReportModel.fromDoc).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });

  Future<void> resolve(
    String reportId, {
    required String newStatus,
    required String adminId,
  }) async {
    try {
      await _col.doc(reportId).update({
        'status': newStatus,
        'resolvedBy': adminId,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }
}
