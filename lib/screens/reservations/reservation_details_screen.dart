import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/format.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/donation_model.dart';
import '../../models/reservation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../routes/app_router.dart';
import '../donations/donation_details_screen.dart';
import 'reservation_actions.dart';

/// Screen 8 - pickup and completion.
///
/// Flow: receiver confirms collection -> provider confirms handover ->
/// reservation is completed (once) and impact updates.
class ReservationDetailsScreen extends StatefulWidget {
  const ReservationDetailsScreen({super.key, required this.reservationId});

  final String reservationId;

  @override
  State<ReservationDetailsScreen> createState() =>
      _ReservationDetailsScreenState();
}

class _ReservationDetailsScreenState extends State<ReservationDetailsScreen> {
  late final Stream<ReservationModel?> _stream =
      context.read<ReservationProvider>().watchOne(widget.reservationId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReservationModel?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reservation')),
            body: ErrorView(message: friendlyError(snap.error!)),
          );
        }
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reservation')),
            body: const LoadingView(),
          );
        }
        final r = snap.data;
        if (r == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reservation')),
            body: const EmptyView(
              icon: Icons.search_off,
              title: 'Reservation not found',
              message: 'It may have been removed.',
            ),
          );
        }
        return _Body(reservation: r);
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.reservation});

  final ReservationModel reservation;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final Stream<DonationModel?> _donationStream =
      context.read<DonationProvider>().watchOne(widget.reservation.donationId);
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final UserModel user = context.watch<AuthProvider>().profile!;
    final status = r.effectiveStatus;
    final isReceiver = user.uid == r.receiverId;
    final isProvider = user.uid == r.providerId;
    final shareContacts = status == ReservationStatus.accepted ||
        status == ReservationStatus.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.donationTitle,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    StatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reservation ID copied')),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          size: 16, color: AppColors.neutral),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('ID: ${r.id}',
                            style: const TextStyle(
                                color: AppColors.neutral, fontSize: 12)),
                      ),
                      const Icon(Icons.copy, size: 14, color: AppColors.neutral),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _Row(Icons.restaurant, 'Portions',
                    status == ReservationStatus.completed
                        ? '${r.portionsCollected} collected (of ${r.requestedPortions} requested)'
                        : '${r.requestedPortions} requested'),
                _Row(Icons.schedule, 'Collect before',
                    '${formatDateTime(r.pickupDeadline)}'
                    '${r.isActiveEffective ? '  (${timeLeft(r.pickupDeadline)})' : ''}'),
                _Row(Icons.place_outlined, 'Pickup address', r.pickupAddress),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await openInMaps(address: r.pickupAddress);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not open maps on this device.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Open in Maps'),
                  ),
                ),
                _Row(Icons.storefront, 'Provider',
                    r.providerName),
                _Row(Icons.person_outline, 'Receiver', r.receiverLabel),
                if (shareContacts && isReceiver && r.providerPhone.isNotEmpty)
                  _Row(Icons.phone_outlined, 'Provider phone', r.providerPhone),
                if (shareContacts && isProvider && r.receiverPhone.isNotEmpty)
                  _Row(Icons.phone_outlined, 'Receiver phone', r.receiverPhone),
              ],
            ),
          ),
          StreamBuilder<DonationModel?>(
            stream: _donationStream,
            builder: (context, snap) {
              final d = snap.data;
              if (d == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Collection instructions',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(d.storageInstructions.isEmpty
                          ? 'No special storage instructions provided.'
                          : d.storageInstructions),
                      const SizedBox(height: 8),
                      Text(
                        d.allergens.isEmpty
                            ? 'Allergens: none declared (this is not a guarantee).'
                            : 'Allergens: ${d.allergens.join(', ')}',
                        style: const TextStyle(color: AppColors.neutral),
                      ),
                      TextButton(
                        onPressed: () => AppRouter.push(
                            context, DonationDetailsScreen(donationId: d.id)),
                        child: const Text('View listing'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Progress',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _Step('Requested', true),
                _Step(
                    'Accepted by provider',
                    r.status == ReservationStatus.accepted ||
                        r.status == ReservationStatus.completed),
                _Step('Receiver confirmed collection', r.receiverConfirmed),
                _Step('Provider confirmed handover', r.providerConfirmed),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._actions(context, r, status, isReceiver, isProvider),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, ReservationModel r,
      String status, bool isReceiver, bool isProvider) {
    Widget info(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral)),
        );
    Widget filled(String label, Future<bool> Function() action) => FilledButton(
          onPressed: _busy ? null : () => _run(action),
          child: Text(label),
        );
    Widget danger(String label, Future<bool> Function() action) =>
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
          ),
          onPressed: _busy ? null : () => _run(action),
          child: Text(label),
        );

    final out = <Widget>[];
    switch (status) {
      case ReservationStatus.pending:
        if (isProvider) {
          out.addAll([
            filled('Accept request', () => ReservationActions.accept(context, r)),
            const SizedBox(height: 10),
            danger('Reject request', () => ReservationActions.reject(context, r)),
          ]);
        } else if (isReceiver) {
          out.addAll([
            info('Waiting for the provider to approve your request.'),
            danger('Cancel request', () => ReservationActions.cancel(context, r)),
          ]);
        }
      case ReservationStatus.accepted:
        if (isReceiver) {
          if (!r.receiverConfirmed) {
            out.addAll([
              filled('Confirm collection',
                  () => ReservationActions.confirmCollection(context, r)),
              const SizedBox(height: 10),
              danger('Cancel reservation',
                  () => ReservationActions.cancel(context, r)),
            ]);
          } else {
            out.add(info(
                'You confirmed collection. Waiting for the provider to confirm the handover.'));
          }
        } else if (isProvider) {
          if (r.receiverConfirmed) {
            out.add(filled('Confirm handover',
                () => ReservationActions.confirmHandover(context, r)));
          } else {
            out.addAll([
              info('Waiting for the receiver to confirm collection.'),
              danger('Cancel reservation',
                  () => ReservationActions.cancel(context, r)),
            ]);
          }
        }
      case ReservationStatus.completed:
        out.add(info('Pickup completed. Thank you for rescuing food!'));
      case ReservationStatus.expired:
        out.add(info('The pickup deadline passed without collection.'));
      case ReservationStatus.rejected:
        out.add(info('The provider declined this request.'));
      case ReservationStatus.cancelled:
        out.add(info('This reservation was cancelled.'));
    }
    return out;
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

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
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.label, this.done);

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: done ? AppColors.primary : AppColors.border,
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: done ? AppColors.slate : AppColors.neutral)),
        ],
      ),
    );
  }
}
