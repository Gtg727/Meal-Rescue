import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/app_exception.dart';
import '../models/donation_model.dart';
import '../models/reservation_model.dart';
import '../models/user_model.dart';

class DonationService {
  DonationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.donations);

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _db.collection(Collections.reservations);

  // ---------------------------------------------------------------- streams

  /// Published listings. Expiry and sorting are applied on the device so no
  /// composite Firestore index is required.
  Stream<List<DonationModel>> watchAvailable() => _col
      .where('status', isEqualTo: DonationStatus.available)
      .snapshots()
      .map(_mapList);

  Stream<List<DonationModel>> watchByProvider(String providerId) => _col
      .where('providerId', isEqualTo: providerId)
      .snapshots()
      .map(_mapList);

  /// Admin only (enforced by security rules).
  Stream<List<DonationModel>> watchAll() => _col.snapshots().map(_mapList);

  Stream<DonationModel?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? DonationModel.fromDoc(s) : null);

  List<DonationModel> _mapList(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(DonationModel.fromDoc).toList();

  // ------------------------------------------------------------------ write

  /// Creates a listing (draft or published). Uses a transaction so the
  /// write is confirmed by the server instead of being silently queued
  /// while offline.
  Future<String> create(DonationModel donation) async {
    try {
      final ref = _col.doc();
      await _db.runTransaction((tx) async {
        tx.set(ref, donation.toCreateMap());
      });
      return ref.id;
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Edits a draft or published listing. [newStatus] is used to publish a
  /// draft. Total portions can never drop below what is already requested,
  /// reserved or collected.
  Future<void> update(
    DonationModel donation, {
    String? newStatus,
  }) async {
    try {
      final ref = _col.doc(donation.id);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw AppException('This listing no longer exists.');
        final current = DonationModel.fromDoc(snap);
        if (current.providerId != donation.providerId) {
          throw AppException('You can only edit your own listings.');
        }
        if (!current.isEditable) {
          throw AppException('This listing can no longer be edited.');
        }
        final committed = current.reservedPortions +
            current.pendingPortions +
            current.completedPortions;
        if (donation.totalPortions < committed) {
          throw AppException(
              'Total portions cannot be less than $committed (already requested, reserved or collected).');
        }
        tx.update(
          ref,
          donation.toUpdateMap(status: newStatus ?? current.status),
        );
      });
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Withdraws a listing. Pending requests are rejected automatically.
  /// Blocked while accepted reservations exist: those must be cancelled or
  /// completed first.
  Future<void> cancel(String donationId, String providerId) async {
    try {
      final related = await _reservations
          .where('donationId', isEqualTo: donationId)
          .where('providerId', isEqualTo: providerId)
          .get();
      final ref = _col.doc(donationId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw AppException('This listing no longer exists.');
        final d = DonationModel.fromDoc(snap);
        if (d.providerId != providerId) {
          throw AppException('You can only withdraw your own listings.');
        }
        if (d.status != DonationStatus.draft &&
            d.status != DonationStatus.available) {
          throw AppException('This listing can no longer be withdrawn.');
        }
        if (d.reservedPortions > 0) {
          throw AppException(
              'Accepted reservations exist. Cancel them or finish the pickups before withdrawing this listing.');
        }
        final resSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in related.docs) {
          resSnaps.add(await tx.get(doc.reference));
        }
        for (final s in resSnaps) {
          if (s.data()?['status'] == ReservationStatus.pending) {
            tx.update(s.reference, {
              'status': ReservationStatus.rejected,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        tx.update(ref, {
          'status': DonationStatus.cancelled,
          'pendingPortions': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Closes a listing after at least one completed pickup.
  Future<void> closeAfterPickups(String donationId, String providerId) async {
    try {
      final ref = _col.doc(donationId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw AppException('This listing no longer exists.');
        final d = DonationModel.fromDoc(snap);
        if (d.providerId != providerId) {
          throw AppException('You can only close your own listings.');
        }
        if (d.status != DonationStatus.available) {
          throw AppException('This listing is not open.');
        }
        if (d.completedPortions <= 0) {
          throw AppException('Complete at least one pickup before closing.');
        }
        if (d.hasActiveReservations) {
          throw AppException(
              'Resolve pending and accepted reservations before closing.');
        }
        tx.update(ref, {
          'status': DonationStatus.completed,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  /// Marks the provider's past-deadline listings: "completed" when something
  /// was collected, otherwise "expired". Listings that still have accepted
  /// reservations awaiting handover are left alone.
  Future<void> expireOverdue(String providerId) async {
    final snap = await _col.where('providerId', isEqualTo: providerId).get();
    final now = DateTime.now();
    for (final doc in snap.docs) {
      final d = DonationModel.fromDoc(doc);
      if (d.status != DonationStatus.available ||
          !d.pickupDeadline.isBefore(now) ||
          d.pendingPortions > 0 ||
          d.reservedPortions > 0) {
        continue;
      }
      try {
        await _db.runTransaction((tx) async {
          final fresh = await tx.get(doc.reference);
          if (!fresh.exists) return;
          final f = DonationModel.fromDoc(fresh);
          if (f.status != DonationStatus.available ||
              !f.pickupDeadline.isBefore(DateTime.now()) ||
              f.hasActiveReservations) {
            return;
          }
          tx.update(doc.reference, {
            'status': f.completedPortions > 0
                ? DonationStatus.completed
                : DonationStatus.expired,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (_) {
        // Best effort clean-up; the UI already hides expired listings.
      }
    }
  }

  /// Creates three demo listings for the signed-in provider.
  Future<void> createSampleListings(UserModel provider) async {
    final now = DateTime.now();
    DonationModel sample({
      required String title,
      required String description,
      required String category,
      required int portions,
      required Duration deadlineIn,
      List<String> allergens = const [],
      List<String> tags = const [],
      String storage = '',
    }) =>
        DonationModel(
          id: '',
          providerId: provider.uid,
          providerName: provider.fullName,
          organizationName: provider.organizationName,
          title: title,
          description: description,
          category: category,
          totalPortions: portions,
          preparedAt: now.subtract(const Duration(minutes: 30)),
          pickupDeadline: now.add(deadlineIn),
          pickupAddress: provider.defaultPickupArea.isNotEmpty
              ? provider.defaultPickupArea
              : 'Main canteen, College Campus',
          allergens: allergens,
          dietaryTags: tags,
          storageInstructions: storage,
          safetyConfirmed: true,
          status: DonationStatus.available,
        );

    await create(sample(
      title: 'Vegetable Rice',
      description: 'Freshly prepared vegetable rice, surplus from lunch service.',
      category: 'Cooked meals',
      portions: 30,
      deadlineIn: const Duration(hours: 4),
      allergens: const ['Peanuts'],
      tags: const ['Vegetarian'],
      storage: 'Keep covered. Consume within 3 hours of pickup.',
    ));
    await create(sample(
      title: 'Bread loaves and buns',
      description: 'Day-old bakery bread, sealed and in good condition.',
      category: 'Bakery products',
      portions: 20,
      deadlineIn: const Duration(hours: 8),
      allergens: const ['Gluten', 'Milk'],
      tags: const ['Vegetarian', 'Contains dairy'],
      storage: 'Store in a cool, dry place.',
    ));
    await create(sample(
      title: 'Fruit boxes',
      description: 'Mixed seasonal fruit, cut and packed this morning.',
      category: 'Fruits and vegetables',
      portions: 15,
      deadlineIn: const Duration(hours: 24),
      allergens: const [kAllergenUnknown],
      tags: const ['Vegan'],
      storage: 'Keep refrigerated until pickup.',
    ));
  }
}
