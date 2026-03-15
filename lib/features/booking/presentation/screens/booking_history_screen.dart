import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/models/booking_model.dart';
import 'package:fixilya_app/features/booking/presentation/controllers/booking_controller.dart';
import 'package:fixilya_app/features/booking/presentation/screens/booking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// Booking history screen.
///
/// Displays all bookings for the current user with tabs for
/// upcoming and past bookings.
class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure the controller is available
    final controller = Get.find<BookingController>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor(context),
          elevation: 0,
          title: Text(
            'My Bookings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.textSecondaryColor(context),
            indicatorColor: AppColors.primaryColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: AppColors.textPrimaryColor(context),
              ),
              onPressed: () => controller.fetchBookings(),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.bookings.isEmpty) {
            return _buildErrorState(context, controller);
          }

          return TabBarView(
            children: [
              _buildBookingList(context, controller.activeBookings),
              _buildBookingList(context, controller.upcomingBookings),
              _buildBookingList(context, controller.pastBookings),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBookingList(BuildContext context, List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => Get.find<BookingController>().fetchBookings(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _BookingCard(booking: bookings[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No bookings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your bookings will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, BookingController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            controller.errorMessage.value,
            style: TextStyle(color: AppColors.textSecondaryColor(context)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => controller.fetchBookings(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking card ──────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingDetailsScreen(booking: booking),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: service type & status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      FaIcon(
                        _serviceIcon(booking.serviceType),
                        size: 16,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.serviceType,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimaryColor(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(context, booking.status),
              ],
            ),
            const SizedBox(height: 12),

            // Date and time
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textSecondaryColor(context)),
                const SizedBox(width: 6),
                Text(
                  _formatDate(booking.scheduledDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time,
                    size: 14, color: AppColors.textSecondaryColor(context)),
                const SizedBox(width: 6),
                Text(
                  booking.scheduledTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Location
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondaryColor(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.location,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Price
            if (booking.estimatedCost != null ||
                booking.totalCost != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(booking.totalCost ?? booking.estimatedCost)?.toStringAsFixed(0)} DH',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, BookingStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name.capitalizeFirst ?? status.name,
        style: TextStyle(
          fontSize: 11,
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
