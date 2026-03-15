import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/models/booking_model.dart';
import 'package:fixilya_app/features/booking/presentation/controllers/booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// Booking details screen.
///
/// Displays all information about a specific booking and provides
/// action buttons depending on the booking status.
class BookingDetailsScreen extends StatelessWidget {
  final BookingModel booking;

  const BookingDetailsScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimaryColor(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Booking Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusBanner(context),
          const SizedBox(height: 16),
          _buildServiceCard(context),
          const SizedBox(height: 16),
          _buildScheduleCard(context),
          const SizedBox(height: 16),
          _buildLocationCard(context),
          const SizedBox(height: 16),
          _buildPaymentCard(context),
          if (booking.clientNotes != null &&
              booking.clientNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(context),
          ],
          if (booking.cancellationReason != null &&
              booking.cancellationReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCancellationCard(context),
          ],
          const SizedBox(height: 24),
          if (booking.canBeCancelled) _buildCancelButton(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Status banner ───────────────────────────────────────────────────────

  Widget _buildStatusBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _statusColor(booking.status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColor(booking.status).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon(booking.status),
            color: _statusColor(booking.status),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _statusColor(booking.status),
                  ),
                ),
                Text(
                  'Booking #${booking.id.substring(0, booking.id.length.clamp(0, 8))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Service card ────────────────────────────────────────────────────────

  Widget _buildServiceCard(BuildContext context) {
    return _card(
      context,
      title: 'Service',
      icon: FontAwesomeIcons.wrench,
      children: [
        _detailRow(context, 'Type', booking.serviceType),
        if (booking.serviceDescription != null)
          _detailRow(context, 'Description', booking.serviceDescription!),
        _detailRow(context, 'Duration', '${booking.estimatedDuration} min'),
      ],
    );
  }

  // ─── Schedule card ───────────────────────────────────────────────────────

  Widget _buildScheduleCard(BuildContext context) {
    return _card(
      context,
      title: 'Schedule',
      icon: FontAwesomeIcons.calendarDays,
      children: [
        _detailRow(context, 'Date', _formatDate(booking.scheduledDate)),
        _detailRow(context, 'Time', booking.scheduledTime),
      ],
    );
  }

  // ─── Location card ───────────────────────────────────────────────────────

  Widget _buildLocationCard(BuildContext context) {
    return _card(
      context,
      title: 'Location',
      icon: FontAwesomeIcons.locationDot,
      children: [
        _detailRow(context, 'Area', booking.location),
        if (booking.address != null)
          _detailRow(context, 'Address', booking.address!),
      ],
    );
  }

  // ─── Payment card ────────────────────────────────────────────────────────

  Widget _buildPaymentCard(BuildContext context) {
    return _card(
      context,
      title: 'Payment',
      icon: FontAwesomeIcons.moneyBill,
      children: [
        _detailRow(
          context,
          'Hourly Rate',
          '${booking.hourlyRate.toStringAsFixed(0)} DH',
        ),
        if (booking.estimatedCost != null)
          _detailRow(
            context,
            'Estimated Cost',
            '${booking.estimatedCost!.toStringAsFixed(0)} DH',
          ),
        if (booking.totalCost != null)
          _detailRow(
            context,
            'Total',
            '${booking.totalCost!.toStringAsFixed(0)} DH',
            isBold: true,
          ),
        _detailRow(
          context,
          'Payment Status',
          booking.paymentStatus.name.capitalizeFirst ?? booking.paymentStatus.name,
        ),
      ],
    );
  }

  // ─── Notes card ──────────────────────────────────────────────────────────

  Widget _buildNotesCard(BuildContext context) {
    return _card(
      context,
      title: 'Notes',
      icon: FontAwesomeIcons.noteSticky,
      children: [
        Text(
          booking.clientNotes!,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimaryColor(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Cancellation card ───────────────────────────────────────────────────

  Widget _buildCancellationCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.circleXmark,
                  size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Cancellation Reason',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.cancellationReason!,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimaryColor(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cancel button ───────────────────────────────────────────────────────

  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _showCancelDialog(context),
        icon: const Icon(Icons.cancel_outlined, size: 20),
        label: const Text('Cancel Booking'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final controller = Get.find<BookingController>();
              controller.cancelBooking(
                booking.id,
                reason: reasonController.text.trim(),
              );
              Navigator.of(context).pop(); // Return to list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Widget _card(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 16, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ),
        ],
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

  IconData _statusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.hourglass_top_rounded;
      case BookingStatus.confirmed:
        return Icons.check_circle_outline;
      case BookingStatus.inProgress:
        return Icons.engineering_rounded;
      case BookingStatus.completed:
        return Icons.task_alt_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_outlined;
      case BookingStatus.refunded:
        return Icons.replay_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
