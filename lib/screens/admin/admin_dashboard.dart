import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../providers/moderation_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../routes/app_router.dart';
import '../donations/donation_details_screen.dart';

/// Admin home: summary counts, reported listings and user management.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationProvider>();
    final don = context.watch<DonationProvider>();
    final res = context.watch<ReservationProvider>();
    final admin = context.watch<AuthProvider>().profile!;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [
              const Tab(text: 'Summary'),
              Tab(text: 'Reports (${mod.openReports.length})'),
              Tab(text: 'Users (${mod.users.length})'),
            ],
          ),
        ),
        body: (mod.loading || don.mineLoading || res.loading)
            ? const LoadingView()
            : mod.error != null
                ? ErrorView(message: mod.error!)
                : TabBarView(
                    children: [
                      _Summary(
                        users: mod.users,
                        activeListings: don.activeListingCount,
                        completedDonations: don.completedDonationCount,
                        portions: res.completedPortionsTotal,
                        openReports: mod.openReports.length,
                      ),
                      _Reports(reports: mod.reports),
                      _Users(users: mod.users, selfUid: admin.uid),
                    ],
                  ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.users,
    required this.activeListings,
    required this.completedDonations,
    required this.portions,
    required this.openReports,
  });

  final List<UserModel> users;
  final int activeListings;
  final int completedDonations;
  final int portions;
  final int openReports;

  @override
  Widget build(BuildContext context) {
    final providers = users.where((u) => u.isProvider).length;
    final receivers = users.where((u) => u.isReceiver).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatGrid(children: [
          StatCard(
              icon: Icons.storefront,
              label: 'Providers',
              value: '$providers'),
          StatCard(
              icon: Icons.volunteer_activism,
              label: 'Receivers',
              value: '$receivers',
              color: AppColors.blue),
          StatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Active listings',
              value: '$activeListings'),
          StatCard(
              icon: Icons.task_alt,
              label: 'Completed donations',
              value: '$completedDonations',
              color: AppColors.blue),
          StatCard(
              icon: Icons.restaurant,
              label: 'Portions redistributed',
              value: '$portions'),
          StatCard(
              icon: Icons.flag_outlined,
              label: 'Open reports',
              value: '$openReports',
              color: openReports > 0 ? AppColors.red : AppColors.neutral),
        ]),
        const SizedBox(height: 16),
        const Text(
          'Admin accounts are created by setting a user\'s role to "admin" in the Firebase console.',
          style: TextStyle(color: AppColors.neutral, fontSize: 12),
        ),
      ],
    );
  }
}

class _Reports extends StatelessWidget {
  const _Reports({required this.reports});

  final List<ReportModel> reports;

  Future<void> _resolve(
      BuildContext context, ReportModel r, {required bool dismiss}) async {
    try {
      await context.read<ModerationProvider>().resolveReport(r.id, dismiss: dismiss);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const EmptyView(
        icon: Icons.flag_outlined,
        title: 'No reports',
        message: 'Reported listings will show up here for review.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = reports[i];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.donationTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Text(
                    r.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: r.isOpen ? AppColors.red : AppColors.neutral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.reason, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (r.details.isNotEmpty) Text(r.details),
              const SizedBox(height: 4),
              Text(
                'Reported by ${r.reporterName}'
                '${r.createdAt == null ? '' : ' · ${formatDateTime(r.createdAt!)}'}',
                style: const TextStyle(color: AppColors.neutral, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => AppRouter.push(context,
                        DonationDetailsScreen(donationId: r.donationId)),
                    child: const Text('View listing'),
                  ),
                  if (r.isOpen) ...[
                    TextButton(
                      onPressed: () => _resolve(context, r, dismiss: true),
                      child: const Text('Dismiss'),
                    ),
                    TextButton(
                      onPressed: () => _resolve(context, r, dismiss: false),
                      child: const Text('Mark resolved'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Users extends StatelessWidget {
  const _Users({required this.users, required this.selfUid});

  final List<UserModel> users;
  final String selfUid;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const EmptyView(
        icon: Icons.people_outline,
        title: 'No users yet',
        message: 'Registered users appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = users[i];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mint,
                child: Text(initials(u.fullName),
                    style: const TextStyle(color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.displayOrg,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${u.email} · ${u.role}',
                        style: const TextStyle(
                            color: AppColors.neutral, fontSize: 12)),
                  ],
                ),
              ),
              if (u.uid != selfUid && !u.isAdmin)
                Column(
                  children: [
                    const Text('Verified', style: TextStyle(fontSize: 10)),
                    Switch(
                      value: u.isVerified,
                      onChanged: (v) async {
                        try {
                          await context
                              .read<ModerationProvider>()
                              .setVerified(u.uid, v);
                        } catch (e) {
                          if (context.mounted) {
                            showSnack(context, friendlyError(e), error: true);
                          }
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
