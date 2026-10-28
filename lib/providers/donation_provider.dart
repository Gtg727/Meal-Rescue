import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../models/donation_model.dart';
import '../models/user_model.dart';
import '../services/donation_service.dart';

enum ExploreSort { earliestDeadline, newest }

enum DeadlineFilter { any, twoHours, today }

class DonationProvider extends ChangeNotifier {
  DonationProvider(this._service);

  final DonationService _service;

  UserModel? _user;
  StreamSubscription<List<DonationModel>>? _exploreSub;
  StreamSubscription<List<DonationModel>>? _mineSub;

  /// Published listings visible to everyone.
  List<DonationModel> explore = [];
  bool exploreLoading = true;
  String? exploreError;

  /// Provider: own listings (all statuses). Admin: every listing.
  List<DonationModel> mine = [];
  bool mineLoading = true;
  String? mineError;

  /// Called by the ProxyProvider whenever the profile changes. Only
  /// re-subscribes when the user or role actually changes.
  void attach(UserModel? user) {
    final same = user?.uid == _user?.uid && user?.role == _user?.role;
    _user = user;
    if (same) return;
    _cancel();
    explore = [];
    mine = [];
    exploreError = null;
    mineError = null;
    exploreLoading = user != null;
    mineLoading = user != null && (user.isProvider || user.isAdmin);
    if (user == null) return;
    _subscribeExplore();
    if (user.isProvider) {
      _subscribeMine(_service.watchByProvider(user.uid));
    } else if (user.isAdmin) {
      _subscribeMine(_service.watchAll());
    }
  }

  void _subscribeExplore() {
    _exploreSub = _service.watchAvailable().listen(
      (list) {
        explore = list;
        exploreLoading = false;
        exploreError = null;
        notifyListeners();
      },
      onError: (Object e) {
        exploreError = friendlyError(e);
        exploreLoading = false;
        notifyListeners();
      },
    );
  }

  void _subscribeMine(Stream<List<DonationModel>> stream) {
    _mineSub = stream.listen(
      (list) {
        mine = list;
        mineLoading = false;
        mineError = null;
        notifyListeners();
      },
      onError: (Object e) {
        mineError = friendlyError(e);
        mineLoading = false;
        notifyListeners();
      },
    );
  }

  void _cancel() {
    _exploreSub?.cancel();
    _mineSub?.cancel();
    _exploreSub = null;
    _mineSub = null;
  }

  /// Re-opens the listeners (pull to refresh / retry button).
  Future<void> refresh() async {
    final u = _user;
    _user = null;
    attach(u);
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  // ---------------------------------------------------------------- queries

  /// Unexpired listings (including fully booked ones) for the Explore tab.
  List<DonationModel> get activeExplore => explore
      .where((d) =>
          d.effectiveStatus == DonationStatus.available ||
          d.effectiveStatus == DonationStatus.reserved)
      .toList();

  List<DonationModel> exploreFiltered({
    String query = '',
    String? category,
    ExploreSort sort = ExploreSort.earliestDeadline,
    DeadlineFilter within = DeadlineFilter.any,
  }) {
    final q = query.trim().toLowerCase();
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final list = activeExplore.where((d) {
      if (category != null && d.category != category) return false;
      if (q.isNotEmpty) {
        final haystack =
            '${d.title} ${d.description} ${d.providerLabel} ${d.pickupAddress} ${d.category}'
                .toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      switch (within) {
        case DeadlineFilter.any:
          break;
        case DeadlineFilter.twoHours:
          if (d.pickupDeadline.isAfter(now.add(const Duration(hours: 2)))) {
            return false;
          }
        case DeadlineFilter.today:
          if (d.pickupDeadline.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (sort == ExploreSort.newest) {
        return (b.createdAt ?? b.preparedAt).compareTo(a.createdAt ?? a.preparedAt);
      }
      return a.pickupDeadline.compareTo(b.pickupDeadline);
    });
    return list;
  }

  /// Latest published listings, newest first.
  List<DonationModel> latest({int limit = 5}) {
    final list = [...activeExplore]..sort((a, b) =>
        (b.createdAt ?? b.preparedAt).compareTo(a.createdAt ?? a.preparedAt));
    return list.take(limit).toList();
  }

  // Provider/admin dashboard numbers (all derived from listing records).
  int get activeListingCount => mine.where((d) => d.isActive).length;

  int get availablePortionsTotal => mine
      .where((d) => d.effectiveStatus == DonationStatus.available)
      .fold(0, (sum, d) => sum + d.reservablePortions);

  int get completedDonationCount =>
      mine.where((d) => d.status == DonationStatus.completed).length;

  List<DonationModel> get drafts =>
      mine.where((d) => d.status == DonationStatus.draft).toList();

  List<DonationModel> get activeMine =>
      mine.where((d) => d.isActive).toList()
        ..sort((a, b) => a.pickupDeadline.compareTo(b.pickupDeadline));

  /// Completed, expired and cancelled listings (donation history).
  List<DonationModel> get history => mine
      .where((d) =>
          d.status != DonationStatus.draft && !d.isActive)
      .toList()
    ..sort((a, b) => b.pickupDeadline.compareTo(a.pickupDeadline));

  Stream<DonationModel?> watchOne(String id) => _service.watchOne(id);

  // ---------------------------------------------------------------- actions

  Future<void> create(DonationModel donation) => _service.create(donation);

  Future<void> update(DonationModel donation, {String? newStatus}) =>
      _service.update(donation, newStatus: newStatus);

  Future<void> withdraw(String donationId) {
    final uid = _user?.uid;
    if (uid == null) throw AppException('You are not signed in.');
    return _service.cancel(donationId, uid);
  }

  Future<void> closeAfterPickups(String donationId) {
    final uid = _user?.uid;
    if (uid == null) throw AppException('You are not signed in.');
    return _service.closeAfterPickups(donationId, uid);
  }

  Future<void> expireOverdue(String providerId) =>
      _service.expireOverdue(providerId);

  Future<void> createSampleListings() {
    final u = _user;
    if (u == null || !u.isProvider) {
      throw AppException('Only providers can add sample listings.');
    }
    return _service.createSampleListings(u);
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}
