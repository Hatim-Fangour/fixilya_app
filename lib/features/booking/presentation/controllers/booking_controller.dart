import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/data/models/booking_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// BookingController
/// Manages booking CRUD operations, state, and filtering for the current user.
/// Works for both client and handyman roles.
class BookingController extends GetxController {
  // ─── Services ────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── State ───────────────────────────────────────────────────────────────
  final bookings = <BookingModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // ─── Computed ────────────────────────────────────────────────────────────
  String? get _currentUid => _auth.currentUser?.uid;

  List<BookingModel> get upcomingBookings =>
      bookings.where((b) => b.isUpcoming).toList();

  List<BookingModel> get pastBookings =>
      bookings.where((b) => b.isPast).toList();

  List<BookingModel> get activeBookings =>
      bookings.where((b) => b.isInProgress || b.isConfirmed).toList();

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchBookings();
  }

  // ─── Fetch bookings for current user ─────────────────────────────────────
  Future<void> fetchBookings() async {
    final uid = _currentUid;
    if (uid == null) {
      errorMessage.value = 'User not authenticated';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Query bookings where the user is either the client or the handyman
      final clientQuery = await _firestore
          .collection('bookings')
          .where('clientId', isEqualTo: uid)
          .orderBy('scheduledDate', descending: true)
          .get();

      final handymanQuery = await _firestore
          .collection('bookings')
          .where('handymanId', isEqualTo: uid)
          .orderBy('scheduledDate', descending: true)
          .get();

      // Merge results, deduplicate by id
      final allDocs = <String, DocumentSnapshot>{};
      for (final doc in clientQuery.docs) {
        allDocs[doc.id] = doc;
      }
      for (final doc in handymanQuery.docs) {
        allDocs[doc.id] = doc;
      }

      bookings.value = allDocs.values.map((doc) {
        return BookingModel.fromFirestore(doc);
      }).toList();

      // Sort by scheduledDate descending
      bookings.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      if (kDebugMode) {
        debugPrint('BookingController: fetched ${bookings.length} bookings');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BookingController: fetchBookings error: $e');
      errorMessage.value = 'Failed to load bookings';
      Get.snackbar(
        'Error',
        'Failed to load bookings. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Create a new booking ────────────────────────────────────────────────
  Future<bool> createBooking({
    required String handymanId,
    required String serviceType,
    String? serviceDescription,
    required DateTime scheduledDate,
    required String scheduledTime,
    required String location,
    String? address,
    required double hourlyRate,
    int estimatedDuration = 60,
    String? clientNotes,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      Get.snackbar(
        'Error',
        'You must be logged in to create a booking.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    }

    isLoading.value = true;

    try {
      final now = DateTime.now();
      final estimatedCost = hourlyRate * (estimatedDuration / 60);

      final bookingData = BookingModel(
        id: '', // Firestore will assign
        clientId: uid,
        handymanId: handymanId,
        serviceType: serviceType,
        serviceDescription: serviceDescription,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        estimatedDuration: estimatedDuration,
        location: location,
        address: address,
        hourlyRate: hourlyRate,
        estimatedCost: estimatedCost,
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        clientNotes: clientNotes,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('bookings').add(bookingData.toFirestore());

      Get.snackbar(
        'Success',
        'Booking created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      // Refresh the list
      await fetchBookings();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('BookingController: createBooking error: $e');
      Get.snackbar(
        'Error',
        'Failed to create booking. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Update booking status ───────────────────────────────────────────────
  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    isLoading.value = true;

    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update locally
      final index = bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        bookings[index] = bookings[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        bookings.refresh();
      }

      Get.snackbar(
        'Success',
        'Booking status updated to ${newStatus.name}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BookingController: updateBookingStatus error: $e');
      }
      Get.snackbar(
        'Error',
        'Failed to update booking status.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Cancel booking ──────────────────────────────────────────────────────
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    final uid = _currentUid;
    if (uid == null) return false;

    isLoading.value = true;

    try {
      final updateData = <String, dynamic>{
        'status': BookingStatus.cancelled.name,
        'cancelledBy': uid,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reason != null && reason.isNotEmpty) {
        updateData['cancellationReason'] = reason;
      }

      await _firestore.collection('bookings').doc(bookingId).update(updateData);

      // Update locally
      final index = bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        bookings[index] = bookings[index].copyWith(
          status: BookingStatus.cancelled,
          cancelledBy: uid,
          cancelledAt: DateTime.now(),
          cancellationReason: reason,
        );
        bookings.refresh();
      }

      Get.snackbar(
        'Booking Cancelled',
        'Your booking has been cancelled.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.cancel_outlined, color: Colors.white),
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BookingController: cancelBooking error: $e');
      }
      Get.snackbar(
        'Error',
        'Failed to cancel booking. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Get a single booking by ID ──────────────────────────────────────────
  BookingModel? getBookingById(String bookingId) {
    try {
      return bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }
}
