import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/bookings_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class ClientNotificationsPage extends StatefulWidget {
  const ClientNotificationsPage({super.key});

  @override
  State<ClientNotificationsPage> createState() =>
      _ClientNotificationsPageState();
}

class _ClientNotificationsPageState extends State<ClientNotificationsPage> {
  final BookingsService _bookingsService = BookingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: IconThemeData(color: AppColors.white),
        backgroundColor: AppColors.pagesAppBar(context),
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          // Mark all as read button
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _bookingsService.streamNotifications(),
            builder: (context, snapshot) {
              final hasUnread =
                  snapshot.hasData &&
                  snapshot.data!.any((notif) => notif['read'] == false);

              if (!hasUnread) return SizedBox.shrink();

              return TextButton(
                onPressed: () async {
                  await _bookingsService.markAllNotificationsAsRead();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('All notifications marked as read'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bookingsService.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] == true;
    final type = notification['type'] as String? ?? 'info';
    final timestamp = notification['createdAt'] as Timestamp?;

    // Get time ago
    String timeAgo = 'Just now';
    if (timestamp != null) {
      timeAgo = timeago.format(timestamp.toDate());
    }

    // Get icon and color based on notification type
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'booking_accepted':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'booking_declined':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'booking_created':
        icon = Icons.schedule;
        iconColor = Colors.blue;
        break;
      case 'job_started':
        icon = Icons.play_circle;
        iconColor = Colors.orange;
        break;
      case 'job_completed':
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case 'booking_cancelled':
        icon = Icons.close;
        iconColor = Colors.grey;
        break;
      case 'new_request':
        icon = Icons.notification_important;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = AppColors.primaryColor;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead
            ? AppColors.cardColor(context)
            : AppColors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? AppColors.borderColor(context)
              : AppColors.primaryColor.withValues(alpha: 0.2),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Mark as read
            if (!isRead) {
              await _bookingsService.markNotificationAsRead(notification['id']);
            }

            // Navigate to booking if applicable
            final bookingId = notification['bookingId'] as String?;
            if (bookingId != null) {
              // TODO: Navigate to booking details
              print('Navigate to booking: $bookingId');
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),

                SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        notification['title'] ?? 'Notification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isRead
                              ? FontWeight.w600
                              : FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),

                      SizedBox(height: 6),

                      // Message
                      Text(
                        notification['message'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryColor(context),
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 8),

                      // Time
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Unread indicator
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'ll see updates about your bookings here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
