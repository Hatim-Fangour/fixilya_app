import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// All **real-time Firestore streams** for bookings and notifications.
///
/// Rule: this file never writes anything to Firestore.
/// All mutations go through [BookingsApiService].
class BookingsRealtimeService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────
  // HANDYMAN STREAMS
  // ─────────────────────────────────────────────

  /// Live stream of pending booking requests for the current handyman.
  Stream<List<Map<String, dynamic>>> streamBookingRequests() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('bookings')
        .where('handymanId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Live stream of confirmed + in-progress bookings for the current handyman.
  Stream<List<Map<String, dynamic>>> streamActiveBookings() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('bookings')
        .where('handymanId', isEqualTo: _uid)
        .where('status', whereIn: ['confirmed', 'in_progress'])
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map(_mapDocs);
  }

  /// Live stream of completed bookings for the current handyman.
  Stream<List<Map<String, dynamic>>> streamCompletedBookings() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('bookings')
        .where('handymanId', isEqualTo: _uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .limit(30)
        .snapshots()
        .map(_mapDocs);
  }

  /// Live stream of declined bookings for the current handyman.
  Stream<List<Map<String, dynamic>>> streamDeclinedBookings() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('bookings')
        .where('handymanId', isEqualTo: _uid)
        .where('status', isEqualTo: 'declined')
        .orderBy('declinedAt', descending: true)
        .limit(20)
        .snapshots()
        .map(_mapDocs);
  }

  /// Live stream of recent activity for the current user.
  Stream<List<Map<String, dynamic>>> streamRecentActivity() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('activity')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(_mapDocs);
  }

  // ─────────────────────────────────────────────
  // CLIENT STREAMS
  // ─────────────────────────────────────────────

  /// Live stream of bookings for the current client.
  /// Pass [status] to filter (e.g. 'pending', 'confirmed').
  Stream<List<Map<String, dynamic>>> streamClientBookings({String? status}) {
    if (_uid == null) return Stream.value([]);

    Query<Map<String, dynamic>> query = _db
        .collection('bookings')
        .where('clientId', isEqualTo: _uid);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  // ─────────────────────────────────────────────
  // NOTIFICATION STREAMS
  // ─────────────────────────────────────────────

  /// Live stream of all notifications for the current user (newest first).
  Stream<List<Map<String, dynamic>>> streamNotifications() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(_mapDocs);
  }

  /// Live count of unread notifications for the current user.
  Stream<int> streamUnreadCount() {
    if (_uid == null) return Stream.value(0);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Live snapshot of a single booking (used in notification action cards).
  Stream<Map<String, dynamic>?> streamBooking(String bookingId) {
    return _db
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map((doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null);
  }

  // ─────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────

  List<Map<String, dynamic>> _mapDocs(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
