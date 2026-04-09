import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Email Notification Service
/// Sends email notifications for booking events
class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ You'll need to set up a Firebase Cloud Function or use a service like SendGrid
  // For now, this will trigger Cloud Functions
  static const String CLOUD_FUNCTION_URL =
      'YOUR_FIREBASE_CLOUD_FUNCTION_URL'; // Replace with your actual Cloud Function URL

  /// Send email when booking is accepted
  Future<bool> sendBookingAcceptedEmail({
    required String clientEmail,
    required String clientName,
    required String handymanName,
    required String service,
    required String scheduledDate,
    required String timeSlot,
    required String bookingId,
  }) async {
    try {
      if (kDebugMode) debugPrint('📧 Sending acceptance email to: $clientEmail');

      // ✅ OPTION 1: Using Firebase Cloud Functions
      final response = await http.post(
        Uri.parse('$CLOUD_FUNCTION_URL/sendBookingAcceptedEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': clientEmail,
          'clientName': clientName,
          'handymanName': handymanName,
          'service': service,
          'scheduledDate': scheduledDate,
          'timeSlot': timeSlot,
          'bookingId': bookingId,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Email sent successfully');

        // Log email in Firestore
        await _logEmailSent(
          recipient: clientEmail,
          type: 'booking_accepted',
          bookingId: bookingId,
        );

        return true;
      } else {
        if (kDebugMode) debugPrint('❌ Email send failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error sending email: $e');
      return false;
    }
  }

  /// Send email when booking is declined
  Future<bool> sendBookingDeclinedEmail({
    required String clientEmail,
    required String clientName,
    required String handymanName,
    required String service,
    required String reason,
    required String bookingId,
  }) async {
    try {
      if (kDebugMode) debugPrint('📧 Sending decline email to: $clientEmail');

      final response = await http.post(
        Uri.parse('$CLOUD_FUNCTION_URL/sendBookingDeclinedEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': clientEmail,
          'clientName': clientName,
          'handymanName': handymanName,
          'service': service,
          'reason': reason,
          'bookingId': bookingId,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Email sent successfully');

        await _logEmailSent(
          recipient: clientEmail,
          type: 'booking_declined',
          bookingId: bookingId,
        );

        return true;
      } else {
        if (kDebugMode) debugPrint('❌ Email send failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error sending email: $e');
      return false;
    }
  }

  /// Send email to handyman for new booking request
  Future<bool> sendNewBookingRequestEmail({
    required String handymanEmail,
    required String handymanName,
    required String clientName,
    required String service,
    required String scheduledDate,
    required String timeSlot,
    required String bookingId,
  }) async {
    try {
      if (kDebugMode) debugPrint('📧 Sending new request email to handyman: $handymanEmail');

      final response = await http.post(
        Uri.parse('$CLOUD_FUNCTION_URL/sendNewBookingRequestEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': handymanEmail,
          'handymanName': handymanName,
          'clientName': clientName,
          'service': service,
          'scheduledDate': scheduledDate,
          'timeSlot': timeSlot,
          'bookingId': bookingId,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Email sent successfully');

        await _logEmailSent(
          recipient: handymanEmail,
          type: 'new_booking_request',
          bookingId: bookingId,
        );

        return true;
      } else {
        if (kDebugMode) debugPrint('❌ Email send failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error sending email: $e');
      return false;
    }
  }

  /// Log email sent to Firestore
  Future<void> _logEmailSent({
    required String recipient,
    required String type,
    required String bookingId,
  }) async {
    try {
      await _firestore.collection('email_logs').add({
        'recipient': recipient,
        'type': type,
        'bookingId': bookingId,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'sent',
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error logging email: $e');
    }
  }
}
