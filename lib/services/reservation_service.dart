import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/inventory.dart';
import '../models/donation_model.dart';
import '../models/reservation_model.dart';
import '../models/user_model.dart';

/// All reservation state changes run inside Firestore transactions so the
/// reservation document and the donation counters change together, and two
/// users can never claim the same portions (FR-12).
///
/// Production hardening: move these transactions into Cloud Functions so the
/// client cannot bypass them (see README, "Security notes").
class ReservationService {
  ReservationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _res =>
      _db.collection(Collections.reservations);
  DocumentReference<Map<String, dynamic>> _don(String id) =>
      _db.collection(Collections.donations).doc(id);

  /// Pre-generates an id so a retried request is idempotent.
  String newId() => _res.doc().id;

  // ---------------------------------------------------------------- streams

  Stream<List<ReservationModel>> watchForReceiver(String uid) => _res
      .where('receiverId', isEqualTo: uid)
      .snapshots()
      .map(_mapList);

  Stream<List<ReservationModel>> watchForProvider(String uid) => _res
      .where('providerId', isEqualTo: uid)
      .snapshots()
      .map(_mapList);

  /// Admin only (enforced by security rules).
  Stream<List<ReservationModel>> watchAll() => _res.snapshots().map(_mapList);

  Stream<ReservationModel?> watchOne(String id) => _res
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? ReservationModel.fromDoc(s) : null);

  List<ReservationModel> _mapList(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(ReservationModel.fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? b.lastActivity)
          .compareTo(a.createdAt ?? a.lastActivity));
    return list;
  }

  // ----------------------------------------------------------------- create

  /// Receiver requests [portions]. Creates a PENDING reservation and
  /// reserves the portions against the listing so concurrent requests cannot
  /// over-allocate it. Calling again with the same [reservationId] returns
  /// without creating a duplicate.
  Future<String> createReservation({
    required String reservationId,
    required String donationId,
    required int portions,
    required UserModel receiver,
  }) async {
    if (!receiver.isReceiver) {
      throw AppException('Only receiver accounts can reserve food.');
    }
    final dRef = _don(donationId);
    final rRef = _res.doc(reservationId);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(rRef);
        if (existing.exists) return; // idempotent retry
        final dSnap = await tx.get(dRef);
        if (!dSnap.exists) throw AppException('This listing no longer exists.');
        final d = DonationModel.fromDoc(dSnap);

        final error = validateReservationRequest(
          requested: portions,
          reservable: d.reservablePortions,
          isExpired: d.isExpired,
          status: d.status,
        );
        if (error != null) throw AppException(error);

        tx.update(dRef, {
          'pendingPortions': d.pendingPortions + portions,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(rRef, {
          'donationId': d.id,
          'donationTitle': d.title,
          'pickupAddress': d.pickupAddress,
          'pickupDeadline': Timestamp.fromDate(d.pickupDeadline),
          'providerId': d.providerId,
          'providerName': d.providerLabel,
          'receiverId': receiver.uid,
          'receiverName': receiver.fullName,
          'receiverOrganization': receiver.organizationName,
          'receiverPhone': receiver.phone,
          'requestedPortions': portions,
          'status': ReservationStatus.pending,
          'receiverConfirmed': false,
          'providerConfirmed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedAt': null,
          'completedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return reservationId;
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  // ----------------------------------------------------- provider decisions

  /// Pending -> accepted. Moves the portions from "pending" to "reserved".
  Future<void> accept(String reservationId, String providerId) async {
    await _run(() async {
      final rRef = _res.doc(reservationId);
      await _db.runTransaction((tx) async {
        final rSnap = await tx.get(rRef);
        final r = _requireReservation(rSnap);
        if (r.providerId != providerId) {
          throw AppException('You can only manage your own reservations.');
        }
        if (r.status != ReservationStatus.pending) {
          throw AppException('This request is no longer pending.');
        }
        final dRef = _don(r.donationId);
        final d = _requireDonation(await tx.get(dRef));
        if (d.status != DonationStatus.available || d.isExpired) {
          throw AppException(
              'This listing has expired or is closed, so the request cannot be accepted.');
        }
        if (!canAcceptRequest(
          requested: r.requestedPortions,
          total: d.totalPortions,
          reserved: d.reservedPortions,
          completed: d.completedPortions,
        )) {
          throw AppException('Not enough portions left to accept this request.');
        }
        tx.update(dRef, {
          'pendingPortions': max(0, d.pendingPortions - r.requestedPortions),
          'reservedPortions': d.reservedPortions + r.requestedPortions,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(rRef, {
          'status': ReservationStatus.accepted,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  /// Pending -> rejected. Releases the pending portions.
  Future<void> reject(String reservationId, String providerId) async {
    await _run(() async {
      final rRef = _res.doc(reservationId);
      await _db.runTransaction((tx) async {
        final r = _requireReservation(await tx.get(rRef));
        if (r.providerId != providerId) {
          throw AppException('You can only manage your own reservations.');
        }
        if (r.status != ReservationStatus.pending) {
          throw AppException('This request is no longer pending.');
        }
        final dRef = _don(r.donationId);
        final d = _requireDonation(await tx.get(dRef));
        tx.update(dRef, {
          'pendingPortions': max(0, d.pendingPortions - r.requestedPortions),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(rRef, {
          'status': ReservationStatus.rejected,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  // ----------------------------------------------------------------- cancel

  /// Receiver may cancel pending/accepted reservations; the provider may
  /// cancel accepted ones. Collection that is already confirmed by the
  /// receiver cannot be cancelled.
  Future<void> cancel(String reservationId, String actorId) async {
    await _run(() async {
      final rRef = _res.doc(reservationId);
      await _db.runTransaction((tx) async {
        final r = _requireReservation(await tx.get(rRef));
        final isReceiver = r.receiverId == actorId;
        final isProvider = r.providerId == actorId;
        if (!isReceiver && !isProvider) {
          throw AppException('You cannot change this reservation.');
        }
        if (!r.isActive) {
          throw AppException('This reservation can no longer be cancelled.');
        }
        if (r.receiverConfirmed) {
          throw AppException(
              'Collection was already confirmed, so it cannot be cancelled.');
        }
        if (isProvider && r.status == ReservationStatus.pending) {
          throw AppException('Reject pending requests instead of cancelling.');
        }
        final dRef = _don(r.donationId);
        final d = _requireDonation(await tx.get(dRef));
        tx.update(dRef, {
          if (r.status == ReservationStatus.pending)
            'pendingPortions': max(0, d.pendingPortions - r.requestedPortions),
          if (r.status == ReservationStatus.accepted)
            'reservedPortions': max(0, d.reservedPortions - r.requestedPortions),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(rRef, {
          'status': ReservationStatus.cancelled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  // ----------------------------------------------------------- pickup steps

  /// Step 1 of completion: the receiver confirms they collected the food.
  Future<void> confirmCollection(String reservationId, String receiverId) async {
    await _run(() async {
      final rRef = _res.doc(reservationId);
      await _db.runTransaction((tx) async {
        final r = _requireReservation(await tx.get(rRef));
        if (r.receiverId != receiverId) {
          throw AppException('Only the receiver can confirm collection.');
        }
        if (r.status != ReservationStatus.accepted) {
          throw AppException('Only accepted reservations can be collected.');
        }
        if (r.receiverConfirmed) {
          throw AppException('You already confirmed this collection.');
        }
        if (r.pickupDeadline.isBefore(DateTime.now())) {
          throw AppException('The pickup deadline has passed.');
        }
        tx.update(rRef, {
          'receiverConfirmed': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  /// Step 2: the provider confirms the handover. This completes the
  /// reservation exactly once and moves portions from "reserved" to
  /// "completed". [collectedPortions] allows partial pickups.
  Future<void> confirmHandover(
    String reservationId,
    String providerId, {
    required int collectedPortions,
  }) async {
    await _run(() async {
      final rRef = _res.doc(reservationId);
      await _db.runTransaction((tx) async {
        final r = _requireReservation(await tx.get(rRef));
        if (r.providerId != providerId) {
          throw AppException('Only the provider can confirm the handover.');
        }
        if (r.status == ReservationStatus.completed) {
          throw AppException('This pickup was already completed.');
        }
        if (r.status != ReservationStatus.accepted) {
          throw AppException('Only accepted reservations can be completed.');
        }
        if (!r.receiverConfirmed) {
          throw AppException('Wait for the receiver to confirm collection first.');
        }
        if (collectedPortions < 1 || collectedPortions > r.requestedPortions) {
          throw AppException(
              'Collected portions must be between 1 and ${r.requestedPortions}.');
        }
        final dRef = _don(r.donationId);
        final d = _requireDonation(await tx.get(dRef));
        final newCompleted = d.completedPortions + collectedPortions;
        final newReserved = max(0, d.reservedPortions - r.requestedPortions);
        final fullyDone = newCompleted >= d.totalPortions &&
            newReserved == 0 &&
            d.pendingPortions == 0;
        tx.update(dRef, {
          'reservedPortions': newReserved,
          'completedPortions': newCompleted,
          if (fullyDone) 'status': DonationStatus.completed,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(rRef, {
          'status': ReservationStatus.completed,
          'providerConfirmed': true,
          'collectedPortions': collectedPortions,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  // ------------------------------------------------------------ housekeeping

  /// Expires the provider's pending/accepted reservations whose pickup
  /// deadline passed without the receiver confirming collection.
  Future<void> expireOverdue(String providerId) async {
    final snap = await _res.where('providerId', isEqualTo: providerId).get();
    final now = DateTime.now();
    for (final doc in snap.docs) {
      final r = ReservationModel.fromDoc(doc);
      if (!r.isActive || r.receiverConfirmed || !r.pickupDeadline.isBefore(now)) {
        continue;
      }
      try {
        await _db.runTransaction((tx) async {
          final fresh = ReservationModel.fromDoc(await tx.get(doc.reference));
          if (!fresh.isActive ||
              fresh.receiverConfirmed ||
              !fresh.pickupDeadline.isBefore(DateTime.now())) {
            return;
          }
          final dRef = _don(fresh.donationId);
          final dSnap = await tx.get(dRef);
          if (dSnap.exists) {
            final d = DonationModel.fromDoc(dSnap);
            tx.update(dRef, {
              if (fresh.status == ReservationStatus.pending)
                'pendingPortions':
                    max(0, d.pendingPortions - fresh.requestedPortions),
              if (fresh.status == ReservationStatus.accepted)
                'reservedPortions':
                    max(0, d.reservedPortions - fresh.requestedPortions),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          tx.update(doc.reference, {
            'status': ReservationStatus.expired,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (_) {
        // Best effort; expired reservations are already shown as expired.
      }
    }
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  ReservationModel _requireReservation(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) throw AppException('This reservation no longer exists.');
    return ReservationModel.fromDoc(snap);
  }

  DonationModel _requireDonation(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) throw AppException('The listing no longer exists.');
    return DonationModel.fromDoc(snap);
  }
}
