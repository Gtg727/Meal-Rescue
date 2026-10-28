import 'package:flutter_test/flutter_test.dart';
import 'package:meal_rescue/core/constants/app_constants.dart';
import 'package:meal_rescue/core/utils/format.dart';
import 'package:meal_rescue/models/donation_model.dart';

DonationModel donation({
  required DateTime deadline,
  String status = DonationStatus.available,
  int total = 30,
  int reserved = 0,
  int pending = 0,
  int completed = 0,
}) =>
    DonationModel(
      id: 'd1',
      providerId: 'p1',
      providerName: 'Canteen',
      title: 'Vegetable Rice',
      description: 'Freshly prepared surplus food',
      category: 'Cooked meals',
      totalPortions: total,
      reservedPortions: reserved,
      pendingPortions: pending,
      completedPortions: completed,
      preparedAt: DateTime.now().subtract(const Duration(hours: 1)),
      pickupDeadline: deadline,
      pickupAddress: 'College Canteen',
      status: status,
    );

void main() {
  final future = DateTime.now().add(const Duration(hours: 3));
  final past = DateTime.now().subtract(const Duration(minutes: 5));

  group('DonationModel status logic', () {
    test('FR-03: fresh listing shows all 30 portions reservable', () {
      final d = donation(deadline: future);
      expect(d.reservablePortions, 30);
      expect(d.canReserve, isTrue);
      expect(d.effectiveStatus, DonationStatus.available);
    });

    test('FR-07: listing past its deadline is expired and not reservable', () {
      final d = donation(deadline: past);
      expect(d.effectiveStatus, DonationStatus.expired);
      expect(d.canReserve, isFalse);
    });

    test('all portions allocated -> derived status "reserved"', () {
      final d = donation(deadline: future, reserved: 20, pending: 10);
      expect(d.reservablePortions, 0);
      expect(d.effectiveStatus, DonationStatus.reserved);
      expect(d.canReserve, isFalse);
    });

    test('draft and cancelled listings are never reservable', () {
      expect(donation(deadline: future, status: DonationStatus.draft).canReserve, isFalse);
      expect(donation(deadline: future, status: DonationStatus.cancelled).canReserve, isFalse);
    });

    test('only drafts and live listings are editable', () {
      expect(donation(deadline: future).isEditable, isTrue);
      expect(donation(deadline: past).isEditable, isFalse);
      expect(donation(deadline: future, status: DonationStatus.completed).isEditable, isFalse);
    });
  });

  group('format helpers', () {
    test('timeLeft', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(timeLeft(now.subtract(const Duration(minutes: 1)), now: now), 'Expired');
      expect(timeLeft(now.add(const Duration(minutes: 45)), now: now), '45m left');
      expect(timeLeft(now.add(const Duration(hours: 2, minutes: 5)), now: now), '2h 5m left');
    });

    test('initials and firstName', () {
      expect(initials('Gautam Kishnani'), 'GK');
      expect(initials(''), '?');
      expect(firstName('  Asha Rao '), 'Asha');
    });
  });
}
