import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/bookings_api_service.dart';
import 'package:fixilya_app/services/bookings_realtime_service.dart';
import 'package:fixilya_app/services/notification_api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class HandymanNotificationsPage extends StatefulWidget {
  const HandymanNotificationsPage({super.key});

  @override
  State<HandymanNotificationsPage> createState() =>
      _HandymanNotificationsPageState();
}

class _HandymanNotificationsPageState
    extends State<HandymanNotificationsPage>
    with SingleTickerProviderStateMixin {
  // ─────────────────────────────────────────────
  // CONSTANTS
  // ─────────────────────────────────────────────

  static const _primary = Color.fromRGBO(83, 110, 254, 1);
  static const _secondary = Color.fromRGBO(110, 133, 255, 1);
  static const _accent = Color.fromRGBO(147, 167, 255, 1);

  // ─────────────────────────────────────────────
  // SERVICES  — read = realtime, write = API
  // ─────────────────────────────────────────────

  final _stream = BookingsRealtimeService();
  final _api = BookingsApiService();
  final _notificationApi = NotificationApiService();

  // ─────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  /// IDs of notifications currently undergoing an action (accept/decline/read)
  final Set<String> _loadingIds = {};

  // Stable stream references — created once so setState never recreates them
  late final Stream<List<Map<String, dynamic>>> _notificationsStream;
  late final Stream<int> _unreadCountStream;

  @override
  void initState() {
    super.initState();
    _notificationsStream = _stream.streamNotifications();
    _unreadCountStream = _stream.streamUnreadCount();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // HELPERS — icons / colors / time
  // ─────────────────────────────────────────────

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_request':
        return FontAwesomeIcons.bellConcierge;
      case 'payment':
        return FontAwesomeIcons.wallet;
      case 'reminder':
        return FontAwesomeIcons.clock;
      case 'review':
        return FontAwesomeIcons.star;
      case 'confirmed':
      case 'booking_created':
        return FontAwesomeIcons.circleCheck;
      case 'cancelled':
      case 'booking_declined':
        return FontAwesomeIcons.circleXmark;
      case 'job_started':
        return FontAwesomeIcons.screwdriverWrench;
      case 'job_completed':
        return FontAwesomeIcons.trophy;
      case 'system':
        return FontAwesomeIcons.circleInfo;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'new_request':
        return const Color(0xFFF97316); // orange
      case 'payment':
        return const Color(0xFF22C55E); // green
      case 'reminder':
        return const Color(0xFF3B82F6); // blue
      case 'review':
        return const Color(0xFFF59E0B); // amber
      case 'confirmed':
      case 'booking_created':
        return const Color(0xFF14B8A6); // teal
      case 'cancelled':
      case 'booking_declined':
        return const Color(0xFFEF4444); // red
      case 'job_started':
        return const Color(0xFF8B5CF6); // violet
      case 'job_completed':
        return const Color(0xFF10B981); // emerald
      default:
        return _primary;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatDate(ts.toDate());
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  // ─────────────────────────────────────────────
  // GROUP NOTIFICATIONS BY DAY
  // ─────────────────────────────────────────────

  Map<String, List<Map<String, dynamic>>> _groupByDay(
      List<Map<String, dynamic>> items) {
    final today = DateTime.now();
    final Map<String, List<Map<String, dynamic>>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final item in items) {
      final ts = item['createdAt'] as Timestamp?;
      if (ts == null) {
        groups['Earlier']!.add(item);
        continue;
      }
      final d = ts.toDate();
      final diff = today.difference(d).inDays;
      if (diff == 0) {
        groups['Today']!.add(item);
      } else if (diff == 1) {
        groups['Yesterday']!.add(item);
      } else {
        groups['Earlier']!.add(item);
      }
    }

    // Remove empty groups
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  // ─────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────

  Future<void> _markRead(String notifId) async {
    if (_loadingIds.contains(notifId)) return;
    setState(() => _loadingIds.add(notifId));
    await _notificationApi.markAsRead(notifId);
    if (mounted) setState(() => _loadingIds.remove(notifId));
  }

  Future<void> _markAllRead() async {
    await _notificationApi.markAllAsRead();
    final count = 1; // success
    if (mounted) {
      Get.snackbar(
        'Done',
        count > 0 ? '$count notifications marked as read' : 'Already up to date',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _accept(String bookingId, String notifId) async {
    if (_loadingIds.contains(bookingId)) return;

    // Check for scheduling conflict before accepting
    final hasConflict = await _checkScheduleConflict(bookingId);
    if (hasConflict && mounted) {
      final proceed = await _showConflictDialog(bookingId);
      if (proceed != true) return;
    }

    setState(() => _loadingIds.add(bookingId));

    final ok = await _api.acceptBooking(bookingId);
    // Mark notification as read regardless of accept result
    await _notificationApi.markAsRead(notifId);

    if (mounted) {
      setState(() => _loadingIds.remove(bookingId));
      Get.snackbar(
        ok ? 'Accepted! 🎉' : 'Error',
        ok ? 'Booking confirmed successfully' : 'Failed to accept booking',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ok ? AppColors.green : Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        icon: Icon(
          ok ? Icons.check_circle_rounded : Icons.error_outline,
          color: Colors.white,
        ),
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _decline(String bookingId, String notifId) async {
    if (_loadingIds.contains(bookingId)) return;

    // Ask for optional reason
    final reason = await _showDeclineReasonSheet();
    if (reason == null) return; // user dismissed

    setState(() => _loadingIds.add(bookingId));
    final ok = await _api.declineBooking(bookingId, reason: reason.isEmpty ? null : reason);
    await _notificationApi.markAsRead(notifId);

    if (mounted) {
      setState(() => _loadingIds.remove(bookingId));
      Get.snackbar(
        ok ? 'Declined' : 'Error',
        ok ? 'Booking has been declined' : 'Failed to decline booking',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ok ? Colors.orange : Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Checks if the handyman already has a confirmed booking on the same day
  Future<bool> _checkScheduleConflict(String bookingId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      // Fetch the booking being accepted to get its date
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) return false;

      final rawDate = bookingDoc.data()?['scheduledDate'];
      DateTime? requestDate;
      if (rawDate is Timestamp) requestDate = rawDate.toDate();
      else if (rawDate is String) requestDate = DateTime.tryParse(rawDate);
      if (requestDate == null) return false;

      final dayStart = DateTime(requestDate.year, requestDate.month, requestDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // Query confirmed bookings for this handyman
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('handymanId', isEqualTo: uid)
          .where('status', whereIn: ['confirmed', 'in_progress'])
          .get();

      for (final doc in snapshot.docs) {
        if (doc.id == bookingId) continue; // skip the booking being accepted
        final raw = doc.data()['scheduledDate'];
        DateTime? d;
        if (raw is Timestamp) d = raw.toDate();
        else if (raw is String) d = DateTime.tryParse(raw);
        if (d != null && !d.isBefore(dayStart) && d.isBefore(dayEnd)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking schedule conflict: $e');
      return false;
    }
  }

  Future<bool?> _showConflictDialog(String bookingId) async {
    // Fetch date for display
    String dateStr = 'this day';
    try {
      final doc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
      final raw = doc.data()?['scheduledDate'];
      DateTime? d;
      if (raw is Timestamp) d = raw.toDate();
      else if (raw is String) d = DateTime.tryParse(raw);
      if (d != null) dateStr = '${d.day}/${d.month}/${d.year}';
    } catch (_) {}

    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('Schedule Conflict'),
        content: Text(
          'You already have a confirmed appointment on $dateStr.\n\n'
          'Are you sure you want to accept this booking too?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept Anyway'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDeclineReasonSheet() async {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context).withValues(alpha: 0.97),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.dividerColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Decline Booking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optionally provide a reason for the client',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'e.g. Not available on that date...',
                      hintStyle: TextStyle(
                          color: AppColors.textSecondaryColor(context)),
                      filled: true,
                      fillColor: AppColors.surfaceColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: _primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                                color: AppColors.borderColor(context)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, ctrl.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Decline Booking',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // APP BAR  — real-time unread count
  // ─────────────────────────────────────────────

  Widget _buildAppBar() {
    return StreamBuilder<int>(
      stream: _unreadCountStream,
      builder: (context, snap) {
        final unread = snap.data ?? 0;

        return SliverAppBar(
          expandedHeight: 170,
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.pagesAppBar(context),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          actions: [
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.done_all_rounded,
                      color: Colors.white, size: 18),
                  label: const Text(
                    'Mark all read',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: AppColors.appHeaderGradientThemed(context),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    right: -30,
                    top: -20,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 60,
                    bottom: -40,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  // Content
                  Positioned.fill(
                    child: SafeArea(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 56, 24, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Icon badge
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const FaIcon(
                                        FontAwesomeIcons.bell,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      if (unread > 0)
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFF4757),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                unread > 9 ? '9+' : '$unread',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Notifications',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: Text(
                                          unread == 0
                                              ? 'All caught up ✓'
                                              : '$unread unread message${unread > 1 ? 's' : ''}',
                                          key: ValueKey(unread),
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // BODY — streaming notifications list
  // ─────────────────────────────────────────────

  Widget _buildBody() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 400,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(_primary),
                strokeWidth: 3,
              ),
            ),
          );
        }

        if (snap.hasError) {
          return _buildErrorState(snap.error.toString());
        }

        final notifications = snap.data ?? [];

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        final groups = _groupByDay(notifications);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in groups.entries) ...[
                _buildGroupLabel(entry.key),
                const SizedBox(height: 10),
                ...entry.value.map(_buildNotificationCard),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // GROUP LABEL
  // ─────────────────────────────────────────────

  Widget _buildGroupLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _accent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryColor(context),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // NOTIFICATION CARD
  // ─────────────────────────────────────────────

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final id = notif['id'] as String;
    final isRead = notif['read'] as bool? ?? false;
    final type = notif['type'] as String? ?? 'system';
    final bookingId = notif['bookingId'] as String?;
    final color = _colorFor(type);
    final ts = notif['createdAt'] as Timestamp?;

    return Dismissible(
      key: Key(id),
      direction: isRead
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all_rounded, color: _primary, size: 22),
            const SizedBox(height: 4),
            const Text(
              'Mark read',
              style: TextStyle(
                  fontSize: 11,
                  color: _primary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _markRead(id),
      child: GestureDetector(
        onTap: () async {
          if (!isRead) await _markRead(id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isRead
                ? AppColors.cardColor(context)
                : color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? AppColors.borderColor(context)
                  : color.withValues(alpha: 0.25),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor(context).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: isRead ? 0.12 : 0.2),
                            color.withValues(alpha: isRead ? 0.06 : 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: FaIcon(
                          _iconFor(type),
                          color: isRead
                              ? color.withValues(alpha: 0.6)
                              : color,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notif['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color:
                                        AppColors.textPrimaryColor(context),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Unread dot
                              if (!isRead)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            color.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notif['message'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryColor(context),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Time + priority badge
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: AppColors.textDisabledColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _timeAgo(ts),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.textDisabledColor(context),
                                ),
                              ),
                              if ((notif['priority'] ?? '') == 'high') ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.red
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'HIGH',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.red,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Inline action buttons (new requests only) ──
                if (type == 'new_request' && bookingId != null) ...[
                  const SizedBox(height: 14),
                  _buildInlineActions(bookingId: bookingId, notifId: id),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INLINE ACTIONS  — real-time booking status
  // ─────────────────────────────────────────────

  Widget _buildInlineActions({
    required String bookingId,
    required String notifId,
  }) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream.streamBooking(bookingId),
      builder: (context, snap) {
        // Show loader while stream hasn't emitted yet
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
              ),
            ),
          );
        }

        final booking = snap.data;
        final status = booking?['status'] as String? ?? 'pending';

        if (status == 'confirmed') {
          return _buildStatusChip(
            label: 'Accepted',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          );
        }

        if (status == 'declined') {
          return _buildStatusChip(
            label: 'Declined',
            icon: Icons.cancel_rounded,
            color: Colors.red,
          );
        }

        if (status == 'cancelled') {
          return _buildStatusChip(
            label: 'Client Cancelled',
            icon: Icons.remove_circle_rounded,
            color: Colors.orange,
          );
        }

        final isLoading = _loadingIds.contains(bookingId);

        // Still pending — show action buttons
        return Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Row(
            children: [
              // Decline
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _decline(bookingId, notifId),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Accept
              Expanded(
                flex: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isLoading
                        ? null
                        : const LinearGradient(
                            colors: [_primary, _secondary]),
                    color: isLoading ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isLoading
                          ? null
                          : () => _accept(bookingId, notifId),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Accept',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY / ERROR STATES
  // ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return SizedBox(
      height: 420,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primary.withValues(alpha: 0.1),
                        _accent.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _primary.withValues(alpha: 0.2), width: 2),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 52,
                    color: _primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'New booking requests and\nupdates will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 40, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}