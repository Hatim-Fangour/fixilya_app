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

  // Get client bookings
  Future<List<BookingModel>> getClientBookings(String clientId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  // Get handyman bookings
  Future<List<BookingModel>> getHandymanBookings(String handymanId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('handymanId', isEqualTo: handymanId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  // Get upcoming bookings
  Future<List<BookingModel>> getUpcomingBookings(String userId) async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection(_collection)
        .where('scheduledDate', isGreaterThan: now.toIso8601String())
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    return snapshot.docs
        .map((doc) => BookingModel.fromFirestore(doc))
        .where((b) => b.clientId == userId || b.handymanId == userId)
        .toList();
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
