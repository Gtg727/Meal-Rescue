import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/donation_card.dart';
import '../../core/widgets/state_views.dart';
import '../../models/donation_model.dart';
import '../../providers/donation_provider.dart';
import '../../routes/app_router.dart';
import 'donation_details_screen.dart';

/// Screen 5 - browse donations with search, filters and sorting.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  String? _category;
  ExploreSort _sort = ExploreSort.earliestDeadline;
  DeadlineFilter _within = DeadlineFilter.any;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _search.text.trim().isNotEmpty ||
      _category != null ||
      _within != DeadlineFilter.any;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DonationProvider>();
    final items = provider.exploreFiltered(
      query: _search.text,
      category: _category,
      sort: _sort,
      within: _within,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Explore food')),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: AppTheme.inputDecoration(
                    'Search food, provider or area',
                    icon: Icons.search,
                    suffix: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('All', _category == null,
                          () => setState(() => _category = null)),
                      for (final c in kCategories)
                        _chip(c, _category == c,
                            () => setState(() => _category = c)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdown<ExploreSort>(
                        label: 'Sort by',
                        value: _sort,
                        items: const [
                          DropdownMenuItem(
                            value: ExploreSort.earliestDeadline,
                            child: Text('Earliest deadline'),
                          ),
                          DropdownMenuItem(
                            value: ExploreSort.newest,
                            child: Text('Recently posted'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _sort = v ?? _sort),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppDropdown<DeadlineFilter>(
                        label: 'Pickup deadline',
                        value: _within,
                        items: const [
                          DropdownMenuItem(
                            value: DeadlineFilter.any,
                            child: Text('Any time'),
                          ),
                          DropdownMenuItem(
                            value: DeadlineFilter.twoHours,
                            child: Text('Within 2 hours'),
                          ),
                          DropdownMenuItem(
                            value: DeadlineFilter.today,
                            child: Text('Today'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _within = v ?? _within),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _content(provider, items)),
        ],
      ),
    );
  }

  Widget _content(DonationProvider provider, List<DonationModel> items) {
    if (provider.exploreLoading) return const LoadingView();
    if (provider.exploreError != null) {
      return ErrorView(message: provider.exploreError!, onRetry: provider.refresh);
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.refresh,
        child: EmptyView(
          icon: Icons.fastfood_outlined,
          title: _filtersActive
              ? 'No matching food'
              : 'No food available right now',
          message: _filtersActive
              ? 'Try clearing the search or filters.'
              : 'New surplus food is posted throughout the day. Pull down or tap refresh to check again.',
          actionLabel: 'Refresh',
          onAction: provider.refresh,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final d = items[i];
          return DonationCard(
            donation: d,
            onTap: () => AppRouter.push(
                context, DonationDetailsScreen(donationId: d.id)),
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.mint,
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : AppColors.slate,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border),
        ),
      );
}
