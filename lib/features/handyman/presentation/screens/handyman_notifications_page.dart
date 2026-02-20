// UPDATED HANDYMAN NOTIFICATIONS PAGE WITH FIREBASE STREAMS
// Replace your existing handyman_notifications_page.dart with this

import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/bookings_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HandymanNotificationsPage extends StatefulWidget {
  const HandymanNotificationsPage({super.key});

  @override
  State<HandymanNotificationsPage> createState() =>
      _HandymanNotificationsPageState();
}

class _HandymanNotificationsPageState extends State<HandymanNotificationsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  // ✅ ADD BOOKINGS SERVICE
  final _bookingsService = BookingsService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_request':
        return FontAwesomeIcons.bellConcierge;
      case 'payment':
        return FontAwesomeIcons.wallet;
      case 'reminder':
        return FontAwesomeIcons.clock;
      case 'review':
        return FontAwesomeIcons.star;
      case 'confirmed':
        return FontAwesomeIcons.circleCheck;
      case 'cancelled':
        return FontAwesomeIcons.circleXmark;
      case 'system':
        return FontAwesomeIcons.circleInfo;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_request':
        return Colors.orange;
      case 'payment':
        return Colors.green;
      case 'reminder':
        return Colors.blue;
      case 'review':
        return Colors.amber;
      case 'confirmed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      case 'system':
        return Colors.purple;
      default:
        return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // ✅ UPDATED: Premium App Bar with Real-time Unread Count
          _buildPremiumAppBar(),

          // ✅ UPDATED: Notifications List with StreamBuilder
          _buildNotificationsList(),
        ],
      ),
    );
  }

  // ============================================
  // ✅ UPDATED APP BAR WITH REAL-TIME COUNT
  // ============================================

  Widget _buildPremiumAppBar() {
    return StreamBuilder<int>(
      stream: _bookingsService.streamUnreadNotificationsCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.pagesAppBar(context),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: AppColors.appHeaderGradientThemed(context),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 60, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.bell,
                              color: AppColors.primaryColor,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '$unreadCount unread',
                                  style: TextStyle(
                                    color: AppColors.white.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (unreadCount > 0)
              TextButton(
                onPressed: () async {
                  await _bookingsService.markAllNotificationsAsRead();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All notifications marked as read'),
                      backgroundColor: AppColors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ============================================
  // ✅ UPDATED NOTIFICATIONS LIST WITH STREAM
  // ============================================

  Widget _buildNotificationsList() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _animationController,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _bookingsService.streamNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryColor,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                children: notifications
                    .map((notification) => _buildNotificationCard(notification))
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================
  // NOTIFICATION CARD
  // ============================================

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] ?? false;
    final type = notification['type'] ?? 'system';
    final color = _getNotificationColor(type);
    final bookingId = notification['bookingId'];

    // Calculate time ago
    String timeAgo = 'Just now';
    if (notification['createdAt'] != null) {
      final timestamp = (notification['createdAt'] as Timestamp).toDate();
      final difference = DateTime.now().difference(timestamp);

      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} hours ago';
      } else {
        timeAgo = '${difference.inDays} days ago';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead
            ? AppColors.surfaceColor(context)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? AppColors.borderColor(context)
              : color.withValues(alpha: 0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: .04),
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

            // Handle notification action based on type
            if (type == 'new_request' && bookingId != null) {
              _showRequestDetailsDialog(notification);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FaIcon(
                        _getNotificationIcon(type),
                        color: color,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimaryColor(context),
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            notification['message'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryColor(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textDisabledColor(context),
                              ),
                              SizedBox(width: 4),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDisabledColor(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Show action buttons for new requests
                if (type == 'new_request' && bookingId != null) ...[
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.dividerColor(context)),
                  SizedBox(height: 12),
                  _buildNotificationActions(notification),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // NOTIFICATION ACTIONS (For New Requests)
  // ============================================

  Widget _buildNotificationActions(Map<String, dynamic> notification) {
    final bookingId = notification['bookingId'];

    // Check booking status in real-time
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final bookingData = snapshot.data?.data() as Map<String, dynamic>?;
        final status = bookingData?['status'] ?? 'pending';

        // Show status badge if already handled
        if (status == 'confirmed') {
          return _buildStatusBadge(
            'Accepted',
            Colors.green,
            Icons.check_circle,
          );
        } else if (status == 'declined') {
          return _buildStatusBadge('Declined', Colors.red, Icons.cancel);
        }

        // Show action buttons if still pending
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _declineRequest(bookingId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('Decline'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => _acceptRequest(bookingId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Accept',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // EMPTY & ERROR STATES
  // ============================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You\'ll see booking requests and updates here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ACTION HANDLERS
  // ============================================

  Future<void> _acceptRequest(String bookingId) async {
    final success = await _bookingsService.acceptBooking(bookingId);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Request accepted!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineRequest(String bookingId) async {
    final success = await _bookingsService.declineBooking(bookingId);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.close_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Request declined'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showRequestDetailsDialog(Map<String, dynamic> notification) {
    final bookingId = notification['bookingId'];

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final bookingData = snapshot.data?.data() as Map<String, dynamic>?;

          if (bookingData == null) {
            return AlertDialog(
              title: Text('Booking Not Found'),
              content: Text('This booking no longer exists.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text('Booking Details', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  Icons.person,
                  'Client',
                  bookingData['clientName'] ?? 'Unknown',
                ),
                SizedBox(height: 12),
                _buildDetailRow(
                  Icons.build,
                  'Service',
                  bookingData['service'] ?? 'Unknown',
                ),
                SizedBox(height: 12),
                _buildDetailRow(
                  Icons.location_on,
                  'Location',
                  bookingData['location'] ?? 'Unknown',
                ),
                SizedBox(height: 12),
                _buildDetailRow(
                  Icons.attach_money,
                  'Amount',
                  '${bookingData['amount']?.toStringAsFixed(0) ?? '0'} DH',
                  isHighlight: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
              if (bookingData['status'] == 'pending') ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _declineRequest(bookingId);
                  },
                  child: Text('Decline', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _acceptRequest(bookingId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  child: Text('Accept'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight
                  ? Colors.green
                  : AppColors.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}
