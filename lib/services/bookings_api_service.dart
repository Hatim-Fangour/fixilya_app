import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';

/// All **write operations** for bookings and notifications.
///
/// Rule: every mutation goes through the backend so business logic,
/// auth checks, and stat updates are enforced server-side.
/// For real-time data use [BookingsRealtimeService] instead.
///
/// After every successful mutation the booking caches are invalidated
/// so the next read fetches fresh data.
class BookingsApiService {
  final _api = ApiClient();
  final _cache = DataPersistenceService();

  // ─────────────────────────────────────────────
  // BOOKING CREATION (client)
  // ─────────────────────────────────────────────

  /// POST /bookings
  ///
  /// Creates a booking and notifies the handyman.
  /// Returns the new [bookingId] on success, null on failure.
  Future<String?> createBooking({
    required String handymanId,
    required String handymanName,
    required String clientName,
    required String clientPhone,
    required String service,
    required String address,
    required String city,
    required DateTime scheduledDate,
    required String description,
    double? estimatedPrice,
  }) async {
    try {
      final response = await _api.bookingDio.post(
        '/api/bookings',
        data: {
          'handymanId': handymanId,
          'handymanName': handymanName,
          'clientName': clientName,
          'clientPhone': clientPhone,
          'service': service,
          'address': address,
          'city': city,
          'scheduledDate': scheduledDate.toIso8601String(),
          'description': description,
          if (estimatedPrice != null) 'estimatedPrice': estimatedPrice,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        await _cache.invalidateBookingCaches();
        return response.data['data']['bookingId'] as String;
      }
      return null;
    } on DioException catch (e) {
      _logError('createBooking', e);
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // STATUS TRANSITIONS (handyman)
  // ─────────────────────────────────────────────

  /// PUT /bookings/:id/accept
  ///
  /// Handyman accepts a pending booking.
  Future<bool> acceptBooking(String bookingId) async {
    try {
      final response = await _api.bookingDio.put('/api/bookings/$bookingId/accept');
      final ok = response.statusCode == 200 && response.data['success'] == true;
      if (ok) await _cache.invalidateBookingCaches();
      return ok;
    } on DioException catch (e) {
      _logError('acceptBooking', e);
      return false;
    }
  }

  /// PUT /bookings/:id/decline
  ///
  /// Handyman declines a pending booking.
  /// [reason] is optional -- defaults to "Not available" on the backend.
  Future<bool> declineBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _api.bookingDio.put(
        '/api/bookings/$bookingId/decline',
        data: reason != null ? {'reason': reason} : {},
      );
      final ok = response.statusCode == 200 && response.data['success'] == true;
      if (ok) await _cache.invalidateBookingCaches();
      return ok;
    } on DioException catch (e) {
      _logError('declineBooking', e);
      return false;
    }
  }

  /// PUT /bookings/:id/start
  ///
  /// Handyman marks a confirmed booking as in-progress.
  Future<bool> startBooking(String bookingId) async {
    try {
      final response = await _api.bookingDio.put('/api/bookings/$bookingId/start');
      final ok = response.statusCode == 200 && response.data['success'] == true;
      if (ok) await _cache.invalidateBookingCaches();
      return ok;
    } on DioException catch (e) {
      _logError('startBooking', e);
      return false;
    }
  }

  /// PUT /bookings/:id/complete
  ///
  /// Handyman marks an in-progress booking as complete.
  /// Backend automatically increments completedJobs + totalEarnings.
  Future<bool> completeBooking(String bookingId) async {
    try {
      final response = await _api.bookingDio.put('/api/bookings/$bookingId/complete');
      final ok = response.statusCode == 200 && response.data['success'] == true;
      if (ok) await _cache.invalidateBookingCaches();
      return ok;
    } on DioException catch (e) {
      _logError('completeBooking', e);
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // CANCEL (client)
  // ─────────────────────────────────────────────

  /// PUT /bookings/:id/cancel
  ///
  /// Client cancels a booking (pending or confirmed only).
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _api.bookingDio.put(
        '/api/bookings/$bookingId/cancel',
        data: reason != null ? {'reason': reason} : {},
      );
      final ok = response.statusCode == 200 && response.data['success'] == true;
      if (ok) await _cache.invalidateBookingCaches();
      return ok;
    } on DioException catch (e) {
      _logError('cancelBooking', e);
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────

  /// PUT /bookings/notifications/:id/read
  ///
  /// Mark a single notification as read.
  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await _api.bookingDio.put(
        '/api/bookings/notifications/$notificationId/read',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logError('markNotificationRead', e);
      return false;
    }
  }

  /// PUT /bookings/notifications/read-all
  ///
  /// Mark all notifications as read for the current user.
  /// Returns the number of notifications updated.
  Future<int> markAllNotificationsRead() async {
    try {
      final response = await _api.bookingDio.put(
        '/api/bookings/notifications/read-all',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return (response.data['updated'] as int?) ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      _logError('markAllNotificationsRead', e);
      return 0;
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────

  void _logError(String method, DioException e) {
    if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (kDebugMode) debugPrint('[BookingsApi] $method');
    if (kDebugMode) debugPrint('   Status : ${e.response?.statusCode}');
    if (kDebugMode) debugPrint('   Message: ${e.message}');
    if (kDebugMode) debugPrint('   Body   : ${e.response?.data}');
    if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
