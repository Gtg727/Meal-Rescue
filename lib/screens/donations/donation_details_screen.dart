import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/format.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/donation_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/donation_model.dart';
import '../../models/reservation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../providers/moderation_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../routes/app_router.dart';
import '../reservations/reservation_card.dart';
import 'add_edit_donation_screen.dart';
import 'report_dialog.dart';

/// Screen 6 - full details of one listing, with role-specific actions.
class DonationDetailsScreen extends StatefulWidget {
  const DonationDetailsScreen({super.key, required this.donationId});

  final String donationId;

  @override
  State<DonationDetailsScreen> createState() => _DonationDetailsScreenState();
}

class _DonationDetailsScreenState extends State<DonationDetailsScreen> {
  late final Stream<DonationModel?> _stream =
      context.read<DonationProvider>().watchOne(widget.donationId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DonationModel?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Food details')),
            body: ErrorView(message: friendlyError(snap.error!)),
          );
        }
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Food details')),
            body: const LoadingView(),
          );
        }
        final d = snap.data;
        if (d == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Food details')),
            body: const EmptyView(
              icon: Icons.search_off,
              title: 'Listing not found',
              message: 'It may have been removed by the provider.',
            ),
          );
        }
        return _DetailsBody(donation: d);
      },
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.donation});

  final DonationModel donation;

  @override
  Widget build(BuildContext context) {
    final d = donation;
    final UserModel user = context.watch<AuthProvider>().profile!;
    final isOwner = user.uid == d.providerId;
    final status = d.effectiveStatus;
    final unknownAllergens = d.allergens.contains(kAllergenUnknown);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food details'),
        actions: [
          if (!isOwner)
            IconButton(
              tooltip: 'Report listing',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showReportDialog(context, d),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          DonationImage(url: d.imageUrl, height: 220),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(d.title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${d.category} · by ${d.providerLabel}',
                    style: const TextStyle(color: AppColors.neutral)),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        Icons.restaurant,
                        'Portions left',
                        '${d.reservablePortions} of ${d.totalPortions}'
                            '${d.pendingPortions > 0 ? '  (${d.pendingPortions} requested)' : ''}',
                      ),
                      _InfoRow(
                        Icons.schedule,
                        'Collect before',
                        '${formatDateTime(d.pickupDeadline)}'
                            '${d.isExpired ? '' : '  (${timeLeft(d.pickupDeadline)})'}',
                        valueColor: d.isExpired ? AppColors.red : null,
                      ),
                      _InfoRow(Icons.soup_kitchen_outlined, 'Prepared',
                          formatDateTime(d.preparedAt)),
                      _InfoRow(Icons.place_outlined, 'Pickup location',
                          d.pickupAddress),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final ok = await openInMaps(
                              address: d.pickupAddress,
                              latitude: d.latitude,
                              longitude: d.longitude,
                            );
                            if (!ok && context.mounted) {
                              showSnack(context,
                                  'Could not open maps on this device.',
                                  error: true);
                            }
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Open in Maps'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Allergens & storage',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (d.allergens.isEmpty)
                        const Text(
                          'No allergens declared by the provider. This does not guarantee the food is allergen free.',
                          style: TextStyle(color: AppColors.neutral),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final a in d.allergens)
                              Chip(
                                label: Text(a),
                                backgroundColor: a == kAllergenUnknown
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFFEE2E2),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      if (unknownAllergens)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'The provider has not checked every allergen. Ask before eating if you have allergies.',
                            style: TextStyle(color: AppColors.amber),
                          ),
                        ),
                      if (d.dietaryTags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final t in d.dietaryTags)
                              Chip(
                                label: Text(t),
                                backgroundColor: AppColors.mint,
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        d.storageInstructions.isEmpty
                            ? 'No storage instructions provided.'
                            : d.storageInstructions,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('About this food',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(d.description),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.health_and_safety_outlined,
                          color: AppColors.amber),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Food safety: the provider is responsible for the accuracy of this information. '
                          'Check the food before eating and do not consume anything that looks, smells or feels off. '
                          'Report unsafe or misleading listings with the flag icon.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (user.isReceiver) _ReserveSection(donation: d),
                if (isOwner) _OwnerSection(donation: d),
                if (user.isAdmin) _AdminSection(donation: d),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.neutral)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Receiver: choose portions and reserve.
class _ReserveSection extends StatefulWidget {
  const _ReserveSection({required this.donation});

  final DonationModel donation;

  @override
  State<_ReserveSection> createState() => _ReserveSectionState();
}

class _ReserveSectionState extends State<_ReserveSection> {
  int _portions = 1;

  /// Kept until the request succeeds so a retry cannot create a duplicate.
  String? _reservationId;
  bool _busy = false;

  void _setPortions(int value, int max) {
    setState(() {
      _portions = value.clamp(1, max < 1 ? 1 : max);
      _reservationId = null; // different request, new id
    });
  }

