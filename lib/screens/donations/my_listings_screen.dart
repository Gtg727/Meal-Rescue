import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/donation_card.dart';
import '../../core/widgets/state_views.dart';
import '../../models/donation_model.dart';
import '../../providers/donation_provider.dart';
import '../../routes/app_router.dart';
import 'add_edit_donation_screen.dart';
import 'donation_details_screen.dart';

/// Provider's listings grouped as Active, Drafts and History.
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final don = context.watch<DonationProvider>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My listings'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Active (${don.activeMine.length})'),
              Tab(text: 'Drafts (${don.drafts.length})'),
              Tab(text: 'History (${don.history.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              AppRouter.push(context, const AddEditDonationScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Add Food'),
        ),
        body: don.mineLoading
            ? const LoadingView()
            : don.mineError != null
                ? ErrorView(message: don.mineError!, onRetry: don.refresh)
                : TabBarView(
                    children: [
                      _List(
                        items: don.activeMine,
                        empty: 'No active listings',
                        emptyHint: 'Tap Add Food to publish surplus food.',
                        onRefresh: don.refresh,
                      ),
                      _List(
                        items: don.drafts,
                        empty: 'No drafts',
                        emptyHint: 'Drafts you save will appear here.',
                        onRefresh: don.refresh,
                      ),
                      _List(
                        items: don.history,
                        empty: 'No history yet',
                        emptyHint:
                            'Completed, expired and withdrawn listings appear here.',
                        onRefresh: don.refresh,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.items,
    required this.empty,
    required this.emptyHint,
    required this.onRefresh,
  });

  final List<DonationModel> items;
  final String empty;
  final String emptyHint;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: items.isEmpty
          ? EmptyView(
              icon: Icons.inventory_2_outlined,
              title: empty,
              message: emptyHint,
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => DonationCard(
                donation: items[i],
                onTap: () => AppRouter.push(
                    context, DonationDetailsScreen(donationId: items[i].id)),
              ),
            ),
    );
  }
}
