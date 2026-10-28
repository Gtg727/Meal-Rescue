import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../models/donation_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/report_service.dart';

/// Reports (anyone can file one) and admin tools (users, report review).
class ModerationProvider extends ChangeNotifier {
  ModerationProvider(this._reports, this._admin);

  final ReportService _reports;
  final AdminService _admin;

  UserModel? _user;
  StreamSubscription<List<ReportModel>>? _reportSub;
  StreamSubscription<List<UserModel>>? _userSub;

  /// Admin only.
  List<ReportModel> reports = [];
  List<UserModel> users = [];
  bool loading = true;
  String? error;

  void attach(UserModel? user) {
    final same = user?.uid == _user?.uid && user?.role == _user?.role;
    _user = user;
    if (same) return;
    _reportSub?.cancel();
    _userSub?.cancel();
    reports = [];
    users = [];
    error = null;
    loading = user != null && user.isAdmin;
    if (user == null || !user.isAdmin) return;

    _reportSub = _reports.watchAll().listen(
      (list) {
        reports = list;
        loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        error = friendlyError(e);
        loading = false;
        notifyListeners();
      },
    );
    _userSub = _admin.watchUsers().listen(
      (list) {
        users = list;
        notifyListeners();
      },
      onError: (Object e) {
        error = friendlyError(e);
        notifyListeners();
      },
    );
  }

  List<ReportModel> get openReports => reports.where((r) => r.isOpen).toList();

  Future<void> submitReport({
    required DonationModel donation,
    required String reason,
    String details = '',
  }) {
    final u = _user;
    if (u == null) throw AppException('You are not signed in.');
    return _reports.submit(
      donation: donation,
      reporter: u,
      reason: reason,
      details: details,
    );
  }

  Future<void> resolveReport(String reportId, {required bool dismiss}) {
    final u = _user;
    if (u == null || !u.isAdmin) {
      throw AppException('Only admins can review reports.');
    }
    return _reports.resolve(
      reportId,
      newStatus: dismiss ? 'dismissed' : 'resolved',
      adminId: u.uid,
    );
  }

  Future<void> takedownListing(String donationId) {
    final u = _user;
    if (u == null || !u.isAdmin) {
      throw AppException('Only admins can remove listings.');
    }
    return _admin.takedownListing(donationId);
  }

  Future<void> setVerified(String uid, bool verified) {
    final u = _user;
    if (u == null || !u.isAdmin) {
      throw AppException('Only admins can verify users.');
    }
    return _admin.setVerified(uid, verified);
  }

  @override
  void dispose() {
    _reportSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
