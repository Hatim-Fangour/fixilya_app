import 'dart:async';

import 'package:fixilya_app/features/call/presentation/screens/incoming_call_screen.dart';
import 'package:fixilya_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Wrap the handyman home scaffold with this widget so incoming calls are
/// intercepted app-wide and the IncomingCallScreen is shown automatically.
///
/// Usage (in HandymanHomePage or a root widget for handyman role):
/// ```dart
/// CallListener(child: YourScreen())
/// ```
class CallListener extends StatefulWidget {
  final Widget child;

  const CallListener({super.key, required this.child});

  @override
  State<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends State<CallListener> {
  final _callService = CallService();
  StreamSubscription? _sub;
  bool _isShowingCall = false;
  String? _activeCallId;

  @override
  void initState() {
    super.initState();
    // Only listen when a user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _listen();
  }

  void _listen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[CallListener] Listening for incoming calls for uid=$uid');

    _sub = _callService.watchIncomingCalls().listen(
      (snapshot) {
        debugPrint('[CallListener] Snapshot received: ${snapshot.docs.length} docs');
        if (snapshot.docs.isEmpty) return;
        final doc = snapshot.docs.first;
        final callId = doc.id;

        // Avoid re-triggering for the same call
        if (_isShowingCall || callId == _activeCallId) return;

        final data = doc.data();
        final callerName = data['callerName'] as String? ?? 'Someone';
        final callerPicture = data['callerPicture'] as String?;

        debugPrint('[CallListener] Incoming call! callId=$callId from=$callerName');

        _activeCallId = callId;
        _isShowingCall = true;

        _showIncomingCall(
          callId: callId,
          callerName: callerName,
          callerPicture: callerPicture,
        );
      },
      onError: (e) {
        debugPrint('[CallListener] Stream error: $e');
      },
    );
  }

  Future<void> _showIncomingCall({
    required String callId,
    required String callerName,
    String? callerPicture,
  }) async {
    debugPrint('[CallListener] Showing IncomingCallScreen for callId=$callId');
    try {
      await Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => IncomingCallScreen(
            callId: callId,
            callerName: callerName,
            callerPicture: callerPicture,
          ),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
    } catch (e) {
      debugPrint('[CallListener] Navigation error: $e');
    }
    _isShowingCall = false;
    // Keep _activeCallId so we don't re-trigger the same call
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
