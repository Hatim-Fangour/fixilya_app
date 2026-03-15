import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

/// A notification card widget.
///
/// Displays the notification title, body, timestamp, and read/unread state.
/// The icon and color are determined by the notification type.
class NotificationCard extends StatelessWidget {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.cardColor(context)
              : AppColors.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? AppColors.borderColor(context)
                : AppColors.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(_typeIcon, size: 20, color: _typeColor),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimaryColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeago.format(createdAt, allowFromNow: true),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _typeColor {
    switch (type) {
      case 'booking':
        return AppColors.primaryColor;
      case 'booking_confirmed':
        return AppColors.success;
      case 'booking_cancelled':
        return AppColors.error;
      case 'chat':
        return AppColors.info;
      case 'call':
        return AppColors.accentOrange;
      case 'review':
        return AppColors.reviews;
      case 'payment':
        return AppColors.success;
      case 'system':
        return AppColors.grey600;
      default:
        return AppColors.primaryColor;
    }
  }

  IconData get _typeIcon {
    switch (type) {
      case 'booking':
        return Icons.calendar_today_rounded;
      case 'booking_confirmed':
        return Icons.check_circle_outline_rounded;
      case 'booking_cancelled':
        return Icons.cancel_outlined;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'call':
        return Icons.call_rounded;
      case 'review':
        return Icons.star_outline_rounded;
      case 'payment':
        return Icons.payment_rounded;
      case 'system':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}
