import '../core/constants/app_constants.dart';
import 'donation_model.dart';
import 'reservation_model.dart';

/// Impact numbers computed from completed records only. Nothing here is a
/// manually maintained counter.
class ImpactStats {
  const ImpactStats({
    required this.completedDonations,
    required this.portionsRedistributed,
    required this.pickupsCompleted,
    required this.activeCount,
  });

  /// Provider/admin: donation records with status "completed".
  /// Receiver: distinct donations they collected food from.
  final int completedDonations;

  /// Sum of portions actually collected in completed reservations.
  final int portionsRedistributed;

  /// Number of completed reservations.
  final int pickupsCompleted;

  /// Provider/admin: listings currently active.
  /// Receiver: reservations currently pending/accepted.
  final int activeCount;

  /// [donations] is the provider's own listings (or all listings for admin).
  /// Pass null for receivers, who only know their own reservations.
  static ImpactStats compute({
    required List<ReservationModel> reservations,
    List<DonationModel>? donations,
  }) {
    final completed = reservations
        .where((r) => r.status == ReservationStatus.completed)
        .toList();
    final portions =
        completed.fold<int>(0, (sum, r) => sum + r.portionsCollected);

    if (donations != null) {
      return ImpactStats(
        completedDonations:
            donations.where((d) => d.status == DonationStatus.completed).length,
        portionsRedistributed: portions,
        pickupsCompleted: completed.length,
        activeCount: donations.where((d) => d.isActive).length,
      );
    }
    return ImpactStats(
      completedDonations: completed.map((r) => r.donationId).toSet().length,
      portionsRedistributed: portions,
      pickupsCompleted: completed.length,
      activeCount: reservations.where((r) => r.isActiveEffective).length,
    );
  }

  /// Most recent reservation activity first.
  static List<ReservationModel> recentActivity(
    List<ReservationModel> reservations, {
    int limit = 8,
  }) {
    final sorted = [...reservations]
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return sorted.take(limit).toList();
  }
}
