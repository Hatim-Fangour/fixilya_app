import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/notifications/presentation/widgets/notification_card.dart';
import 'package:flutter/material.dart';

/// Notifications screen.
///
/// Displays a real-time list of notifications for the current user,
/// fetched from Firestore and ordered by creation time.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        appBar: _buildAppBar(context),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load notifications',
                    style: TextStyle(
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh, size: 18),
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

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final notifId = docs[i].id;
              return NotificationCard(
                id: notifId,
                title: data['title'] as String? ?? 'Notification',
                body: data['body'] as String? ?? '',
                type: data['type'] as String? ?? 'general',
                isRead: data['isRead'] as bool? ?? false,
                createdAt: data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now(),
                onTap: () => _markAsRead(notifId),
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.backgroundColor(context),
      elevation: 0,
      title: Text(
        'Notifications',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: AppColors.textPrimaryColor(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _markAllAsRead(),
          child: Text(
            'Mark all read',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 72,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsRead(String notifId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notifId)
          .update({'isRead': true});
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}
