import 'dart:math';

import '../constants/app_constants.dart';

/// Pure inventory helpers (no Firebase), so the quantity rules from the
/// specification can be unit tested.
///
/// Terminology
///  * total      – portions the provider published
///  * pending    – portions requested but not yet approved
///  * reserved   – portions in ACCEPTED reservations, not yet collected
///  * completed  – portions already handed over

/// Spec formula: Available = Total - Accepted - Completed.
int allocatablePortions({
  required int total,
  required int reserved,
  required int completed,
}) =>
    max(0, total - reserved - completed);

/// Portions a NEW request may still claim. Pending requests are counted so
/// that concurrent requests can never over-allocate the listing.
int reservablePortions({
  required int total,
  required int reserved,
  required int completed,
  required int pending,
}) =>
    max(0, total - reserved - completed - pending);

/// Returns an error message when a new reservation request must be blocked,
/// or null when it is allowed.
String? validateReservationRequest({
  required int requested,
  required int reservable,
  required bool isExpired,
  required String status,
}) {
  if (isExpired) {
    return 'This listing has expired and can no longer be reserved.';
  }
  if (status != DonationStatus.available) {
    return 'This listing is not accepting reservations.';
  }
  if (requested <= 0) return 'Enter at least 1 portion.';
  if (reservable <= 0) return 'All portions have already been requested.';
  if (requested > reservable) {
    return 'Only $reservable portion${reservable == 1 ? '' : 's'} left. '
        'Please reduce your request.';
  }
  return null;
}

/// Whether the provider may accept a request for [requested] portions.
bool canAcceptRequest({
  required int requested,
  required int total,
  required int reserved,
  required int completed,
}) =>
    requested <= allocatablePortions(
      total: total,
      reserved: reserved,
      completed: completed,
    );
