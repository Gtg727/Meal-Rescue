import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/app_snack.dart';
import '../../models/reservation_model.dart';
import '../../providers/reservation_provider.dart';

/// User actions on a reservation. Each one asks for confirmation where it is
/// hard to undo, calls the provider, and reports the server's answer. A
/// success message is only shown after the server accepted the change.
class ReservationActions {
  static Future<bool> _run(
    BuildContext context,
    Future<void> Function(ReservationProvider p) action,
    String successMessage,
  ) async {
    final provider = context.read<ReservationProvider>();
    try {
      await action(provider);
      if (context.mounted) showSnack(context, successMessage);
      return true;
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
      return false;
    }
  }

  static Future<bool> accept(BuildContext context, ReservationModel r) =>
      _run(context, (p) => p.accept(r.id), 'Reservation accepted');

  static Future<bool> reject(BuildContext context, ReservationModel r) async {
    final ok = await confirmDialog(
      context,
      title: 'Reject request?',
      message:
          'Reject the request for ${r.requestedPortions} portion(s) from ${r.receiverLabel}?',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return _run(context, (p) => p.reject(r.id), 'Request rejected');
  }

  static Future<bool> cancel(BuildContext context, ReservationModel r) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel reservation?',
      message: 'The portions will be released for other receivers.',
      confirmLabel: 'Cancel reservation',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return _run(context, (p) => p.cancel(r.id), 'Reservation cancelled');
  }

  static Future<bool> confirmCollection(
      BuildContext context, ReservationModel r) async {
    final ok = await confirmDialog(
      context,
      title: 'Confirm collection',
      message:
          'Confirm that you collected the food from ${r.providerName}. The provider then confirms the handover to complete the pickup.',
      confirmLabel: 'I collected it',
    );
    if (!ok || !context.mounted) return false;
    return _run(context, (p) => p.confirmCollection(r.id),
        'Collection confirmed. Waiting for the provider.');
  }

  static Future<bool> confirmHandover(
      BuildContext context, ReservationModel r) async {
    final collected = await showDialog<int>(
      context: context,
      builder: (_) => _HandoverDialog(requested: r.requestedPortions),
    );
    if (collected == null || !context.mounted) return false;
    return _run(
      context,
      (p) => p.confirmHandover(r.id, collectedPortions: collected),
      'Pickup completed',
    );
  }
}

class _HandoverDialog extends StatefulWidget {
  const _HandoverDialog({required this.requested});

  final int requested;

  @override
  State<_HandoverDialog> createState() => _HandoverDialogState();
}

class _HandoverDialogState extends State<_HandoverDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.requested}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 1 || n > widget.requested) {
      setState(() => _error = 'Enter a number from 1 to ${widget.requested}');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm handover'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'How many portions were actually handed over? Impact is counted from this number.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: AppTheme.inputDecoration(
              'Portions handed over',
              hint: 'Up to ${widget.requested}',
            ).copyWith(errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Complete pickup')),
      ],
    );
  }
}
