import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Form field that picks a date and then a time, with validation support.
class DateTimeFormField extends FormField<DateTime> {
  DateTimeFormField({
    super.key,
    required String label,
    required DateTime? initialValue,
    required ValueChanged<DateTime?> onChanged,
    super.validator,
    DateTime? firstDate,
    DateTime? lastDate,
    IconData icon = Icons.event,
  }) : super(
          initialValue: initialValue,
          builder: (state) {
            Future<void> pick() async {
              final ctx = state.context;
              final now = DateTime.now();
              final first = firstDate ?? now.subtract(const Duration(days: 7));
              final last = lastDate ?? now.add(const Duration(days: 365));
              var base = state.value ?? now;
              if (base.isBefore(first)) base = first;
              if (base.isAfter(last)) base = last;

              final date = await showDatePicker(
                context: ctx,
                initialDate: base,
                firstDate: DateTime(first.year, first.month, first.day),
                lastDate: last,
              );
              if (date == null || !ctx.mounted) return;
              final time = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(base),
              );
              if (time == null) return;
              final picked = DateTime(
                  date.year, date.month, date.day, time.hour, time.minute);
              state.didChange(picked);
              onChanged(picked);
            }

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: pick,
              child: InputDecorator(
                decoration: AppTheme.inputDecoration(label, icon: icon)
                    .copyWith(errorText: state.errorText),
                child: Text(
                  state.value == null
                      ? 'Select date & time'
                      : formatDateTime(state.value!),
                  style: TextStyle(
                    color: state.value == null
                        ? AppColors.neutral
                        : AppColors.slate,
                  ),
                ),
              ),
            );
          },
        );
}
