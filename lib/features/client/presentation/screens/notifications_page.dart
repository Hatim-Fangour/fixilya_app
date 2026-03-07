import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/notification_api_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class ClientNotificationsPage extends StatefulWidget {
  const ClientNotificationsPage({super.key});

  @override
  State<ClientNotificationsPage> createState() =>
      _ClientNotificationsPageState();
}

class _ClientNotificationsPageState extends State<ClientNotificationsPage> {
  final NotificationApiService _notificationApi = NotificationApiService();

  late final Stream<List<Map<String, dynamic>>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList());
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationApi.markAsRead(notificationId);
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationApi.markAllAsRead();
    } catch (e) {
      debugPrint('markAllAsRead error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Timestamp helper
  // SSE service parses ISO strings → DateTime objects
  // but we guard against raw strings too
  // ─────────────────────────────────────────────

  String _formatTime(dynamic value) {
    if (value == null) return 'Just now';

    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value);
    } else if (value is Timestamp) {
      dt = value
          .toDate(); // legacy Firestore Timestamp (shouldn't happen via SSE)
    }

    return dt != null ? timeago.format(dt) : 'Just now';
  }

  // ─────────────────────────────────────────────
  // Icon / colour by notification type
  // ─────────────────────────────────────────────

  ({IconData icon, Color color}) _typeStyle(String? type) {
    return switch (type) {
      'booking_accepted' => (icon: Icons.check_circle, color: Colors.green),
      'booking_declined' => (icon: Icons.cancel, color: Colors.red),
      'booking_created' => (icon: Icons.schedule, color: Colors.blue),
      'booking_confirmed' => (icon: Icons.check_circle, color: Colors.green),
      'job_started' => (icon: Icons.play_circle, color: Colors.orange),
      'job_completed' => (
        icon: Icons.check_circle_outline,
        color: Colors.green,
      ),
      'booking_cancelled' => (icon: Icons.close, color: Colors.grey),
      'new_request' => (
        icon: Icons.notification_important,
        color: Colors.orange,
      ),
      _ => (icon: Icons.notifications, color: AppColors.primaryColor),
    };
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: IconThemeData(color: AppColors.white),
        backgroundColor: AppColors.pagesAppBar(context),
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [_buildMarkAllButton()],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            );
          }

          // ── Error ────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) => _buildCard(notifications[index]),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // "Mark all read" — only shown when unread exist
  // ─────────────────────────────────────────────

  Widget _buildMarkAllButton() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final hasUnread =
            snapshot.hasData && snapshot.data!.any((n) => n['read'] == false);

        if (!hasUnread) return const SizedBox.shrink();

        return TextButton(
          onPressed: () async {
            await _markAllAsRead();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All notifications marked as read'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
          child: const Text(
            'Mark all read',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Notification card
  // ─────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] == true;
    final style = _typeStyle(notification['type'] as String?);
    final timeText = _formatTime(notification['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (!isRead) await _markAsRead(notification['id'] as String);
            final bookingId = notification['bookingId'] as String?;
            if (bookingId != null) {
              debugPrint('Navigate to booking: $bookingId');
              // TODO: AppRoutes.toBookingDetails(bookingId)
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon ──────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 24),
                ),

                const SizedBox(width: 14),

                // ── Content ───────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] as String? ?? 'Notification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isRead
                              ? FontWeight.w600
                              : FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['message'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryColor(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Unread dot ────────────────
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

  // ─────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll see updates about your bookings here",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
