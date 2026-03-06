import 'dart:async';

import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/call/presentation/screens/call_screen.dart';
import 'package:fixilya_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Shown on the handyman's device when a client calls.
///
/// The handyman can Accept (green) or Decline (red).
/// After 45 s without a response the call is auto-marked as missed.
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPicture;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPicture,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final _callService = CallService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _missedTimer;
  StreamSubscription? _statusSub;
  bool _responded = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the avatar ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-miss after 45 s
    _missedTimer = Timer(const Duration(seconds: 45), _handleMissed);

    // Watch if caller hung up before we answer
    _statusSub = _callService.watchCall(widget.callId).listen((snap) {
      if (!snap.exists || _responded) return;
      final status = snap.data()?['status'] as String?;
      if (status == 'ended' || status == 'missed') {
        _responded = true;
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _missedTimer?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _accept() async {
    if (_responded) return;
    _responded = true;
    _missedTimer?.cancel();

    // Fetch callee Agora token from server; also transitions call status → active.
    final calleeToken = await _callService.acceptCall(widget.callId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: widget.callId,
          remoteUid: '', // caller's uid — not needed for audio
          remoteName: widget.callerName,
          remotePicture: widget.callerPicture,
          isCaller: false,
          agoraToken: calleeToken,
        ),
      ),
    );
  }

  Future<void> _decline() async {
    if (_responded) return;
    _responded = true;
    _missedTimer?.cancel();
    await _callService.rejectCall(widget.callId);
    if (mounted) Navigator.of(context).pop();
  }

  void _handleMissed() {
    if (_responded || !mounted) return;
    _responded = true;
    _callService.markMissed(widget.callId);
    Navigator.of(context).pop();
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            _buildLabel(),
            const SizedBox(height: 40),
            _buildPulsingAvatar(),
            const SizedBox(height: 24),
            _buildCallerName(),
            const SizedBox(height: 8),
            _buildSubtitle(),
            const Spacer(flex: 3),
            _buildButtons(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel() {
    return const Text(
      'Incoming Call',
      style: TextStyle(
        color: Colors.white54,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPulsingAvatar() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          // Inner avatar
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryColor, AppColors.secondaryColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: widget.callerPicture != null &&
                    widget.callerPicture!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.callerPicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initial(),
                    ),
                  )
                : _initial(),
          ),
        ],
      ),
    );
  }

  Widget _initial() {
    final ch = widget.callerName.isNotEmpty
        ? widget.callerName[0].toUpperCase()
        : 'C';
    return Center(
      child: Text(
        ch,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 52,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCallerName() {
    return Text(
      widget.callerName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Fixilya Client',
      style: TextStyle(
        color: Colors.white54,
        fontSize: 15,
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decline
        _circleButton(
          icon: FontAwesomeIcons.phoneSlash,
          color: Colors.red,
          label: 'Decline',
          onTap: _decline,
        ),
        const SizedBox(width: 60),
        // Accept
        _circleButton(
          icon: FontAwesomeIcons.phone,
          color: Colors.green,
          label: 'Accept',
          onTap: _accept,
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: FaIcon(icon, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
