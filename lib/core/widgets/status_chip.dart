import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Colour-coded status pill: green available, amber pending, blue accepted
/// or reserved, red rejected/expired, neutral completed/cancelled/draft.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  static Color colorFor(String status) {
    switch (status) {
      case 'available':
        return AppColors.primary;
      case 'pending':
        return AppColors.amber;
      case 'accepted':
      case 'reserved':
        return AppColors.blue;
      case 'rejected':
      case 'expired':
        return AppColors.red;
      default:
        return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        capitalize(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
