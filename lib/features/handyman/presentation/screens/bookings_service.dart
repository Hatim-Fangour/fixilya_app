import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================
  // BOOKINGS MANAGEMENT
  // ============================================

  /// Get active bookings for current handyman
  Stream<List<Map<String, dynamic>>> streamActiveBookings() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('bookings')
        .where('handymanId', isEqualTo: currentUserId)
        .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Get booking requests (pending approval)
  Stream<List<Map<String, dynamic>>> streamBookingRequests() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('bookings')
        .where('handymanId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Get recent activity (completed, cancelled bookings + reviews)
  Stream<List<Map<String, dynamic>>> streamRecentActivity() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('activity')
        .where('handymanId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Accept a booking request
  Future<bool> acceptBooking(String bookingId) async {
    try {
      print('✅ Accepting booking: $bookingId');

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'confirmed',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity record
      await _createActivity(
        type: 'booking_accepted',
        bookingId: bookingId,
        title: 'Booking Accepted',
        description: 'You accepted a new booking request',
      );

      print('✅ Booking accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting booking: $e');
      return false;
    }
  }

  /// Decline a booking request
  Future<bool> declineBooking(String bookingId) async {
    try {
      print('🚫 Declining booking: $bookingId');

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity record
      await _createActivity(
        type: 'booking_declined',
        bookingId: bookingId,
        title: 'Booking Declined',
        description: 'You declined a booking request',
      );

      print('✅ Booking declined successfully');
      return true;
    } catch (e) {
      print('❌ Error declining booking: $e');
      return false;
    }
  }

  /// Mark booking as complete
  Future<bool> completeBooking(String bookingId) async {
    try {
      print('🎉 Completing booking: $bookingId');

      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      final bookingData = bookingDoc.data();

      if (bookingData == null) {
        print('❌ Booking not found');
        return false;
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity record
      await _createActivity(
        type: 'job_completed',
        bookingId: bookingId,
        title: 'Job Completed',
        description:
            'Job completed for ${bookingData['clientName'] ?? 'client'}',
        amount: bookingData['amount'],
      );

      // Update handyman stats
      await _updateHandymanStats(
        completedJobs: 1,
        earnings: (bookingData['amount'] ?? 0.0).toDouble(),
      );

      print('✅ Booking completed successfully');
      return true;
    } catch (e) {
      print('❌ Error completing booking: $e');
      return false;
    }
  }

  // ============================================
  // NOTIFICATIONS
  // ============================================

  /// Get unread notifications count
  Stream<int> streamUnreadNotificationsCount() {
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get all notifications
  Stream<List<Map<String, dynamic>>> streamNotifications() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      if (currentUserId == null) return;

      final batch = _firestore.batch();

      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Create activity record
  Future<void> _createActivity({
    required String type,
    required String title,
    required String description,
    String? bookingId,
    double? amount,
  }) async {
    try {
      if (currentUserId == null) return;

      await _firestore.collection('activity').add({
        'handymanId': currentUserId,
        'type': type,
        'title': title,
        'description': description,
        'bookingId': bookingId,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error creating activity: $e');
    }
  }

  /// Update handyman statistics
  Future<void> _updateHandymanStats({
    int? completedJobs,
    double? earnings,
  }) async {
    try {
      if (currentUserId == null) return;

      final updates = <String, dynamic>{};

      if (completedJobs != null) {
        updates['completedJobs'] = FieldValue.increment(completedJobs);
      }

      if (earnings != null) {
        updates['totalEarnings'] = FieldValue.increment(earnings);
        updates['monthlyEarnings'] = FieldValue.increment(earnings);
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('handymen')
          .doc(currentUserId)
          .update(updates);

      print('✅ Handyman stats updated');
    } catch (e) {
      print('❌ Error updating handyman stats: $e');
    }
  }

  /// Create a test booking (for testing)
  Future<String?> createTestBooking({
    required String clientName,
    required String service,
    required String location,
    required double amount,
    required DateTime scheduledDate,
  }) async {
    try {
      if (currentUserId == null) return null;

      final docRef = await _firestore.collection('bookings').add({
        'handymanId': currentUserId,
        'clientName': clientName,
        'clientId': 'test_client_id',
        'service': service,
        'location': location,
        'amount': amount,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification
      await _firestore.collection('notifications').add({
        'userId': currentUserId,
        'type': 'new_request',
        'title': 'New Booking Request',
        'message': '$clientName requested $service service',
        'bookingId': docRef.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Test booking created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating test booking: $e');
      return null;
    }
  }
}
