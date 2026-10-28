import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/reservation_provider.dart';
import 'reservation_card.dart';

/// Screen 7 - reservations, grouped by status. Receivers see their own
/// requests; providers see incoming requests with accept/reject actions.
class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().profile;
    final res = context.watch<ReservationProvider>();
    if (user == null) return const SizedBox.shrink();

    final isProvider = user.isProvider;
    final tabs = <_Tab>[
      _Tab(isProvider ? 'Requests' : 'Pending', res.pending,
          isProvider ? 'No incoming requests' : 'No pending reservations'),
      _Tab('Accepted', res.accepted, 'No accepted reservations'),
      _Tab('Completed', res.completed, 'No completed pickups yet'),
      _Tab('Closed', res.closed, 'Nothing rejected, cancelled or expired'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user.isAdmin ? 'All reservations' : 'Reservations'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [
              for (final t in tabs)
                Tab(text: t.items.isEmpty ? t.label : '${t.label} (${t.items.length})'),
            ],
          ),
        ),
        body: res.loading
            ? const LoadingView()
            : res.error != null
                ? ErrorView(message: res.error!, onRetry: res.refresh)
                : TabBarView(
                    children: [
                      for (final t in tabs)
                        _ReservationList(
                          tab: t,
                          viewerRole: user.role,
                          onRefresh: res.refresh,
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.items, this.emptyText);

  final String label;
  final List<ReservationModel> items;
  final String emptyText;
}

class _ReservationList extends StatelessWidget {
  const _ReservationList({
    required this.tab,
    required this.viewerRole,
    required this.onRefresh,
  });

  final _Tab tab;
  final String viewerRole;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: tab.items.isEmpty
          ? EmptyView(
              icon: Icons.receipt_long_outlined,
              title: tab.emptyText,
              message: viewerRole == AppRoles.receiver
                  ? 'Find food in Explore and reserve portions to see them here.'
                  : 'Reservations will appear here as they happen.',
              actionLabel: viewerRole == AppRoles.receiver ? 'Browse food' : null,
              onAction: viewerRole == AppRoles.receiver
                  ? () => context.read<NavProvider>().go(NavProvider.explore)
                  : null,
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tab.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => ReservationCard(
                reservation: tab.items[i],
                viewerRole: viewerRole,
                showActions: true,
              ),
            ),
    );
  }
}
