import 'package:flutter_test/flutter_test.dart';
import 'package:meal_rescue/core/utils/validators.dart';

void main() {
  group('auth validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('canteen@example.com'), isNull);
    });

    test('password needs 8+ chars with a letter and a number', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('Rescue2026'), isNull);
    });

    test('confirm password', () {
      expect(Validators.confirmPassword('a', 'b'), isNotNull);
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
    });

    test('phone is optional but must look valid when given', () {
      expect(Validators.phoneOptional(''), isNull);
      expect(Validators.phoneOptional('9000000000'), isNull);
      expect(Validators.phoneOptional('12'), isNotNull);
    });
  });

  group('listing form validators', () {
    test('title is 3-80 characters', () {
      expect(Validators.title('ab'), isNotNull);
      expect(Validators.title('Vegetable Rice'), isNull);
      expect(Validators.title('x' * 81), isNotNull);
    });

    test('category must be predefined', () {
      expect(Validators.category('Cooked meals'), isNull);
      expect(Validators.category('Mystery'), isNotNull);
      expect(Validators.category(null), isNotNull);
    });

    test('positive integer', () {
      expect(Validators.positiveInt('30'), isNull);
      expect(Validators.positiveInt('0'), isNotNull);
      expect(Validators.positiveInt('-2'), isNotNull);
      expect(Validators.positiveInt('2.5'), isNotNull);
      expect(Validators.positiveInt('11', max: 10), isNotNull);
    });

    test('prepared time cannot be in the future', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(Validators.preparedAt(now.subtract(const Duration(hours: 1)), now: now), isNull);
      expect(Validators.preparedAt(now.add(const Duration(hours: 2)), now: now), isNotNull);
      expect(Validators.preparedAt(null, now: now), isNotNull);
    });

    test('deadline must be in the future and after preparation', () {
      final now = DateTime(2026, 1, 1, 12);
      final prepared = now.subtract(const Duration(hours: 1));
      expect(Validators.pickupDeadline(now.add(const Duration(hours: 3)), prepared, now: now), isNull);
      expect(Validators.pickupDeadline(now.subtract(const Duration(minutes: 1)), prepared, now: now), isNotNull);
      expect(Validators.pickupDeadline(null, prepared, now: now), isNotNull);
    });
  });
}
