import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/models/booking_model.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A compact card displaying a booking summary.
///
/// Used in booking lists to show service type, status, date, and cost.
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onTap;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLightColor(context),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Service icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: FaIcon(
                  _serviceIcon(booking.serviceType),
                  size: 20,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.serviceType,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimaryColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12,
                          color: AppColors.textSecondaryColor(context)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(booking.scheduledDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time,
                          size: 12,
                          color: AppColors.textSecondaryColor(context)),
                      const SizedBox(width: 4),
                      Text(
                        booking.scheduledTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status & price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusChip(context),
                if (booking.estimatedCost != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${booking.estimatedCost!.toStringAsFixed(0)} DH',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final color = _statusColor(booking.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        booking.statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.confirmed:
        return AppColors.info;
      case BookingStatus.inProgress:
        return AppColors.primaryColor;
      case BookingStatus.completed:
        return AppColors.success;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.refunded:
        return AppColors.grey600;
    }
  }

  IconData _serviceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'plumbing':
        return FontAwesomeIcons.faucet;
      case 'electrical work':
        return FontAwesomeIcons.bolt;
      case 'carpentry':
        return FontAwesomeIcons.hammer;
      case 'painting':
        return FontAwesomeIcons.paintRoller;
      case 'cleaning':
        return FontAwesomeIcons.broom;
      case 'ac repair':
        return FontAwesomeIcons.snowflake;
      case 'gardening':
        return FontAwesomeIcons.seedling;
      case 'appliance repair':
        return FontAwesomeIcons.plug;
      default:
        return FontAwesomeIcons.wrench;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}
