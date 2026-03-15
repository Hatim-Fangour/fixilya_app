import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Reusable date/time picker widget for booking forms.
///
/// Displays the selected date and time in a tappable container that
/// opens the platform date or time picker dialog.
class DateTimePicker extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const DateTimePicker({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      onTimeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PickerButton(
            icon: Icons.calendar_today,
            label:
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            onTap: () => _pickDate(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PickerButton(
            icon: Icons.access_time,
            label: selectedTime.format(context),
            onTap: () => _pickTime(context),
          ),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFillColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimaryColor(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
