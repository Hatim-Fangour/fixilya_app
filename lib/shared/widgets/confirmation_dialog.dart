import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Shows a confirmation dialog and returns `true` if the user confirmed,
/// `false` or `null` if cancelled.
///
/// Usage:
/// ```dart
/// final confirmed = await showConfirmationDialog(
///   context,
///   title: 'Delete Item',
///   message: 'Are you sure you want to delete this?',
///   confirmLabel: 'Delete',
///   isDestructive: true,
/// );
/// if (confirmed == true) { /* proceed */ }
/// ```
Future<bool?> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDestructive
                      ? AppColors.errorColor(context)
                      : AppColors.primaryColor)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDestructive ? Icons.warning_amber_rounded : Icons.help_outline,
              color: isDestructive
                  ? AppColors.errorColor(context)
                  : AppColors.primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondaryColor(context),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelLabel,
            style: TextStyle(
              color: AppColors.textSecondaryColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive
                ? AppColors.errorColor(context)
                : AppColors.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            confirmLabel,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
