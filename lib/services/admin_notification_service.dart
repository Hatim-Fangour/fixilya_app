import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Notify admin of new handyman registration
  Future<void> notifyAdminOfNewHandyman({
    required String handymanId,
    required String handymanName,
    required String email,
    required String phone,
    required bool profileCompleted,
  }) async {
    try {
      if (kDebugMode) debugPrint('📧 Notifying admin of new handyman...');

      await _firestore.collection('adminNotifications').add({
        'type': 'new_handyman',
        'handymanId': handymanId,
        'handymanName': handymanName,
        'email': email,
        'phone': phone,
        'profileCompleted': profileCompleted,
        'title': profileCompleted
            ? '🎉 New Handyman - Profile Completed'
            : '📝 New Handyman - Profile Incomplete',
        'message': profileCompleted
            ? '$handymanName has registered and completed their profile. Review and approve their application.'
            : '$handymanName has registered but skipped profile setup. They may complete it later.',
        'priority': profileCompleted ? 'high' : 'medium',
        'read': false,
        'actionRequired': !profileCompleted,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Admin notification created');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating admin notification: $e');
      // Don't throw - notification failure shouldn't block registration
    }
  }

  /// Check if this is a first-time registration
  Future<bool> isFirstTimeUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      // If document doesn't exist or was just created, it's a new user
      if (!userDoc.exists) return true;

      final data = userDoc.data();
      if (data == null) return true;

      // Check if createdAt is recent (within last minute)
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return true;

      final createdDate = createdAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(createdDate);

      // If created within last 2 minutes, consider it a new registration
      return difference.inMinutes < 2;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking if first-time user: $e');
      return false; // Assume not first time on error
    }
  }
}
