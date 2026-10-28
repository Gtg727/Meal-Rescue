import '../constants/app_constants.dart';

/// Form validators. Each returns an error message or null when valid.
class Validators {
  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(value);
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    return v == original ? null : 'Passwords do not match';
  }

  static String? fullName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Full name is required';
    if (value.length < 2) return 'Enter your full name';
    return null;
  }

  /// Phone is optional; when given it must look like a phone number.
  static String? phoneOptional(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[\s\-+()]'), '');
    return RegExp(r'^\d{10,13}$').hasMatch(digits)
        ? null
        : 'Enter a valid phone number';
  }

  static String? title(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Food title is required';
    if (value.length < 3 || value.length > 80) {
      return 'Title must be 3-80 characters';
    }
    return null;
  }

  static String? description(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Description is required';
    if (value.length < 10) return 'Please describe the food in a bit more detail';
    return null;
  }

  static String? address(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Pickup address is required';
    if (value.length < 5) return 'Enter a usable pickup address';
    return null;
  }

  static String? positiveInt(String? v, {int? max, String field = 'Value'}) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return '$field is required';
    final n = int.tryParse(value);
    if (n == null) return 'Enter a whole number';
    if (n <= 0) return '$field must be at least 1';
    if (max != null && n > max) return '$field cannot exceed $max';
    return null;
  }

  static String? category(String? v) =>
      (v != null && kCategories.contains(v)) ? null : 'Choose a category';

  static String? preparedAt(DateTime? d, {DateTime? now}) {
    if (d == null) return 'Preparation time is required';
    final current = now ?? DateTime.now();
    if (d.isAfter(current.add(kPreparedAtTolerance))) {
      return 'Preparation time cannot be in the future';
    }
    return null;
  }

  static String? pickupDeadline(
    DateTime? deadline,
    DateTime? prepared, {
    DateTime? now,
  }) {
    if (deadline == null) return 'Pickup deadline is required';
    final current = now ?? DateTime.now();
    if (!deadline.isAfter(current)) return 'Deadline must be in the future';
    if (prepared != null && !deadline.isAfter(prepared)) {
      return 'Deadline must be after the preparation time';
    }
    return null;
  }
}
