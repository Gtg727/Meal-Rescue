import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/reservation_model.dart';
import '../../routes/app_router.dart';
import 'reservation_actions.dart';
import 'reservation_details_screen.dart';

/// Summary card for one reservation. [viewerRole] decides which party's
/// name is shown and whether inline provider actions appear.
class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.viewerRole,
    this.showActions = false,
  });

  final ReservationModel reservation;
  final String viewerRole;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final status = r.effectiveStatus;
    final isProvider = viewerRole == AppRoles.provider;

    final String party;
    if (viewerRole == AppRoles.admin) {
      party = '${r.providerName} → ${r.receiverLabel}';
    } else if (isProvider) {
      party = 'Requested by ${r.receiverLabel}';
    } else {
      party = 'From ${r.providerName}';
    }

    return AppCard(
      onTap: () => AppRouter.push(
          context, ReservationDetailsScreen(reservationId: r.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.donationTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(party, style: const TextStyle(color: AppColors.neutral)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.restaurant, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text('${r.requestedPortions} portion(s)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.schedule, size: 16, color: AppColors.amber),
              const SizedBox(width: 4),
              Text(
                r.isActiveEffective
                    ? timeLeft(r.pickupDeadline)
                    : formatDateTime(r.pickupDeadline),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          if (showActions &&
              isProvider &&
              status == ReservationStatus.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                    ),
                    onPressed: () => ReservationActions.reject(context, r),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42)),
                    onPressed: () => ReservationActions.accept(context, r),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
