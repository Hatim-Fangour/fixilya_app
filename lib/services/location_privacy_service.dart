import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LocationPrivacyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Handyman privacy ───────────────────────────────────────────────────────

  /// Returns the handyman's location privacy setting.
  /// Defaults to 'city_only' if not set.
  Future<String> getHandymanPrivacy(String uid) async {
    try {
      final doc = await _firestore.collection('handymen').doc(uid).get();
      return (doc.data()?['locationPrivacy'] as String?) ?? 'city_only';
    } catch (e) {
      if (kDebugMode) debugPrint('LocationPrivacyService: getHandymanPrivacy error: $e');
      return 'city_only';
    }
  }

  /// Updates the handyman's location privacy setting.
  Future<void> setHandymanPrivacy(String uid, String privacy) async {
    try {
      await _firestore.collection('handymen').doc(uid).update({
        'locationPrivacy': privacy,
      });
      if (kDebugMode) debugPrint('LocationPrivacyService: set privacy=$privacy for uid=$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('LocationPrivacyService: setHandymanPrivacy error: $e');
      rethrow;
    }
  }

  // ─── Client share preference ─────────────────────────────────────────────

  /// Returns whether the client has opted in to sharing their location on bookings.
  /// Defaults to false.
  Future<bool> getClientSharePreference(String uid) async {
    try {
      final doc = await _firestore.collection('clients').doc(uid).get();
      return (doc.data()?['shareLocationOnBooking'] as bool?) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('LocationPrivacyService: getClientSharePreference error: $e');
      return false;
    }
  }

  /// Updates the client's location-sharing preference.
  Future<void> setClientSharePreference(String uid, bool share) async {
    try {
      await _firestore.collection('clients').doc(uid).update({
        'shareLocationOnBooking': share,
      });
      if (kDebugMode) debugPrint('LocationPrivacyService: set shareLocationOnBooking=$share for uid=$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('LocationPrivacyService: setClientSharePreference error: $e');
      rethrow;
    }
  }

  // ─── Booking location reads ──────────────────────────────────────────────

  /// Returns the handyman's location attached to a booking, or null if not set.
  Future<Map<String, double>?> getBookingHandymanLocation(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      final data = doc.data();
      if (data == null) return null;
      final lat = (data['handymanLatitude'] as num?)?.toDouble();
      final lon = (data['handymanLongitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return {'latitude': lat, 'longitude': lon};
    } catch (e) {
      if (kDebugMode) debugPrint('LocationPrivacyService: getBookingHandymanLocation error: $e');
      return null;
    }
  }

  /// Returns the client's location attached to a booking, or null if not set.
  Future<Map<String, double>?> getBookingClientLocation(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      final data = doc.data();
      if (data == null) return null;
      final lat = (data['clientLatitude'] as num?)?.toDouble();
      final lon = (data['clientLongitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return {'latitude': lat, 'longitude': lon};
    } catch (e) {
      if (kDebugMode) debugPrint('LocationPrivacyService: getBookingClientLocation error: $e');
      return null;
    }
  }
}
