import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// ✨ Complete Admin Data Service with Firebase Integration
/// Handles all admin operations with proper error handling and logging
class AdminDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================
  // ACCESS CONTROL
  // ============================================

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      return adminDoc.exists && (adminDoc.data()?['isAdmin'] == true);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// ✅ NEW: Stream admin status (real-time)
  Stream<bool> streamAdminStatus() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('admins')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists && (doc.data()?['isAdmin'] == true));
  }

  /// ✅ NEW: Check if a specific user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      final adminDoc = await _firestore.collection('admins').doc(userId).get();

      return adminDoc.exists && (adminDoc.data()?['isAdmin'] == true);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking user admin status: $e');
      return false;
    }
  }

  /// ✅ NEW: Make user admin
  Future<bool> makeUserAdmin({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) debugPrint('❌ No current user');
        return false;
      }

      // Check if current user is admin
      final isCurrentUserAdmin = await isAdmin();
      if (!isCurrentUserAdmin) {
        if (kDebugMode) debugPrint('❌ Current user is not admin');
        return false;
      }

      await _firestore.collection('admins').doc(userId).set({
        'isAdmin': true,
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
        'permissions': [
          'approve_handymen',
          'suspend_users',
          'view_analytics',
          'manage_bookings',
          'manage_admins',
        ],
      });

      // Log the action
      await _logAdminAction(
        action: 'make_admin',
        targetType: 'user',
        targetId: userId,
        details: {'email': email, 'name': name},
      );

      if (kDebugMode) debugPrint('✅ User made admin: $userId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error making user admin: $e');
      return false;
    }
  }

  /// ✅ NEW: Remove admin privileges
  Future<bool> removeAdmin(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) debugPrint('❌ No current user');
        return false;
      }

      // Check if current user is admin
      final isCurrentUserAdmin = await isAdmin();
      if (!isCurrentUserAdmin) {
        if (kDebugMode) debugPrint('❌ Current user is not admin');
        return false;
      }

      // Prevent self-removal
      if (userId == currentUser.uid) {
        if (kDebugMode) debugPrint('❌ Cannot remove own admin privileges');
        return false;
      }

      await _firestore.collection('admins').doc(userId).delete();

      // Log the action
      await _logAdminAction(
        action: 'remove_admin',
        targetType: 'user',
        targetId: userId,
      );

      if (kDebugMode) debugPrint('✅ Admin removed: $userId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error removing admin: $e');
      return false;
    }
  }

  /// ✅ NEW: Get all admins
  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    try {
      final snapshot = await _firestore
          .collection('admins')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting admins: $e');
      return [];
    }
  }

  /// Create admin user (only for initial setup)
  Future<bool> createAdmin(
    String userId, {
    required String email,
    required String name,
  }) async {
    try {
      await _firestore.collection('admins').doc(userId).set({
        'isAdmin': true,
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': [
          'approve_handymen',
          'suspend_users',
          'view_analytics',
          'manage_bookings',
        ],
      });

      if (kDebugMode) debugPrint('✅ Admin created: $userId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating admin: $e');
      return false;
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Get comprehensive app statistics
  Future<Map<String, dynamic>> getAppStatistics() async {
    try {
      final currentUserId = _auth.currentUser?.uid;

      // Execute queries in parallel for better performance
      final results = await Future.wait([
        _firestore.collection('handymen').get(),
        _firestore.collection('clients').get(),
        _firestore
            .collection('handymen')
            .where('approved', isEqualTo: false)
            .where('suspended', isEqualTo: false)
            .get(),
        _firestore
            .collection('bookings')
            .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
            .get(),
        _firestore
            .collection('bookings')
            .where('status', isEqualTo: 'completed')
            .get(),
        _firestore.collection('bookings').get(),
      ]);

      final handymenSnapshot = results[0];
      final clientsSnapshot = results[1];
      final pendingSnapshot = results[2];
      final activeBookingsSnapshot = results[3];
      final completedBookingsSnapshot = results[4];
      final allBookingsSnapshot = results[5];

      // ✅ Filter out current user from counts
      int totalHandymen = 0;
      int totalClients = 0;

      for (var doc in handymenSnapshot.docs) {
        if (doc.id != currentUserId) totalHandymen++;
      }

      for (var doc in clientsSnapshot.docs) {
        if (doc.id != currentUserId) totalClients++;
      }

      // Calculate revenue
      double totalRevenue = 0;
      double thisMonthRevenue = 0;

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in completedBookingsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? data['totalAmount'] ?? 0).toDouble();
        totalRevenue += amount;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(firstDayOfMonth)) {
          thisMonthRevenue += amount;
        }
      }

      // Calculate approval rate
      final totalHandymenEver = totalHandymen + pendingSnapshot.size;
      final approvalRate = totalHandymenEver > 0
          ? (totalHandymen / totalHandymenEver * 100)
          : 0.0;

      if (kDebugMode) debugPrint('✅ Statistics loaded successfully');

      return {
        'totalHandymen': totalHandymen,
        'totalClients': totalClients,
        'totalUsers': totalHandymen + totalClients,
        'totalBookings': allBookingsSnapshot.size,
        'pendingApprovals': pendingSnapshot.size,
        'activeBookings': activeBookingsSnapshot.size,
        'completedBookings': completedBookingsSnapshot.size,
        'totalRevenue': totalRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'averageBookingValue': completedBookingsSnapshot.size > 0
            ? totalRevenue / completedBookingsSnapshot.size
            : 0.0,
        'approvalRate': approvalRate,
        'activeRate':
            (activeBookingsSnapshot.size + completedBookingsSnapshot.size) > 0
            ? (activeBookingsSnapshot.size /
                  (activeBookingsSnapshot.size +
                      completedBookingsSnapshot.size) *
                  100)
            : 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting statistics: $e');

      if (e.toString().contains('index')) {
        if (kDebugMode) debugPrint('⚠️ Firestore index required. Create indexes for:');
        if (kDebugMode) debugPrint('   Collection: handymen - Fields: approved (=), suspended (=)');
        if (kDebugMode) debugPrint('   Collection: bookings - Field: status (=)');
      }

      return {};
    }
  }

  // ... (keep all existing methods: getHandymen, getPendingHandymen, approveHandyman, etc.)
  // Just add the new admin-related methods above

  // ============================================
  // ACTIVITY LOG
  // ============================================

  /// Internal method to log admin actions
  Future<void> _logAdminAction({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('admin_logs').add({
        'adminId': user.uid,
        'adminEmail': user.email,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Admin action logged: $action');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error logging action: $e');
    }
  }

  /// Check if current user is admin
  // Future<bool> isAdmin() async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) return false;

  //     final adminDoc = await _firestore
  //         .collection('admins')
  //         .doc(user.uid)
  //         .get();
  //     // return true;
  //     return adminDoc.exists && (adminDoc.data()?['isAdmin'] == true);
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error checking admin status: $e');
  //     return false;
  //   }
  // }

  /// Create admin user (only for initial setup)
  // Future<bool> createAdmin(
  //   String userId, {
  //   required String email,
  //   required String name,
  // }) async {
  //   try {
  //     await _firestore.collection('admins').doc(userId).set({
  //       'isAdmin': true,
  //       'email': email,
  //       'name': name,
  //       'createdAt': FieldValue.serverTimestamp(),
  //       'permissions': [
  //         'approve_handymen',
  //         'suspend_users',
  //         'view_analytics',
  //         'manage_bookings',
  //       ],
  //     });

  //     if (kDebugMode) debugPrint('✅ Admin created: $userId');
  //     return true;
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error creating admin: $e');
  //     return false;
  //   }
  // }

  // ============================================
  // STATISTICS
  // ============================================

  /// Get comprehensive app statistics
  // Future<Map<String, dynamic>> getAppStatistics() async {
  //   try {
  //     // Execute queries in parallel for better performance
  //     final results = await Future.wait([
  //       _firestore.collection('handymen').get(),
  //       _firestore.collection('clients').get(),
  //       _firestore
  //           .collection('handymen')
  //           .where('approved', isEqualTo: false)
  //           .where('suspended', isEqualTo: false)
  //           .get(),
  //       _firestore
  //           .collection('bookings')
  //           .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
  //           .get(),
  //       _firestore
  //           .collection('bookings')
  //           .where('status', isEqualTo: 'completed')
  //           .get(),
  //       _firestore.collection('bookings').get(),
  //     ]);

  //     final handymenSnapshot = results[0];
  //     final clientsSnapshot = results[1];
  //     final pendingSnapshot = results[2];
  //     final activeBookingsSnapshot = results[3];
  //     final completedBookingsSnapshot = results[4];
  //     final allBookingsSnapshot = results[5];

  //     // Calculate revenue
  //     double totalRevenue = 0;
  //     double thisMonthRevenue = 0;

  //     final now = DateTime.now();
  //     final firstDayOfMonth = DateTime(now.year, now.month, 1);

  //     for (var doc in completedBookingsSnapshot.docs) {
  //       final data = doc.data();
  //       final amount = (data['amount'] ?? data['totalAmount'] ?? 0).toDouble();
  //       totalRevenue += amount;

  //       final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  //       if (createdAt != null && createdAt.isAfter(firstDayOfMonth)) {
  //         thisMonthRevenue += amount;
  //       }
  //     }

  //     // Calculate approval rate
  //     final totalHandymenEver = handymenSnapshot.size + pendingSnapshot.size;
  //     final approvalRate = totalHandymenEver > 0
  //         ? (handymenSnapshot.size / totalHandymenEver * 100)
  //         : 0.0;

  //     if (kDebugMode) debugPrint('✅ Statistics loaded successfully');

  //     return {
  //       'totalHandymen': handymenSnapshot.size,
  //       'totalClients': clientsSnapshot.size,
  //       'totalUsers': handymenSnapshot.size + clientsSnapshot.size,
  //       'totalBookings': allBookingsSnapshot.size,
  //       'pendingApprovals': pendingSnapshot.size,
  //       'activeBookings': activeBookingsSnapshot.size,
  //       'completedBookings': completedBookingsSnapshot.size,
  //       'totalRevenue': totalRevenue,
  //       'thisMonthRevenue': thisMonthRevenue,
  //       'averageBookingValue': completedBookingsSnapshot.size > 0
  //           ? totalRevenue / completedBookingsSnapshot.size
  //           : 0.0,
  //       'approvalRate': approvalRate,
  //       'activeRate':
  //           (activeBookingsSnapshot.size + completedBookingsSnapshot.size) > 0
  //           ? (activeBookingsSnapshot.size /
  //                 (activeBookingsSnapshot.size +
  //                     completedBookingsSnapshot.size) *
  //                 100)
  //           : 0.0,
  //       'lastUpdated': DateTime.now().toIso8601String(),
  //     };
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error getting statistics: $e');

  //     // If error is due to missing index, provide helpful message
  //     if (e.toString().contains('index')) {
  //       if (kDebugMode) debugPrint('⚠️ Firestore index required. Create indexes for:');
  //       if (kDebugMode) debugPrint('   Collection: handymen - Fields: approved (=), suspended (=)');
  //       if (kDebugMode) debugPrint('   Collection: bookings - Field: status (=)');
  //     }

  //     return {};
  //   }
  // }

  /// Stream real-time statistics
  Stream<Map<String, dynamic>> streamAppStatistics() async* {
    while (true) {
      yield await getAppStatistics();
      await Future.delayed(Duration(seconds: 30));
    }
  }

  // ============================================
  // HANDYMAN MANAGEMENT
  // ============================================

  /// Get all handymen with optional filters
  Future<List<Map<String, dynamic>>> getHandymen({
    bool? approved,
    bool? suspended,
    String? city,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection('handymen');

      if (approved != null) {
        query = query.where('approved', isEqualTo: approved);
      }

      if (suspended != null) {
        query = query.where('suspended', isEqualTo: suspended);
      }

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting handymen: $e');
      return [];
    }
  }

  /// Get pending handymen (waiting for approval)
  Future<List<Map<String, dynamic>>> getPendingHandymen({
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('handymen')
          .where('approved', isEqualTo: false)
          .where('suspended', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting pending handymen: $e');

      if (e.toString().contains('index')) {
        if (kDebugMode) debugPrint('⚠️ Create Firestore index:');
        if (kDebugMode) debugPrint('   Collection: handymen');
        if (kDebugMode) debugPrint('   Fields: approved (=), suspended (=), createdAt (DESC)');
      }

      return [];
    }
  }

  /// Approve handyman
  Future<bool> approveHandyman(String handymanId) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'approved': true,
        'rejected': false,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAdminAction(
        action: 'approve_handyman',
        targetType: 'handyman',
        targetId: handymanId,
      );

      if (kDebugMode) debugPrint('✅ Handyman approved: $handymanId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error approving handyman: $e');
      return false;
    }
  }

  /// Reject handyman
  Future<bool> rejectHandyman(String handymanId, {String? reason}) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'approved': false,
        'rejected': true,
        'rejectionReason': reason ?? 'Application did not meet requirements',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAdminAction(
        action: 'reject_handyman',
        targetType: 'handyman',
        targetId: handymanId,
        details: {'reason': reason},
      );

      if (kDebugMode) debugPrint('✅ Handyman rejected: $handymanId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error rejecting handyman: $e');
      return false;
    }
  }

  /// Suspend/Unsuspend handyman account
  Future<bool> toggleSuspendHandyman(
    String handymanId,
    bool suspend, {
    String? reason,
  }) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'suspended': suspend,
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
        'suspensionReason': suspend ? (reason ?? 'Violation of terms') : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAdminAction(
        action: suspend ? 'suspend_handyman' : 'unsuspend_handyman',
        targetType: 'handyman',
        targetId: handymanId,
        details: {'reason': reason},
      );

      if (kDebugMode) debugPrint('✅ Handyman ${suspend ? "suspended" : "unsuspended"}: $handymanId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error toggling suspend: $e');
      return false;
    }
  }

  /// Delete handyman account (use with caution)
  Future<bool> deleteHandyman(String handymanId) async {
    try {
      // Delete from handymen collection
      await _firestore.collection('handymen').doc(handymanId).delete();

      // Also delete from users collection if exists
      await _firestore.collection('users').doc(handymanId).delete();

      // Log the action
      await _logAdminAction(
        action: 'delete_handyman',
        targetType: 'handyman',
        targetId: handymanId,
      );

      if (kDebugMode) debugPrint('✅ Handyman deleted: $handymanId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting handyman: $e');
      return false;
    }
  }

  // ============================================
  // CLIENT MANAGEMENT
  // ============================================

  /// Get all clients
  Future<List<Map<String, dynamic>>> getClients({
    String? city,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection('clients');

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting clients: $e');
      return [];
    }
  }

  /// Delete client account
  Future<bool> deleteClient(String clientId) async {
    try {
      await _firestore.collection('clients').doc(clientId).delete();
      await _firestore.collection('users').doc(clientId).delete();

      await _logAdminAction(
        action: 'delete_client',
        targetType: 'client',
        targetId: clientId,
      );

      if (kDebugMode) debugPrint('✅ Client deleted: $clientId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting client: $e');
      return false;
    }
  }

  /// Suspend/Unsuspend client account
  Future<bool> toggleSuspendClient(
    String clientId,
    bool suspend, {
    String? reason,
  }) async {
    try {
      await _firestore.collection('clients').doc(clientId).update({
        'suspended': suspend,
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
        'suspensionReason': suspend ? (reason ?? 'Violation of terms') : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logAdminAction(
        action: suspend ? 'suspend_client' : 'unsuspend_client',
        targetType: 'client',
        targetId: clientId,
        details: {'reason': reason},
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error toggling client suspend: $e');
      return false;
    }
  }

  // ============================================
  // BOOKINGS MANAGEMENT
  // ============================================

  /// Get recent bookings
  Future<List<Map<String, dynamic>>> getRecentBookings({
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('bookings');

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting bookings: $e');
      return [];
    }
  }

  /// Cancel booking (admin action)
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled_by_admin',
        'cancellationReason': reason ?? 'Cancelled by administrator',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logAdminAction(
        action: 'cancel_booking',
        targetType: 'booking',
        targetId: bookingId,
        details: {'reason': reason},
      );

      if (kDebugMode) debugPrint('✅ Booking cancelled: $bookingId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error cancelling booking: $e');
      return false;
    }
  }

  // ============================================
  // COMPLAINTS & REPORTS
  // ============================================

  /// Get complaints/reports
  Future<List<Map<String, dynamic>>> getComplaints({
    bool? resolved,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('complaints');

      if (resolved != null) {
        query = query.where('resolved', isEqualTo: resolved);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting complaints: $e');
      return [];
    }
  }

  /// Resolve complaint
  Future<bool> resolveComplaint(
    String complaintId, {
    String? resolution,
  }) async {
    try {
      await _firestore.collection('complaints').doc(complaintId).update({
        'resolved': true,
        'resolution': resolution ?? 'Resolved by admin',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': _auth.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logAdminAction(
        action: 'resolve_complaint',
        targetType: 'complaint',
        targetId: complaintId,
        details: {'resolution': resolution},
      );

      if (kDebugMode) debugPrint('✅ Complaint resolved: $complaintId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error resolving complaint: $e');
      return false;
    }
  }

  // ============================================
  // ACTIVITY LOG
  // ============================================

  /// Internal method to log admin actions
  // Future<void> _logAdminAction({
  //   required String action,
  //   required String targetType,
  //   required String targetId,
  //   Map<String, dynamic>? details,
  // }) async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) return;

  //     await _firestore.collection('admin_logs').add({
  //       'adminId': user.uid,
  //       'adminEmail': user.email,
  //       'action': action,
  //       'targetType': targetType,
  //       'targetId': targetId,
  //       'details': details ?? {},
  //       'timestamp': FieldValue.serverTimestamp(),
  //     });

  //     if (kDebugMode) debugPrint('✅ Admin action logged: $action');
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error logging action: $e');
  //   }
  // }

  /// Get recent admin activity
  Future<List<Map<String, dynamic>>> getAdminActivity({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting activity: $e');
      return [];
    }
  }

  // ============================================
  // REVENUE & ANALYTICS
  // ============================================

  /// Get detailed revenue statistics
  Future<Map<String, dynamic>> getRevenueStats() async {
    try {
      final completedBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0;
      double thisMonthRevenue = 0;
      double todayRevenue = 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in completedBookings.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? data['totalAmount'] ?? 0).toDouble();
        totalRevenue += amount;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          if (createdAt.isAfter(firstDayOfMonth)) {
            thisMonthRevenue += amount;
          }
          if (createdAt.isAfter(today)) {
            todayRevenue += amount;
          }
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'todayRevenue': todayRevenue,
        'averageBookingValue': completedBookings.size > 0
            ? totalRevenue / completedBookings.size
            : 0.0,
        'totalCompletedBookings': completedBookings.size,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting revenue stats: $e');
      return {};
    }
  }

  /// Get growth statistics
  Future<Map<String, dynamic>> getGrowthStats() async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);

      // This month's data
      final thisMonthHandymen = await _firestore
          .collection('handymen')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
          )
          .get();

      final thisMonthClients = await _firestore
          .collection('clients')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
          )
          .get();

      // Last month's data
      final lastMonthHandymen = await _firestore
          .collection('handymen')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfLastMonth),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(firstDayOfMonth))
          .get();

      final lastMonthClients = await _firestore
          .collection('clients')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfLastMonth),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(firstDayOfMonth))
          .get();

      // Calculate growth percentages
      final handymenGrowth = lastMonthHandymen.size > 0
          ? ((thisMonthHandymen.size - lastMonthHandymen.size) /
                lastMonthHandymen.size *
                100)
          : 100.0;

      final clientsGrowth = lastMonthClients.size > 0
          ? ((thisMonthClients.size - lastMonthClients.size) /
                lastMonthClients.size *
                100)
          : 100.0;

      return {
        'handymenThisMonth': thisMonthHandymen.size,
        'handymenLastMonth': lastMonthHandymen.size,
        'handymenGrowth': handymenGrowth,
        'clientsThisMonth': thisMonthClients.size,
        'clientsLastMonth': lastMonthClients.size,
        'clientsGrowth': clientsGrowth,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting growth stats: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getTrendingSkills({int limit = 5}) async {
    try {
      final handymenSnapshot = await _firestore
          .collection('handymen')
          .where('approved', isEqualTo: true)
          .get();

      Map<String, int> skillCounts = {};

      for (var doc in handymenSnapshot.docs) {
        final data = doc.data();
        final skills = data['skills'] as List<dynamic>?;

        if (skills != null) {
          for (var skill in skills) {
            final skillName = skill is String ? skill : skill['name'];
            skillCounts[skillName] = (skillCounts[skillName] ?? 0) + 1;
          }
        }
      }

      final sortedSkills = skillCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedSkills.take(limit).map((entry) {
        return {
          'name': entry.key,
          'count': entry.value,
          'percentage': (entry.value / handymenSnapshot.size * 100)
              .toStringAsFixed(1),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting trending skills: $e');
      return [];
    }
  }

  /// Get top performing handymen
  Future<List<Map<String, dynamic>>> getTopHandymen({int limit = 5}) async {
    try {
      final handymenSnapshot = await _firestore
          .collection('handymen')
          .where('approved', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> handymenWithStats = [];

      for (var doc in handymenSnapshot.docs) {
        final data = doc.data();
        final handymanId = doc.id;

        // Get completed bookings count
        final bookingsSnapshot = await _firestore
            .collection('bookings')
            .where('handymanId', isEqualTo: handymanId)
            .where('status', isEqualTo: 'completed')
            .get();

        // Get average rating
        final reviewsSnapshot = await _firestore
            .collection('reviews')
            .where('handymanId', isEqualTo: handymanId)
            .get();

        double avgRating = 0.0;
        if (reviewsSnapshot.size > 0) {
          double totalRating = 0;
          for (var review in reviewsSnapshot.docs) {
            totalRating += (review.data()['rating'] ?? 0).toDouble();
          }
          avgRating = totalRating / reviewsSnapshot.size;
        }

        handymenWithStats.add({
          'id': handymanId,
          'name': data['fullName'] ?? 'Unknown',
          'profilePicture': data['profilePicture'],
          'city': data['city'] ?? 'Unknown',
          'completedJobs': bookingsSnapshot.size,
          'rating': avgRating,
          'reviewCount': reviewsSnapshot.size,
        });
      }

      // Sort by completed jobs and rating
      handymenWithStats.sort((a, b) {
        final jobsCompare = (b['completedJobs'] as int).compareTo(
          a['completedJobs'] as int,
        );
        if (jobsCompare != 0) return jobsCompare;
        return (b['rating'] as double).compareTo(a['rating'] as double);
      });

      return handymenWithStats.take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting top handymen: $e');
      return [];
    }
  }

  /// Get recent activity (last 20 actions)
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 20}) async {
    try {
      // Combine recent bookings, approvals, and reviews
      final recentBookings = await _firestore
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final recentReviews = await _firestore
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> activities = [];

      // Add bookings
      for (var doc in recentBookings.docs) {
        final data = doc.data();
        activities.add({
          'type': 'booking',
          'icon': Icons.work,
          'title': 'New Booking',
          'description': data['service'] ?? 'Unknown service',
          'status': data['status'],
          'timestamp': data['createdAt'],
          'color': AppColors.accentColor,
        });
      }

      // Add reviews
      for (var doc in recentReviews.docs) {
        final data = doc.data();
        activities.add({
          'type': 'review',
          'icon': Icons.star,
          'title': 'New Review',
          'description': '${data['rating']} stars',
          'timestamp': data['createdAt'],
          'color': AppColors.accentOrange,
        });
      }

      // Sort by timestamp
      activities.sort((a, b) {
        final aTime =
            (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime =
            (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      return activities.take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting recent activity: $e');
      return [];
    }
  }

  /// Get platform health metrics
  Future<Map<String, dynamic>> getPlatformHealth() async {
    try {
      final now = DateTime.now();
      final last24h = now.subtract(Duration(hours: 24));
      final last7days = now.subtract(Duration(days: 7));

      // Get active users (logged in last 24h)
      final activeHandymen = await _firestore
          .collection('handymen')
          .where('lastActiveAt', isGreaterThan: Timestamp.fromDate(last24h))
          .get();

      final activeClients = await _firestore
          .collection('clients')
          .where('lastActiveAt', isGreaterThan: Timestamp.fromDate(last24h))
          .get();

      // Get new users this week
      final newHandymen = await _firestore
          .collection('handymen')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last7days))
          .get();

      final newClients = await _firestore
          .collection('clients')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last7days))
          .get();

      // Get booking completion rate
      final completedThisWeek = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThan: Timestamp.fromDate(last7days))
          .get();

      final totalThisWeek = await _firestore
          .collection('bookings')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last7days))
          .get();

      final completionRate = totalThisWeek.size > 0
          ? (completedThisWeek.size / totalThisWeek.size * 100)
          : 0.0;

      return {
        'activeUsers24h': activeHandymen.size + activeClients.size,
        'activeHandymen24h': activeHandymen.size,
        'activeClients24h': activeClients.size,
        'newUsers7d': newHandymen.size + newClients.size,
        'newHandymen7d': newHandymen.size,
        'newClients7d': newClients.size,
        'bookingCompletionRate': completionRate,
        'bookingsThisWeek': totalThisWeek.size,
        'completedThisWeek': completedThisWeek.size,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting platform health: $e');
      return {};
    }
  }

  /// Get city-wise distribution
  Future<List<Map<String, dynamic>>> getCityDistribution() async {
    try {
      final handymenSnapshot = await _firestore
          .collection('handymen')
          .where('approved', isEqualTo: true)
          .get();

      Map<String, int> cityCounts = {};

      for (var doc in handymenSnapshot.docs) {
        final city = doc.data()['city'] ?? 'Unknown';
        cityCounts[city] = (cityCounts[city] ?? 0) + 1;
      }

      final sortedCities = cityCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCities.map((entry) {
        return {
          'city': entry.key,
          'count': entry.value,
          'percentage': (entry.value / handymenSnapshot.size * 100)
              .toStringAsFixed(1),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting city distribution: $e');
      return [];
    }
  }

  Future<bool> sendNotificationToHandyman(
    String handymanId, {
    required String title,
    required String message,
    String type = 'admin_message',
  }) async {
    try {
      // Get handyman data
      final handymanDoc = await _firestore
          .collection('handymen')
          .doc(handymanId)
          .get();

      if (!handymanDoc.exists) {
        if (kDebugMode) debugPrint('❌ Handyman not found');
        return false;
      }

      final handymanData = handymanDoc.data()!;
      final handymanName = handymanData['fullName'] ?? 'Handyman';

      // Create notification
      await _firestore.collection('notifications').add({
        'userId': handymanId,
        'userType': 'handyman',
        'type': type,
        'title': title,
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log admin action
      await _logAdminAction(
        action: 'send_notification',
        targetType: 'handyman',
        targetId: handymanId,
        details: {'title': title, 'message': message},
      );

      if (kDebugMode) debugPrint('✅ Notification sent to $handymanName');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error sending notification: $e');
      return false;
    }
  }

  Future<bool> rejectHandymanWithReason(
    String handymanId, {
    required String reason,
  }) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'approved': false,
        'rejected': true,
        'reviewStatus': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification
      await sendNotificationToHandyman(
        handymanId,
        title: '❌ Profile Rejected',
        message: 'Your profile was not approved. Reason: $reason',
        type: 'rejection',
      );

      await _logAdminAction(
        action: 'reject_handyman',
        targetType: 'handyman',
        targetId: handymanId,
        details: {'reason': reason},
      );

      if (kDebugMode) debugPrint('✅ Handyman rejected with reason');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error rejecting handyman: $e');
      return false;
    }
  }

  Future<bool> requestMoreInfo(
    String handymanId, {
    required String message,
    List<String>? missingFields,
  }) async {
    try {
      String fullMessage = message;

      if (missingFields != null && missingFields.isNotEmpty) {
        fullMessage += '\n\nMissing information:\n';
        fullMessage += missingFields.map((field) => '• $field').join('\n');
      }

      // Update handyman status
      await _firestore.collection('handymen').doc(handymanId).update({
        'reviewStatus': 'needs_info',
        'infoRequest': {
          'message': fullMessage,
          'missingFields': missingFields ?? [],
          'requestedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification
      await sendNotificationToHandyman(
        handymanId,
        title: '📋 Information Required',
        message: fullMessage,
        type: 'info_request',
      );

      await _logAdminAction(
        action: 'request_info',
        targetType: 'handyman',
        targetId: handymanId,
        details: {'message': message, 'missingFields': missingFields},
      );

      if (kDebugMode) debugPrint('✅ Info request sent');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error requesting info: $e');
      return false;
    }
  }

  /// Suspend handyman
  Future<bool> suspendHandymanWithReason(
    String handymanId, {
    required String reason,
  }) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'suspended': true,
        'reviewStatus': 'suspended',
        'suspensionReason': reason,
        'suspendedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification
      await sendNotificationToHandyman(
        handymanId,
        title: '⚠️ Account Suspended',
        message: 'Your account has been suspended. Reason: $reason',
        type: 'suspension',
      );

      await _logAdminAction(
        action: 'suspend_handyman',
        targetType: 'handyman',
        targetId: handymanId,
        details: {'reason': reason},
      );

      if (kDebugMode) debugPrint('✅ Handyman suspended');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error suspending handyman: $e');
      return false;
    }
  }

  /// Get admin notifications
  Future<List<Map<String, dynamic>>> getAdminNotifications({
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('adminNotifications')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      if (kDebugMode) debugPrint("snapshot.docs : ${snapshot.docs}");

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting admin notifications: $e');
      return [];
    }
  }

  /// Mark admin notification as read
  Future<bool> markAdminNotificationRead(String notificationId) async {
    try {
      await _firestore
          .collection('adminNotifications')
          .doc(notificationId)
          .update({'read': true});
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Approve handyman with optional message
  Future<bool> approveHandymanWithMessage(
    String handymanId, {
    String? customMessage,
  }) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'approved': true,
        'rejected': false,
        'suspended': false,
        'reviewStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to handyman
      final message =
          customMessage ??
          'Congratulations! Your profile has been approved. You can now start accepting bookings.';

      await sendNotificationToHandyman(
        handymanId,
        title: '🎉 Profile Approved',
        message: message,
        type: 'approval',
      );

      // Log action
      await _logAdminAction(
        action: 'approve_handyman',
        targetType: 'handyman',
        targetId: handymanId,
      );

      if (kDebugMode) debugPrint('✅ Handyman approved with notification');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error approving handyman: $e');
      return false;
    }
  }
}
