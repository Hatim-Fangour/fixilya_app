import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
// ✅ Import email service
import 'package:fixilya_app/services/email_service.dart';
import 'package:fixilya_app/services/location_privacy_service.dart';
import 'package:fixilya_app/services/location_service.dart';

class BookingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmailService _emailService = EmailService(); // ✅ Add email service
  final LocationPrivacyService _locationPrivacyService = LocationPrivacyService();
  final LocationService _locationService = LocationService();

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================
  // CLIENT BOOKING CREATION
  // ============================================

  /// Create a new booking request from client
  Future<String?> createBooking({
    required String handymanId,
    required String handymanName,
    required String clientName,
    required String clientPhone,
    required String service,
    required String address,
    required String city,
    required DateTime scheduledDate,
    // required String timeSlot,
    required String description,
    // required double estimatedPrice,
    double? clientLatitude,
    double? clientLongitude,
  }) async {
    try {
      if (currentUserId == null) {
        if (kDebugMode) debugPrint('❌ No user logged in');
        return null;
      }

      if (kDebugMode) debugPrint('📝 Creating booking...');

      // Create booking document
      final bookingRef = await _firestore.collection('bookings').add({
        'handymanId': handymanId,
        'handymanName': handymanName,
        'clientId': currentUserId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'service': service,
        'address': address,
        'city': city,
        'location': '$address, $city',
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        // 'timeSlot': timeSlot,
        'description': description,
        // 'amount': estimatedPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (clientLatitude != null) 'clientLatitude': clientLatitude,
        if (clientLongitude != null) 'clientLongitude': clientLongitude,
      });

      if (kDebugMode) debugPrint('✅ Booking created: ${bookingRef.id}');

      // ✅ Get handyman email for notification
      final handymanDoc = await _firestore
          .collection('handymen')
          .doc(handymanId)
          .get();
      final handymanEmail = handymanDoc.data()?['email'] as String?;

      // Create in-app notification for handyman
      await _createNotification(
        userId: handymanId,
        type: 'new_request',
        title: 'New Booking Request',
        message:
            '$clientName requested $service service on ${_formatDate(scheduledDate)} ',
        bookingId: bookingRef.id,
        actionType: 'booking_request',
        priority: 'high',
      );

      // ✅ Send EMAIL to handyman
      if (handymanEmail != null && handymanEmail.isNotEmpty) {
        // await _emailService.sendNewBookingRequestEmail(
        //   handymanEmail: handymanEmail,
        //   handymanName: handymanName,
        //   clientName: clientName,
        //   service: service,
        //   scheduledDate: _formatDate(scheduledDate),
        //   timeSlot: timeSlot,
        //   bookingId: bookingRef.id,
        // );
        if (kDebugMode) debugPrint('📧 Email sent to handyman: $handymanEmail');
      }

      // Create notification for client (confirmation)
      await _createNotification(
        userId: currentUserId!,
        type: 'booking_created',
        title: 'Booking Request Sent',
        message:
            'Your request to $handymanName has been sent. Waiting for confirmation.',
        bookingId: bookingRef.id,
        actionType: 'booking_status',
        priority: 'normal',
      );

      return bookingRef.id;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating booking: $e');
      return null;
    }
  }

  // ============================================
  // HANDYMAN: ACCEPT/DECLINE BOOKINGS
  // ============================================

  /// Accept a booking request (Handyman)
  Future<bool> acceptBooking(String bookingId) async {
    try {
      if (kDebugMode) debugPrint('✅ Accepting booking: $bookingId');

      // Get booking data first
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      final bookingData = bookingDoc.data();

      if (bookingData == null) {
        if (kDebugMode) debugPrint('❌ Booking not found');
        return false;
      }

      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'confirmed',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Attach handyman GPS to booking (independent — never aborts accept flow)
      _attachHandymanLocationToBooking(bookingId, bookingData).catchError((e) {
        if (kDebugMode) debugPrint('BookingsService: location attach failed: $e');
      });

      // Create activity for handyman
      await _createActivity(
        userId: currentUserId!,
        type: 'booking_accepted',
        bookingId: bookingId,
        title: 'Booking Accepted',
        description: 'You accepted booking from ${bookingData['clientName']}',
      );

      // ✅ Get client email
      final clientDoc = await _firestore
          .collection('clients')
          .doc(bookingData['clientId'])
          .get();
      final clientEmail = clientDoc.data()?['email'] as String?;

      // Create in-app notification for client
      await _createNotification(
        userId: bookingData['clientId'],
        type: 'booking_accepted',
        title: 'Booking Confirmed! 🎉',
        message:
            '${bookingData['handymanName']} accepted your booking for ${bookingData['service']}',
        bookingId: bookingId,
        actionType: 'booking_confirmed',
        priority: 'high',
      );

      // ✅ Send EMAIL to client
      if (clientEmail != null && clientEmail.isNotEmpty) {
        final scheduledDate = (bookingData['scheduledDate'] as Timestamp?)
            ?.toDate();

        await _emailService.sendBookingAcceptedEmail(
          clientEmail: clientEmail,
          clientName: bookingData['clientName'] ?? 'Client',
          handymanName: bookingData['handymanName'] ?? 'Handyman',
          service: bookingData['service'] ?? 'Service',
          scheduledDate: scheduledDate != null
              ? _formatDate(scheduledDate)
              : 'TBD',
          timeSlot: bookingData['timeSlot'] ?? 'TBD',
          bookingId: bookingId,
        );
        if (kDebugMode) debugPrint('📧 Acceptance email sent to client: $clientEmail');
      }

      if (kDebugMode) debugPrint('✅ Booking accepted successfully');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error accepting booking: $e');
      return false;
    }
  }

  /// Attaches handyman GPS to booking when privacy == 'on_booking_accept',
  /// and sends FCM-style in-app notification with Google Maps deep-link.
  Future<void> _attachHandymanLocationToBooking(
    String bookingId,
    Map<String, dynamic> bookingData,
  ) async {
    try {
      final uid = currentUserId;
      if (uid == null) return;

      final privacy = await _locationPrivacyService.getHandymanPrivacy(uid);

      if (privacy == 'on_booking_accept') {
        final pos = await _locationService.getCurrentLocation();
        if (pos != null) {
          await _firestore.collection('bookings').doc(bookingId).update({
            'handymanLatitude': pos.latitude,
            'handymanLongitude': pos.longitude,
          });

          // Notify client with Google Maps deep-link
          final mapsLink =
              'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
          final clientId = bookingData['clientId'] as String?;
          final handymanName = bookingData['handymanName'] ?? 'Your handyman';
          if (clientId != null) {
            await _createNotification(
              userId: clientId,
              type: 'handyman_location_shared',
              title: 'Booking Confirmed!',
              message: '$handymanName is on their way. Tap to see location: $mapsLink',
              bookingId: bookingId,
              actionType: 'view_location',
              priority: 'high',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingsService: _attachHandymanLocationToBooking: $e');
    }
  }

  /// Decline a booking request (Handyman)
  Future<bool> declineBooking(String bookingId, {String? reason}) async {
    try {
      if (kDebugMode) debugPrint('🚫 Declining booking: $bookingId');

      // Get booking data first
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      final bookingData = bookingDoc.data();

      if (bookingData == null) {
        if (kDebugMode) debugPrint('❌ Booking not found');
        return false;
      }

      final declineReason = reason ?? 'Not available';

      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
        'declineReason': declineReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity for handyman
      await _createActivity(
        userId: currentUserId!,
        type: 'booking_declined',
        bookingId: bookingId,
        title: 'Booking Declined',
        description: 'You declined booking from ${bookingData['clientName']}',
      );

      // ✅ Get client email
      final clientDoc = await _firestore
          .collection('clients')
          .doc(bookingData['clientId'])
          .get();
      final clientEmail = clientDoc.data()?['email'] as String?;

      // Create in-app notification for client
      await _createNotification(
        userId: bookingData['clientId'],
        type: 'booking_declined',
        title: 'Booking Declined',
        message:
            '${bookingData['handymanName']} is unable to accept your booking. $declineReason',
        bookingId: bookingId,
        actionType: 'booking_declined',
        priority: 'high',
      );

      // ✅ Send EMAIL to client
      if (clientEmail != null && clientEmail.isNotEmpty) {
        await _emailService.sendBookingDeclinedEmail(
          clientEmail: clientEmail,
          clientName: bookingData['clientName'] ?? 'Client',
          handymanName: bookingData['handymanName'] ?? 'Handyman',
          service: bookingData['service'] ?? 'Service',
          reason: declineReason,
          bookingId: bookingId,
        );
        if (kDebugMode) debugPrint('📧 Decline email sent to client: $clientEmail');
      }

      if (kDebugMode) debugPrint('✅ Booking declined successfully');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error declining booking: $e');
      return false;
    }
  }

  /// Start a booking (mark as in progress)
  Future<bool> startBooking(String bookingId) async {
    try {
      if (kDebugMode) debugPrint('▶️ Starting booking: $bookingId');

      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      final bookingData = bookingDoc.data();

      if (bookingData == null) return false;

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify client
      await _createNotification(
        userId: bookingData['clientId'],
        type: 'job_started',
        title: 'Job Started',
        message:
            '${bookingData['handymanName']} has started working on your ${bookingData['service']} service',
        bookingId: bookingId,
        actionType: 'job_update',
        priority: 'normal',
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error starting booking: $e');
      return false;
    }
  }

  /// Mark booking as complete (Handyman)
  Future<bool> completeBooking(String bookingId) async {
    try {
      if (kDebugMode) debugPrint('🎉 Completing booking: $bookingId');

      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      final bookingData = bookingDoc.data();

      if (bookingData == null) {
        if (kDebugMode) debugPrint('❌ Booking not found');
        return false;
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity for handyman
      await _createActivity(
        userId: currentUserId!,
        type: 'job_completed',
        bookingId: bookingId,
        title: 'Job Completed',
        description:
            'Completed ${bookingData['service']} for ${bookingData['clientName']}',
        amount: bookingData['amount'],
      );

      // Update handyman stats
      await _updateHandymanStats(
        completedJobs: 1,
        earnings: (bookingData['amount'] ?? 0.0).toDouble(),
      );

      // Notify client to leave review
      await _createNotification(
        userId: bookingData['clientId'],
        type: 'job_completed',
        title: 'Job Completed! ✅',
        message:
            '${bookingData['handymanName']} has completed your ${bookingData['service']} service. Please leave a review!',
        bookingId: bookingId,
        actionType: 'leave_review',
        priority: 'high',
      );

      if (kDebugMode) debugPrint('✅ Booking completed successfully');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error completing booking: $e');
      return false;
    }
  }

  /// Cancel booking (Client)
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    try {
      if (kDebugMode) debugPrint('❌ Cancelling booking: $bookingId');

      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      final bookingData = bookingDoc.data();

      if (bookingData == null) return false;

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason ?? 'Cancelled by client',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify handyman
      await _createNotification(
        userId: bookingData['handymanId'],
        type: 'booking_cancelled',
        title: 'Booking Cancelled',
        message:
            '${bookingData['clientName']} cancelled the booking. ${reason ?? ""}',
        bookingId: bookingId,
        actionType: 'booking_cancelled',
        priority: 'normal',
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error cancelling booking: $e');
      return false;
    }
  }

  // ============================================
  // STREAMS FOR HANDYMAN
  // ============================================

  /// Stream active bookings for current handyman
  Stream<List<Map<String, dynamic>>> streamActiveBookings() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('bookings')
        .where('handymanId', isEqualTo: currentUserId)
        .where('status', whereIn: ['confirmed', 'in_progress'])
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Stream booking requests (pending approval)
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

  /// Stream declined bookings
  Stream<List<Map<String, dynamic>>> streamDeclinedBookings() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('bookings')
        .where('handymanId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'declined')
        .orderBy('declinedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Stream recent activity
  Stream<List<Map<String, dynamic>>> streamRecentActivity() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('activity')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  // ============================================
  // STREAMS FOR CLIENT
  // ============================================

  /// Stream client's bookings
  Stream<List<Map<String, dynamic>>> streamClientBookings({String? status}) {
    if (currentUserId == null) return Stream.value([]);

    Query query = _firestore
        .collection('bookings')
        .where('clientId', isEqualTo: currentUserId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    });
  }

  // ============================================
  // NOTIFICATIONS
  // ============================================

  /// Create a notification
  Future<void> _createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? bookingId,
    String? actionType,
    String priority = 'normal',
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'bookingId': bookingId,
        'actionType': actionType,
        'priority': priority,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('📬 Notification created for user: $userId');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating notification: $e');
    }
  }

  /// Stream unread notifications count
  Stream<int> streamUnreadNotificationsCount() {
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream all notifications
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
      if (kDebugMode) debugPrint('❌ Error marking notification as read: $e');
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
      if (kDebugMode) debugPrint('✅ All notifications marked as read');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Create activity record
  Future<void> _createActivity({
    required String userId,
    required String type,
    required String title,
    required String description,
    String? bookingId,
    double? amount,
  }) async {
    try {
      await _firestore.collection('activity').add({
        'userId': userId,
        'type': type,
        'title': title,
        'description': description,
        'bookingId': bookingId,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error creating activity: $e');
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
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('handymen')
          .doc(currentUserId)
          .update(updates);

      if (kDebugMode) debugPrint('✅ Handyman stats updated');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error updating handyman stats: $e');
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ============================================
  // GET HANDYMAN AVAILABILITY
  // ============================================

  /// Get handyman's available time slots for a specific date
  Future<List<String>> getAvailableTimeSlots(
    String handymanId,
    DateTime date,
  ) async {
    try {
      // Default time slots
      final allSlots = [
        '08:00 - 10:00',
        '10:00 - 12:00',
        '12:00 - 14:00',
        '14:00 - 16:00',
        '16:00 - 18:00',
        '18:00 - 20:00',
      ];

      // Get bookings for that day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final bookedSlots = await _firestore
          .collection('bookings')
          .where('handymanId', isEqualTo: handymanId)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      final bookedTimeSlots = bookedSlots.docs
          .map((doc) => doc.data()['timeSlot'] as String?)
          .where((slot) => slot != null)
          .toList();

      // Filter out booked slots
      return allSlots.where((slot) => !bookedTimeSlots.contains(slot)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting available slots: $e');
      return [];
    }
  }
}
