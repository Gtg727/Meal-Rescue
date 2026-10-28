import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/donation_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/stat_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../routes/app_router.dart';
import '../donations/add_edit_donation_screen.dart';
import '../donations/donation_details_screen.dart';
import '../donations/my_listings_screen.dart';
import '../reservations/reservation_card.dart';

/// Provider dashboard: active listings, available portions, pending
/// reservations, completed donations and an Add Food button.
class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sweep());
  }

  /// Expires overdue reservations and listings (best effort).
  Future<void> _sweep() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().profile;
    if (user == null) return;
    final res = context.read<ReservationProvider>();
    final don = context.read<DonationProvider>();
    try {
      await res.expireOverdue(user.uid);
      await don.expireOverdue(user.uid);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final don = context.read<DonationProvider>();
    final res = context.read<ReservationProvider>();
    await don.refresh();
    await res.refresh();
    await _sweep();
  }

  Future<void> _loadSamples() async {
    final don = context.read<DonationProvider>();
    try {
      await don.createSampleListings();
      if (mounted) showSnack(context, 'Added 3 sample listings.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().profile;
    final don = context.watch<DonationProvider>();
    final res = context.watch<ReservationProvider>();
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${firstName(user.fullName)}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'listings') {
                AppRouter.push(context, const MyListingsScreen());
              } else if (v == 'sample') {
                _loadSamples();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'listings', child: Text('My listings & history')),
              PopupMenuItem(value: 'sample', child: Text('Load sample listings')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRouter.push(context, const AddEditDonationScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
      body: (don.mineLoading || res.loading)
          ? const LoadingView()
          : (don.mineError ?? res.error) != null
              ? ErrorView(
                  message: (don.mineError ?? res.error)!,
                  onRetry: _refresh,
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      StatGrid(children: [
                        StatCard(
                          icon: Icons.inventory_2_outlined,
                          label: 'Active listings',
                          value: '${don.activeListingCount}',
                          onTap: () =>
                              AppRouter.push(context, const MyListingsScreen()),
                        ),
                        StatCard(
                          icon: Icons.restaurant,
                          label: 'Portions available',
                          value: '${don.availablePortionsTotal}',
                        ),
                        StatCard(
                          icon: Icons.hourglass_top,
                          label: 'Pending requests',
                          value: '${res.pending.length}',
                          color: AppColors.amber,
                          onTap: () => context
                              .read<NavProvider>()
                              .go(NavProvider.reservations),
                        ),
                        StatCard(
                          icon: Icons.task_alt,
                          label: 'Completed donations',
                          value: '${don.completedDonationCount}',
                          color: AppColors.blue,
                        ),
                      ]),
                      SectionHeader(
                        'Pending requests',
                        actionLabel: res.pending.length > 3 ? 'See all' : null,
                        onAction: () => context
                            .read<NavProvider>()
                            .go(NavProvider.reservations),
                      ),
                      if (res.pending.isEmpty)
                        const AppCard(
                          child: Text(
                            'No reservation requests right now. They appear here as receivers reserve your food.',
                            style: TextStyle(color: AppColors.neutral),
                          ),
                        )
                      else
                        for (final r in res.pending.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReservationCard(
                              reservation: r,
                              viewerRole: AppRoles.provider,
                              showActions: true,
                            ),
                          ),
                      SectionHeader(
                        'Your active listings',
                        actionLabel: 'See all',
                        onAction: () =>
                            AppRouter.push(context, const MyListingsScreen()),
                      ),
                      if (don.activeMine.isEmpty)
                        const AppCard(
                          child: Text(
                            'No active listings yet. Tap "Add Food" to publish your surplus.',
                            style: TextStyle(color: AppColors.neutral),
                          ),
                        )
                      else
                        for (final d in don.activeMine.take(3))
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
