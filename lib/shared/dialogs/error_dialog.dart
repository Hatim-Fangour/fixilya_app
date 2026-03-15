import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// A simple, themed error dialog.
///
/// Usage:
/// ```dart
/// showErrorDialog(context, title: 'Oops', message: 'Something went wrong.');
/// ```
Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Error',
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.errorColor(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: AppColors.errorColor(context),
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
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
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
          ),
          child: Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
