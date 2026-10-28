/// Central place for role names, status values, collection names and
/// the predefined option lists used by forms.
class AppRoles {
  static const provider = 'provider';
  static const receiver = 'receiver';
  static const admin = 'admin';

  /// Roles a user may pick at registration. Admin can only be granted
  /// manually in the Firebase console.
  static const selectable = [provider, receiver];

  static String label(String role) {
    switch (role) {
      case provider:
        return 'Food provider';
      case receiver:
        return 'Food receiver';
      case admin:
        return 'Admin';
      default:
        return role;
    }
  }
}

class DonationStatus {
  static const draft = 'draft';
  static const available = 'available';
  static const reserved = 'reserved';
  static const completed = 'completed';
  static const expired = 'expired';
  static const cancelled = 'cancelled';
}

class ReservationStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const completed = 'completed';
  static const expired = 'expired';

  /// Reservations that still hold (or are waiting for) inventory.
  static const active = [pending, accepted];
}

class Collections {
  static const users = 'users';
  static const donations = 'donations';
  static const reservations = 'reservations';
  static const reports = 'reports';
}

const kAppName = 'MealRescue';
const kTagline = 'Rescue Food. Share Hope.';

const kCategories = <String>[
  'Cooked meals',
  'Rice and bread',
  'Fruits and vegetables',
  'Bakery products',
  'Packaged food',
  'Other',
];

/// "Unknown" lets a provider disclose that allergen status was not checked
/// instead of implying the food is allergen free.
const kAllergenUnknown = 'Unknown / not checked';
const kAllergens = <String>[
  'Peanuts',
  'Tree nuts',
  'Milk',
  'Eggs',
  'Gluten',
  'Soy',
  'Fish',
  'Shellfish',
  'Sesame',
  kAllergenUnknown,
];

const kDietaryTags = <String>[
  'Vegetarian',
  'Vegan',
  'Contains dairy',
  'Contains egg',
  'Non-vegetarian',
];

const kReportReasons = <String>[
  'Unsafe or spoiled food',
  'Incorrect food information',
  'Misleading listing',
  'Suspicious activity',
  'Other',
];

/// Maximum size of a compressed food photo. It is stored as base64 inside the
/// Firestore listing document (1 MiB limit), and base64 adds ~33%.
const kMaxImageBytes = 400 * 1024;

/// How far in the future a "prepared at" time may be (clock skew tolerance).
const kPreparedAtTolerance = Duration(minutes: 5);
