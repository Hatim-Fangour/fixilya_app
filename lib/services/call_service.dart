import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/config/app_config.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:flutter/foundation.dart';

void debugLog(String msg) {
  if (kDebugMode) debugPrint('[CallService] $msg');
}

/// Manages call signaling through Firestore + Agora RTC.
///
/// Flow:
///   1. Client presses "Call" → [initiateCall] calls call-service which writes the Firestore doc
///   2. Handyman app listens to /calls with status == 'ringing' for their uid
///   3. Handyman accepts → [acceptCall] fetches callee token from call-service (sets status = 'active')
///   4. Handyman rejects → [rejectCall] sets status = 'rejected'
///   5. Either side hangs up → [endCall] sets status = 'ended'
///
/// The Agora channel name IS the callId, so both sides join the same channel.
/// Tokens are generated server-side — never client-side.
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────
  // AGORA CONFIG
  // ─────────────────────────────────────────────

  /// App ID read from AppConfig (populated via --dart-define in production).
  static String get agoraAppId => AppConfig.agoraAppId;

  // ─────────────────────────────────────────────

  String get _currentUid => _auth.currentUser!.uid;

  /// Creates a call session via call-service.
  ///
  /// The server validates that caller and callee share an active booking,
  /// writes the Firestore call doc, and returns the caller's Agora token.
  ///
  /// Returns `{'callId': String, 'token': String?}`.
  Future<Map<String, String?>> initiateCall({
    required String calleeId,
    required String calleeName,
    required String callerName,
    String? calleePicture,
    String? callerPicture,
  }) async {
    try {
      final response = await ApiClient().callDio.post(
        '/calls/initiate',
        data: {
          'calleeId':      calleeId,
          'calleeName':    calleeName,
          'callerName':    callerName,
          if (calleePicture != null) 'calleePicture': calleePicture,
          if (callerPicture != null) 'callerPicture': callerPicture,
        },
      );
      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return {
          'callId': data['callId'] as String,
          'token':  data['callerToken'] as String?,
        };
      }
      throw Exception('Unexpected response from call-service: ${response.statusCode}');
    } on DioException catch (e) {
      debugLog('initiateCall error: ${e.type} — ${e.response?.data}');
      rethrow;
    }
  }

  /// Fetches the callee's Agora token from call-service (also sets status → active).
  ///
  /// Returns the Agora token string, or null if the request fails.
  Future<String?> acceptCall(String callId) async {
    try {
      final response = await ApiClient().callDio.get('/calls/$callId/accept');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['calleeToken'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugLog('acceptCall error: ${e.type}');
      return null;
    }
  }

  /// Handyman rejects the call.
  Future<void> rejectCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Either side ends the call.
  Future<void> endCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark call as missed (called when ringing timeout expires with no answer).
  Future<void> markMissed(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'missed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream the call document for real-time status updates.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCall(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  /// Stream for incoming calls targeting this user (handyman listening).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingCalls() {
    return _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'ringing')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  /// Fetch a single call document.
  Future<Map<String, dynamic>?> getCall(String callId) async {
    final doc = await _firestore.collection('calls').doc(callId).get();
    return doc.data();
  }
}
