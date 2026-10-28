import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_snack.dart';
import '../../models/donation_model.dart';
import '../../providers/moderation_provider.dart';

/// Lets any signed-in user report an unsafe or misleading listing.
Future<void> showReportDialog(BuildContext context, DonationModel donation) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReportDialog(donation: donation),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.donation});

  final DonationModel donation;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _details = TextEditingController();
  String _reason = kReportReasons.first;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<ModerationProvider>().submitReport(
            donation: widget.donation,
            reason: _reason,
            details: _details.text,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks. An admin will review this listing.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report listing'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.donation.title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppDropdown<String>(
              label: 'Reason',
              value: _reason,
              items: [
                for (final r in kReportReasons)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 500,
              decoration: AppTheme.inputDecoration('Details (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Submit report'),
        ),
      ],
    );
  }
}