  Future<void> _reserve() async {
    final d = widget.donation;
    final ok = await confirmDialog(
      context,
      title: 'Reserve $_portions portion(s)?',
      message:
          'Your request goes to the provider for approval. Collect before ${formatDateTime(d.pickupDeadline)}.',
      confirmLabel: 'Reserve',
    );
    if (!ok || !mounted) return;

    final provider = context.read<ReservationProvider>();
    final nav = context.read<NavProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _reservationId ??= provider.newReservationId();
    setState(() => _busy = true);
    try {
      await provider.reserve(
        reservationId: _reservationId!,
        donationId: d.id,
        portions: _portions,
      );
      _reservationId = null;
      navigator.pop();
      nav.go(NavProvider.reservations);
      messenger.showSnackBar(
        const SnackBar(content: Text('Request sent. Waiting for the provider to approve.')),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    final mine = context
        .watch<ReservationProvider>()
        .activeForDonation(d.id)
        .toList();
    final max = d.reservablePortions;
    final portions = _portions.clamp(1, max < 1 ? 1 : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You have ${r.requestedPortions} portion(s) '
                      '${r.effectiveStatus == ReservationStatus.accepted ? 'accepted' : 'requested'} on this listing.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!d.canReserve)
          AppCard(
            child: Text(
              switch (d.effectiveStatus) {
                DonationStatus.expired =>
                  'This listing has expired and can no longer be reserved.',
                DonationStatus.reserved =>
                  'All portions are currently requested or reserved. Check back soon: they are released if a request is rejected or cancelled.',
                _ => 'This listing is not accepting reservations.',
              },
              style: const TextStyle(color: AppColors.neutral),
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Portions',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton.outlined(
                      onPressed: portions > 1
                          ? () => _setPortions(portions - 1, max)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('$portions',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    IconButton.outlined(
                      onPressed: portions < max
                          ? () => _setPortions(portions + 1, max)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Up to $max available',
                      style: const TextStyle(
                          color: AppColors.neutral, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _reserve,
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Reserve Food'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Provider (owner): edit, withdraw, close and review requests.
class _OwnerSection extends StatelessWidget {
  const _OwnerSection({required this.donation});

  final DonationModel donation;

  Future<void> _withdraw(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Withdraw listing?',
      message:
          'Pending requests will be rejected. Listings with accepted reservations cannot be withdrawn until those are cancelled or collected.',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final provider = context.read<DonationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.withdraw(donation.id);
      messenger.showSnackBar(const SnackBar(content: Text('Listing withdrawn.')));
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _close(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Close donation?',
      message:
          'The listing will be marked completed with ${donation.completedPortions} portion(s) collected. No further reservations will be possible.',
      confirmLabel: 'Close donation',
    );
    if (!ok || !context.mounted) return;
    final provider = context.read<DonationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.closeAfterPickups(donation.id);
      messenger.showSnackBar(const SnackBar(content: Text('Donation closed.')));
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = donation;
    final reservations = context.watch<ReservationProvider>().forDonation(d.id);
    final canWithdraw =
        d.status == DonationStatus.draft || d.status == DonationStatus.available;
    final canClose = d.status == DonationStatus.available &&
        d.completedPortions > 0 &&
        !d.hasActiveReservations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.isEditable)
          FilledButton.icon(
            onPressed: () =>
                AppRouter.push(context, AddEditDonationScreen(existing: d)),
            icon: const Icon(Icons.edit_outlined),
            label: Text(d.status == DonationStatus.draft
                ? 'Edit & publish'
                : 'Edit listing'),
          ),
        if (canClose) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _close(context),
            icon: const Icon(Icons.task_alt),
            label: Text('Close donation (${d.completedPortions} collected)'),
          ),
        ],
        if (canWithdraw) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            onPressed: () => _withdraw(context),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Withdraw listing'),
          ),
        ],
        if (reservations.isNotEmpty) ...[
          const SectionHeader('Reservations on this listing'),
          for (final ReservationModel r in reservations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReservationCard(
                reservation: r,
                viewerRole: AppRoles.provider,
                showActions: true,
              ),
            ),
        ],
      ],
    );
  }
}

/// Admin: remove a listing.
class _AdminSection extends StatelessWidget {
  const _AdminSection({required this.donation});

  final DonationModel donation;

  @override
  Widget build(BuildContext context) {
    final removable = donation.status != DonationStatus.cancelled &&
        donation.status != DonationStatus.completed;
    if (!removable) return const SizedBox.shrink();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red,
        side: const BorderSide(color: AppColors.red),
      ),
      onPressed: () async {
        final ok = await confirmDialog(
          context,
          title: 'Remove listing?',
          message:
              'The listing and all active reservations on it will be cancelled.',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        final provider = context.read<ModerationProvider>();
        try {
          await provider.takedownListing(donation.id);
          if (context.mounted) showSnack(context, 'Listing removed.');
        } catch (e) {
          if (context.mounted) showSnack(context, friendlyError(e), error: true);
        }
      },
      icon: const Icon(Icons.delete_outline),
      label: const Text('Remove listing (admin)'),
    );
  }
}
