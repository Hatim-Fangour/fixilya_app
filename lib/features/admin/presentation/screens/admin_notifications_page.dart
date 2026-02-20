// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  // Luxury Colors
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0A1929);
  static const Color charcoal = Color(0xFF1A2332);
  static const Color softWhite = Color(0xFFFAFAFA);
  static const Color accentRed = Color(0xFFE63946);
  static const Color accentGreen = Color(0xFF06D6A0);
  static const Color accentBlue = Color(0xFF118AB2);
  static const Color accentOrange = Color(0xFFFFB703);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'all'; // all, pending, complaints, activity

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildNotificationsList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: charcoal,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: softWhite),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryGold.withValues(alpha:0.2),
                  primaryGold.withValues(alpha:0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_active,
              color: primaryGold,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Notifications',
            style: TextStyle(
              color: softWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.done_all, color: softWhite),
          onPressed: _markAllAsRead,
          tooltip: 'Mark all as read',
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all', Icons.notifications),
            SizedBox(width: 12),
            _buildFilterChip(
              'Pending Approvals',
              'pending',
              Icons.pending_actions,
            ),
            SizedBox(width: 12),
            _buildFilterChip('Complaints', 'complaints', Icons.report),
            SizedBox(width: 12),
            _buildFilterChip('Activity', 'activity', Icons.history),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [primaryGold, Color(0xFFFFD700)])
              : null,
          color: isSelected ? null : charcoal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : primaryGold.withValues(alpha:0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? deepNavy : softWhite.withValues(alpha:0.7),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? deepNavy : softWhite.withValues(alpha:0.7),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final notifications = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(20),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification =
                notifications[index].data() as Map<String, dynamic>;
            final notificationId = notifications[index].id;
            return _buildNotificationCard(notification, notificationId);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getNotificationsStream() {
    Query query = _firestore.collection('admin_notifications');

    switch (_selectedFilter) {
      case 'pending':
        query = query.where('type', isEqualTo: 'pending_approval');
        break;
      case 'complaints':
        query = query.where('type', isEqualTo: 'complaint');
        break;
      case 'activity':
        query = query.where('type', isEqualTo: 'activity');
        break;
      default:
        // Show all
        break;
    }

    return query.orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    String notificationId,
  ) {
    final type = notification['type'] ?? 'activity';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final isRead = notification['isRead'] ?? false;
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate();

    Color typeColor;
    IconData typeIcon;

    switch (type) {
      case 'pending_approval':
        typeColor = accentOrange;
        typeIcon = Icons.pending_actions;
        break;
      case 'complaint':
        typeColor = accentRed;
        typeIcon = Icons.report_problem;
        break;
      case 'new_handyman':
        typeColor = accentBlue;
        typeIcon = Icons.person_add;
        break;
      case 'new_booking':
        typeColor = accentGreen;
        typeIcon = Icons.work;
        break;
      default:
        typeColor = primaryGold;
        typeIcon = Icons.info;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRead
              ? [charcoal.withValues(alpha:0.5), deepNavy.withValues(alpha:0.5)]
              : [charcoal, deepNavy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.transparent : typeColor.withValues(alpha:0.3),
          width: isRead ? 0 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification, notificationId),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [typeColor, typeColor.withValues(alpha:0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: Colors.white, size: 22),
                ),
                SizedBox(width: 14),

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
                                color: softWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: typeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: softWhite.withValues(alpha:0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (createdAt != null) ...[
                        SizedBox(height: 8),
                        Text(
                          timeago.format(createdAt),
                          style: TextStyle(
                            color: softWhite.withValues(alpha:0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action arrow
                Icon(
                  Icons.chevron_right,
                  color: softWhite.withValues(alpha:0.3),
                  size: 20,
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
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryGold.withValues(alpha:0.2),
                  primaryGold.withValues(alpha:0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              color: primaryGold.withValues(alpha:0.5),
              size: 60,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Notifications',
            style: TextStyle(
              color: softWhite,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(color: softWhite.withValues(alpha:0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: accentRed, size: 60),
          SizedBox(height: 16),
          Text(
            'Error Loading Notifications',
            style: TextStyle(
              color: softWhite,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    Map<String, dynamic> notification,
    String notificationId,
  ) async {
    // Mark as read
    await _markAsRead(notificationId);

    final targetType = notification['targetType'];

    // Navigate based on notification type
    switch (targetType) {
      case 'handyman':
        // Navigate to handyman profile or approvals page
        Get.back(); // Go back to dashboard
        // You can navigate to specific handyman profile here
        break;
      case 'complaint':
        // Navigate to complaints page
        break;
      case 'booking':
        // Navigate to booking details
        break;
      default:
        break;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('admin_notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final unreadNotifications = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      Get.snackbar(
        '✅ Success',
        'All notifications marked as read',
        backgroundColor: accentGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
    }
  }
}
