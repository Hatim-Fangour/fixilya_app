import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // STATISTICS
  // ============================================

  /// Get app statistics
  Future<Map<String, dynamic>> getAppStatistics() async {
    try {
      // Get counts
      final handymenSnapshot = await _firestore.collection('handymen').get();
      final clientsSnapshot = await _firestore.collection('clients').get();
      final bookingsSnapshot = await _firestore.collection('bookings').get();

      // Pending handymen (profileCompleted but not approved)
      final pendingHandymen = await _firestore
          .collection('handymen')
          .where('approved', isEqualTo: false)
          .get();

      // Active bookings
      final activeBookings = await _firestore
          .collection('bookings')
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      // Completed bookings
      final completedBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      return {
        'totalHandymen': handymenSnapshot.size,
        'totalClients': clientsSnapshot.size,
        'totalBookings': bookingsSnapshot.size,
        'pendingApprovals': pendingHandymen.size,
        'activeBookings': activeBookings.size,
        'completedBookings': completedBookings.size,
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      return {};
    }
  }

  /// Stream app statistics (real-time)
  Stream<Map<String, dynamic>> streamAppStatistics() async* {
    while (true) {
      yield await getAppStatistics();
      await Future.delayed(Duration(seconds: 30)); // Update every 30 seconds
    }
  }

  // ============================================
  // HANDYMAN MANAGEMENT
  // ============================================

  /// Get all handymen (with filters)
  Future<List<Map<String, dynamic>>> getHandymen({
    bool? approved,
    bool? suspended,
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

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      print('❌ Error getting handymen: $e');
      return [];
    }
  }

  /// Get pending handymen (waiting for approval)
  Future<List<Map<String, dynamic>>> getPendingHandymen() async {
    return await getHandymen(approved: false, suspended: false);
  }

  /// Approve handyman
  Future<bool> approveHandyman(String handymanId) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Handyman approved: $handymanId');
      return true;
    } catch (e) {
      print('❌ Error approving handyman: $e');
      return false;
    }
  }

  /// Reject handyman
  Future<bool> rejectHandyman(String handymanId, {String? reason}) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'approved': false,
        'rejected': true,
        'rejectionReason': reason ?? 'Not specified',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Handyman rejected: $handymanId');
      return true;
    } catch (e) {
      print('❌ Error rejecting handyman: $e');
      return false;
    }
  }

  /// Suspend/Unsuspend handyman account
  Future<bool> toggleSuspendHandyman(String handymanId, bool suspend) async {
    try {
      await _firestore.collection('handymen').doc(handymanId).update({
        'suspended': suspend,
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Handyman ${suspend ? "suspended" : "unsuspended"}: $handymanId');
      return true;
    } catch (e) {
      print('❌ Error toggling suspend: $e');
      return false;
    }
  }

  /// Delete handyman account
  Future<bool> deleteHandyman(String handymanId) async {
    try {
      // Delete from handymen collection
      await _firestore.collection('handymen').doc(handymanId).delete();

      // Also delete from users collection
      await _firestore.collection('users').doc(handymanId).delete();

      print('✅ Handyman deleted: $handymanId');
      return true;
    } catch (e) {
      print('❌ Error deleting handyman: $e');
      return false;
    }
  }

  // ============================================
  // CLIENT MANAGEMENT
  // ============================================

  /// Get all clients
  Future<List<Map<String, dynamic>>> getClients({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('clients')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      print('❌ Error getting clients: $e');
      return [];
    }
  }

  /// Delete client account
  Future<bool> deleteClient(String clientId) async {
    try {
      await _firestore.collection('clients').doc(clientId).delete();
      await _firestore.collection('users').doc(clientId).delete();

      print('✅ Client deleted: $clientId');
      return true;
    } catch (e) {
      print('❌ Error deleting client: $e');
      return false;
    }
  }

  // ============================================
  // BOOKINGS & COMPLAINTS
  // ============================================

  /// Get recent bookings
  Future<List<Map<String, dynamic>>> getRecentBookings({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      print('❌ Error getting bookings: $e');
      return [];
    }
  }

  /// Get complaints/reports
  Future<List<Map<String, dynamic>>> getComplaints({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('complaints')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      print('❌ Error getting complaints: $e');
      return [];
    }
  }

  // ============================================
  // ACTIVITY LOG
  // ============================================

  /// Log admin action
  Future<void> logAdminAction({
    required String adminId,
    required String action,
    required String targetType, // 'handyman', 'client', 'booking'
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('admin_logs').add({
        'adminId': adminId,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Admin action logged: $action');
    } catch (e) {
      print('❌ Error logging action: $e');
    }
  }

  /// Get recent admin activity
  Future<List<Map<String, dynamic>>> getAdminActivity({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      print('❌ Error getting activity: $e');
      return [];
    }
  }

  // ============================================
  // REVENUE & ANALYTICS
  // ============================================

  /// Get revenue statistics
  Future<Map<String, dynamic>> getRevenueStats() async {
    try {
      final completedBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0;
      double thisMonthRevenue = 0;

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in completedBookings.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        totalRevenue += amount;

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(firstDayOfMonth)) {
          thisMonthRevenue += amount;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'averageBookingValue': completedBookings.size > 0
            ? totalRevenue / completedBookings.size
            : 0,
      };
    } catch (e) {
      print('❌ Error getting revenue stats: $e');
      return {};
    }
  }
}
