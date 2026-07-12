import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bookings';

  // Create booking
  Future<String> createBooking(BookingModel booking) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(booking.toFirestore());
    return docRef.id;
  }

  // Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    final doc = await _firestore.collection(_collection).doc(bookingId).get();
    return doc.exists ? BookingModel.fromFirestore(doc) : null;
  }

  // Update booking
  Future<void> updateBooking(BookingModel booking) async {
    await _firestore
        .collection(_collection)
        .doc(booking.id)
        .update(booking.toFirestore());
  }

  // Get client bookings (most recent 50 — billing-safe)
  Future<List<BookingModel>> getClientBookings(String clientId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  // Get handyman bookings (most recent 50 — billing-safe)
  Future<List<BookingModel>> getHandymanBookings(String handymanId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('handymanId', isEqualTo: handymanId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  /// Get upcoming bookings for a user (as client or handyman).
  ///
  /// Firestore does not support OR queries across different fields in a single
  /// query, so we issue two separate queries (clientId and handymanId) and
  /// merge the results, deduplicating by booking id.
  Future<List<BookingModel>> getUpcomingBookings(String userId) async {
    final now = DateTime.now();

    // Query bookings where the user is the client (cap at 20 — upcoming only)
    final clientSnapshot = await _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThan: now.toIso8601String())
        .where('status', whereIn: ['pending', 'confirmed'])
        .limit(20)
        .get();

    // Query bookings where the user is the handyman (cap at 20 — upcoming only)
    final handymanSnapshot = await _firestore
        .collection(_collection)
        .where('handymanId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThan: now.toIso8601String())
        .where('status', whereIn: ['pending', 'confirmed'])
        .limit(20)
        .get();

    // Merge and deduplicate by document id
    final seen = <String>{};
    final results = <BookingModel>[];

    for (final doc in [...clientSnapshot.docs, ...handymanSnapshot.docs]) {
      if (seen.add(doc.id)) {
        results.add(BookingModel.fromFirestore(doc));
      }
    }

    // Sort by scheduled date ascending (nearest first)
    results.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return results;
  }

  // Cancel booking
  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
    required String reason,
  }) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': BookingStatus.cancelled.name,
      'cancellationReason': reason,
      'cancelledBy': userId,
      'cancelledAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
