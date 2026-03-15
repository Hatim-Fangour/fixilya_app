import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// A non-dismissible loading dialog with an optional message.
///
/// Usage:
/// ```dart
/// showLoadingDialog(context, message: 'Saving...');
/// // When done:
/// Navigator.pop(context);
/// ```
Future<void> showLoadingDialog(
  BuildContext context, {
  String? message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
            if (message != null) ...[
              SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
            ],
            SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
