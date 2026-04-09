import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/call_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Full-screen active call screen.
///
/// [callId]       – Firestore document ID (= Agora channel name)
/// [remoteUid]    – Display UID of the other person
/// [remoteName]   – Name shown on screen
/// [remotePicture]– Optional avatar URL
/// [isCaller]     – true if this user initiated the call
class CallScreen extends StatefulWidget {
  final String callId;
  final String remoteUid;
  final String remoteName;
  final String? remotePicture;
  final bool isCaller;
  /// Server-side Agora RTC token (null only during development with token-disabled project).
  final String? agoraToken;

  const CallScreen({
    super.key,
    required this.callId,
    required this.remoteUid,
    required this.remoteName,
    this.remotePicture,
    required this.isCaller,
    this.agoraToken,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _callService = CallService();
  late RtcEngine _engine;
  bool _engineReady = false; // guard: true only after initialize()

  bool _joined = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _remoteJoined = false;
  bool _isEnding = false;

  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _ringTimeout;
  StreamSubscription? _callStatusSub;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _watchCallStatus();
    if (widget.isCaller) _startRingTimeout();
  }

  // ─── Agora setup ───────────────────────────────────────────────────────────

  Future<void> _initAgora() async {
    // 1. Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showError('Microphone permission denied');
      return;
    }

    // 2. Create engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(appId: CallService.agoraAppId),
    );
    _engineReady = true;

    // 3. Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _joined = true);
          _startTimer();
          if (kDebugMode) debugPrint('CallScreen: joined ${connection.channelId}');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() => _remoteJoined = true);
          _ringTimeout?.cancel();
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() => _remoteJoined = false);
          _endCall();
        },
        onLeaveChannel: (connection, stats) {},
        onError: (err, msg) {
          if (kDebugMode) debugPrint('CallScreen Agora error [$err]: $msg');
        },
      ),
    );

    // 4. Audio-only call settings
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableAudio();
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // 5. Join the channel using the server-issued token
    await _engine.joinChannel(
      token: widget.agoraToken ?? '',
      channelId: widget.callId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  // ─── Call status watcher ───────────────────────────────────────────────────

  void _watchCallStatus() {
    _callStatusSub = _callService.watchCall(widget.callId).listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;
      final status = data['status'] as String?;

      if (status == 'ended' || status == 'rejected' || status == 'missed') {
        if (!_isEnding) _leaveAndPop(status ?? 'ended');
      }
    });
  }

  // ─── Ring timeout (caller side) ────────────────────────────────────────────

  void _startRingTimeout() {
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (!_remoteJoined) {
        _callService.markMissed(widget.callId);
        _leaveAndPop('missed');
      }
    });
  }

  // ─── Call timer ────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _toggleMute() {
    if (!_engineReady) return;
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    if (!_engineReady) return;
    setState(() => _speakerOn = !_speakerOn);
    _engine.setEnableSpeakerphone(_speakerOn);
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    await _callService.endCall(widget.callId);
    _leaveAndPop('ended');
  }

  Future<void> _leaveAndPop(String reason) async {
    _timer?.cancel();
    _ringTimeout?.cancel();
    _callStatusSub?.cancel();
    if (_engineReady) {
      _engineReady = false; // prevent double-release
      await _engine.leaveChannel();
      await _engine.release();
    }
    if (mounted) {
      Navigator.of(context).pop(reason);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _timer?.cancel();
    _ringTimeout?.cancel();
    _callStatusSub?.cancel();
    // Only release if _leaveAndPop() hasn't already done it
    if (_engineReady) {
      _engineReady = false;
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildAvatar(),
            const SizedBox(height: 20),
            _buildName(),
            const SizedBox(height: 8),
            _buildStatus(),
            const Spacer(),
            _buildControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Text(
            'Voice Call',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_joined && _remoteJoined)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _elapsedLabel,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, AppColors.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      child: widget.remotePicture != null && widget.remotePicture!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                widget.remotePicture!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarInitial(),
              ),
            )
          : _avatarInitial(),
    );
  }

  Widget _avatarInitial() {
    final initial = widget.remoteName.isNotEmpty
        ? widget.remoteName[0].toUpperCase()
        : 'H';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 52,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildName() {
    return Text(
      widget.remoteName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatus() {
    String label;
    Color color;

    if (!_joined) {
      label = 'Connecting…';
      color = Colors.white54;
    } else if (!_remoteJoined) {
      label = widget.isCaller ? 'Ringing…' : 'Waiting…';
      color = Colors.white54;
    } else {
      label = 'Connected';
      color = Colors.greenAccent;
    }

    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          icon: _muted ? FontAwesomeIcons.microphoneSlash : FontAwesomeIcons.microphone,
          label: _muted ? 'Unmute' : 'Mute',
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          iconColor: _muted ? AppColors.accentOrange : Colors.white,
          onTap: _toggleMute,
        ),
        const SizedBox(width: 24),
        // End call — large red button
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.phoneSlash,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _controlButton(
          icon: _speakerOn ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeXmark,
          label: _speakerOn ? 'Speaker' : 'Earpiece',
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          iconColor: _speakerOn ? AppColors.primaryColor : Colors.white,
          onTap: _toggleSpeaker,
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
            ),
            child: Center(child: FaIcon(icon, color: iconColor, size: 22)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
