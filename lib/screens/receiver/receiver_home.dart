import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/donation_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/stat_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../routes/app_router.dart';
import '../donations/donation_details_screen.dart';
import '../reservations/reservation_card.dart';

/// Receiver dashboard: available food, latest donations, active
/// reservations, completed pickups and meals collected.
class ReceiverHome extends StatelessWidget {
  const ReceiverHome({super.key});

  Future<void> _refresh(BuildContext context) async {
    final don = context.read<DonationProvider>();
    final res = context.read<ReservationProvider>();
    await don.refresh();
    await res.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().profile;
    final don = context.watch<DonationProvider>();
    final res = context.watch<ReservationProvider>();
    if (user == null) return const SizedBox.shrink();
    final nav = context.read<NavProvider>();

    final available = don.activeExplore.where((d) => d.canReserve).length;
    final latest = don.latest();

    return Scaffold(
      appBar: AppBar(title: Text('Hi, ${firstName(user.fullName)}')),
      body: (don.exploreLoading || res.loading)
          ? const LoadingView()
          : (don.exploreError ?? res.error) != null
              ? ErrorView(
                  message: (don.exploreError ?? res.error)!,
                  onRetry: () => _refresh(context),
                )
              : RefreshIndicator(
                  onRefresh: () => _refresh(context),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      StatGrid(children: [
                        StatCard(
                          icon: Icons.fastfood_outlined,
                          label: 'Food available',
                          value: '$available',
                          onTap: () => nav.go(NavProvider.explore),
                        ),
                        StatCard(
                          icon: Icons.hourglass_top,
                          label: 'Active reservations',
                          value: '${res.active.length}',
                          color: AppColors.amber,
                          onTap: () => nav.go(NavProvider.reservations),
                        ),
                        StatCard(
                          icon: Icons.task_alt,
                          label: 'Completed pickups',
                          value: '${res.completed.length}',
                          color: AppColors.blue,
                        ),
                        StatCard(
                          icon: Icons.volunteer_activism,
                          label: 'Meals collected',
                          value: '${res.completedPortionsTotal}',
                          onTap: () => nav.go(NavProvider.impact),
                        ),
                      ]),
                      SectionHeader(
                        'Active reservations',
                        actionLabel: res.active.length > 3 ? 'See all' : null,
                        onAction: () => nav.go(NavProvider.reservations),
                      ),
                      if (res.active.isEmpty)
                        const AppCard(
                          child: Text(
                            'No active reservations. Reserve food from the latest donations below.',
                            style: TextStyle(color: AppColors.neutral),
                          ),
                        )
                      else
                        for (final r in res.active.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReservationCard(
                              reservation: r,
                              viewerRole: AppRoles.receiver,
                            ),
                          ),
                      SectionHeader(
                        'Latest donations',
                        actionLabel: 'See all',
                        onAction: () => nav.go(NavProvider.explore),
                      ),
                      if (latest.isEmpty)
                        const AppCard(
                          child: Text(
                            'No food is listed right now. Pull down to refresh.',
                            style: TextStyle(color: AppColors.neutral),
                          ),
                        )
                      else
                        for (final d in latest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: DonationCard(
                              donation: d,
                              onTap: () => AppRouter.push(context,
                                  DonationDetailsScreen(donationId: d.id)),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
