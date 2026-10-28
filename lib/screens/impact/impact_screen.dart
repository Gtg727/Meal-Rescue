import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/impact_stats.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../routes/app_router.dart';
import '../reservations/reservation_details_screen.dart';

/// Screen 9 - impact dashboard. Every number is computed from completed
/// reservation and donation records, never from a stored counter.
class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().profile;
    final don = context.watch<DonationProvider>();
    final res = context.watch<ReservationProvider>();
    if (user == null) return const SizedBox.shrink();

    final loading = res.loading || (!user.isReceiver && don.mineLoading);
    final error = res.error ?? (user.isReceiver ? null : don.mineError);

    final stats = ImpactStats.compute(
      reservations: res.reservations,
      donations: user.isReceiver ? null : don.mine,
    );
    final recent = ImpactStats.recentActivity(res.reservations);

    final String title;
    final String subtitle;
    final String activeLabel;
    final String completedLabel;
    if (user.isAdmin) {
      title = 'Platform impact';
      subtitle = 'Across all providers and receivers';
      activeLabel = 'Donations active now';
      completedLabel = 'Completed donations';
    } else if (user.isProvider) {
      title = 'Your impact';
      subtitle = 'Food you have shared';
      activeLabel = 'Donations active now';
      completedLabel = 'Completed donations';
    } else {
      title = 'Your impact';
      subtitle = 'Food you have rescued';
      activeLabel = 'Active reservations';
      completedLabel = 'Donations collected from';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Impact')),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(message: error, onRetry: res.refresh)
              : RefreshIndicator(
                  onRefresh: () async {
                    await res.refresh();
                    if (!user.isReceiver) await don.refresh();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                            Text(subtitle,
                                style: const TextStyle(color: AppColors.mint)),
                            const SizedBox(height: 16),
                            Text(
                              '${stats.portionsRedistributed}',
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900),
                            ),
                            const Text('portions redistributed',
                                style: TextStyle(color: AppColors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatGrid(children: [
                        StatCard(
                          icon: Icons.task_alt,
                          label: completedLabel,
                          value: '${stats.completedDonations}',
                        ),
                        StatCard(
                          icon: Icons.handshake_outlined,
                          label: 'Pickups completed',
                          value: '${stats.pickupsCompleted}',
                          color: AppColors.blue,
                        ),
                        StatCard(
                          icon: Icons.bolt,
                          label: activeLabel,
                          value: '${stats.activeCount}',
                          color: AppColors.amber,
                        ),
                        StatCard(
                          icon: Icons.restaurant,
                          label: 'Portions redistributed',
                          value: '${stats.portionsRedistributed}',
                        ),
                      ]),
                      const SectionHeader('Recent activity'),
                      if (recent.isEmpty)
                        const AppCard(
                          child: Text(
                            'No activity yet. Completed pickups update these numbers automatically.',
                            style: TextStyle(color: AppColors.neutral),
                          ),
                        )
                      else
                        for (final r in recent)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityTile(reservation: r),
                          ),
                      const SizedBox(height: 8),
                      const Text(
                        'Impact counts only portions confirmed as handed over. '
                        'It does not estimate kilograms of food or emissions.',
                        style: TextStyle(color: AppColors.neutral, fontSize: 12),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.reservation});

  final ReservationModel reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final status = r.effectiveStatus;
    final done = status == ReservationStatus.completed;
    final text = switch (status) {
      ReservationStatus.completed =>
        '${r.portionsCollected} portion(s) of ${r.donationTitle} collected',
      ReservationStatus.accepted =>
        '${r.requestedPortions} portion(s) of ${r.donationTitle} accepted',
      ReservationStatus.pending =>
        '${r.requestedPortions} portion(s) of ${r.donationTitle} requested',
      _ => '${r.donationTitle}: ${status}',
    };
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => AppRouter.push(
          context, ReservationDetailsScreen(reservationId: r.id)),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.history,
            color: done ? AppColors.primary : AppColors.neutral,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(formatDateTime(r.lastActivity),
                    style: const TextStyle(
                        color: AppColors.neutral, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
