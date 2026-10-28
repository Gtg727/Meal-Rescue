import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../models/reservation_model.dart';
import '../models/user_model.dart';
import '../services/reservation_service.dart';

class ReservationProvider extends ChangeNotifier {
  ReservationProvider(this._service);

  final ReservationService _service;

  UserModel? _user;
  StreamSubscription<List<ReservationModel>>? _sub;

  /// Receiver: own reservations. Provider: reservations on own listings.
  /// Admin: all reservations.
  List<ReservationModel> reservations = [];
  bool loading = true;
  String? error;

  void attach(UserModel? user) {
    final same = user?.uid == _user?.uid && user?.role == _user?.role;
    _user = user;
    if (same) return;
    _sub?.cancel();
    _sub = null;
    reservations = [];
    error = null;
    loading = user != null;
    if (user == null) return;

    final Stream<List<ReservationModel>> stream;
    if (user.isProvider) {
      stream = _service.watchForProvider(user.uid);
    } else if (user.isAdmin) {
      stream = _service.watchAll();
    } else {
      stream = _service.watchForReceiver(user.uid);
    }
    _sub = stream.listen(
      (list) {
        reservations = list;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        error = friendlyError(e);
        loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    final u = _user;
    _user = null;
    attach(u);
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  // ---------------------------------------------------------------- queries

  List<ReservationModel> withStatus(String status) =>
      reservations.where((r) => r.effectiveStatus == status).toList();

  List<ReservationModel> get pending => withStatus(ReservationStatus.pending);
  List<ReservationModel> get accepted => withStatus(ReservationStatus.accepted);
  List<ReservationModel> get completed =>
      withStatus(ReservationStatus.completed);

  /// Rejected, cancelled and expired.
  List<ReservationModel> get closed => reservations
      .where((r) => const [
            ReservationStatus.rejected,
            ReservationStatus.cancelled,
            ReservationStatus.expired,
          ].contains(r.effectiveStatus))
      .toList();

  List<ReservationModel> get active =>
      reservations.where((r) => r.isActiveEffective).toList();

  int get completedPortionsTotal =>
      completed.fold(0, (sum, r) => sum + r.portionsCollected);

  ReservationModel? findById(String id) {
    for (final r in reservations) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<ReservationModel> forDonation(String donationId) =>
      reservations.where((r) => r.donationId == donationId).toList();

  List<ReservationModel> activeForDonation(String donationId) => reservations
      .where((r) => r.donationId == donationId && r.isActiveEffective)
      .toList();

  Stream<ReservationModel?> watchOne(String id) => _service.watchOne(id);

  // ---------------------------------------------------------------- actions

  String newReservationId() => _service.newId();

  Future<void> reserve({
    required String reservationId,
    required String donationId,
    required int portions,
  }) {
    final u = _user;
    if (u == null) throw AppException('You are not signed in.');
    return _service.createReservation(
      reservationId: reservationId,
      donationId: donationId,
      portions: portions,
      receiver: u,
    );
  }

  String get _uid {
    final u = _user;
    if (u == null) throw AppException('You are not signed in.');
    return u.uid;
  }

  Future<void> accept(String id) => _service.accept(id, _uid);
  Future<void> reject(String id) => _service.reject(id, _uid);
  Future<void> cancel(String id) => _service.cancel(id, _uid);
  Future<void> confirmCollection(String id) =>
      _service.confirmCollection(id, _uid);
  Future<void> confirmHandover(String id, {required int collectedPortions}) =>
      _service.confirmHandover(id, _uid, collectedPortions: collectedPortions);

  Future<void> expireOverdue(String providerId) =>
      _service.expireOverdue(providerId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
