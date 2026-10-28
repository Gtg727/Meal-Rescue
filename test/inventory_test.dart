import 'package:flutter_test/flutter_test.dart';
import 'package:meal_rescue/core/constants/app_constants.dart';
import 'package:meal_rescue/core/utils/inventory.dart';

void main() {
  group('allocatablePortions (Total - Accepted - Completed)', () {
    test('spec example: 30 total, 18 accepted/collected, 12 left', () {
      expect(allocatablePortions(total: 30, reserved: 18, completed: 0), 12);
      expect(allocatablePortions(total: 30, reserved: 0, completed: 18), 12);
    });

    test('never negative', () {
      expect(allocatablePortions(total: 5, reserved: 4, completed: 4), 0);
    });
  });

  group('reservablePortions (also subtracts pending)', () {
    test('pending requests cannot be double-booked', () {
      expect(
        reservablePortions(total: 30, reserved: 0, completed: 0, pending: 10),
        20,
      );
    });
  });

  group('validateReservationRequest', () {
    String? check({
      int requested = 5,
      int reservable = 10,
      bool expired = false,
      String status = DonationStatus.available,
    }) =>
        validateReservationRequest(
          requested: requested,
          reservable: reservable,
          isExpired: expired,
          status: status,
        );

    test('FR-04: valid request is allowed', () => expect(check(), isNull));

    test('FR-06: more than available is blocked with a clear message', () {
      final msg = check(requested: 11, reservable: 10);
      expect(msg, isNotNull);
      expect(msg, contains('10'));
    });

    test('FR-14: expired listing is blocked', () {
      expect(check(expired: true), contains('expired'));
    });

    test('draft / cancelled / completed listings are blocked', () {
      for (final s in [
        DonationStatus.draft,
        DonationStatus.cancelled,
        DonationStatus.completed,
      ]) {
        expect(check(status: s), isNotNull, reason: s);
      }
    });

    test('zero or negative portions are blocked', () {
      expect(check(requested: 0), isNotNull);
      expect(check(requested: -3), isNotNull);
    });

    test('fully requested listing is blocked', () {
      expect(check(reservable: 0), contains('already'));
    });
  });

  group('canAcceptRequest', () {
    test('accepts while portions remain', () {
      expect(
        canAcceptRequest(requested: 10, total: 30, reserved: 8, completed: 0),
        isTrue,
      );
    });

    test('refuses once accepted + completed would exceed total', () {
      expect(
        canAcceptRequest(requested: 13, total: 30, reserved: 10, completed: 8),
        isFalse,
      );
    });
  });
}
