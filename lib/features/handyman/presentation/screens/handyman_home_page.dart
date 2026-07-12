import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/call/presentation/widgets/call_listener.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/bookings_service.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_notifications_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_reviews_page.dart';
import 'package:fixilya_app/services/bookings_api_service.dart';
import 'package:fixilya_app/services/notification_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/features/call/presentation/screens/call_screen.dart';
import 'package:fixilya_app/services/call_service.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';

class HandymanHomePage extends StatefulWidget {
  const HandymanHomePage({super.key});

  @override
  State<HandymanHomePage> createState() => _HandymanHomePageState();
}

class _HandymanHomePageState extends State<HandymanHomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  bool _isAvailable = true;

  // Services
  final _handymanDataService = HandymanApiService();
  final _bookingsService = BookingsService();
  final _api = BookingsApiService();
  final _notificationApi = NotificationApiService();

  bool _isLoadingData = true;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;

  String _handymanName = "Handyman";

  int _activeBookings = 0;
  int _pendingRequests = 0;
  double _rating = 0.0;
  int _totalReviews = 0;

  // Stable Firestore stream references — created once in initState,
  // never recreated on rebuild, so StreamBuilders never reset to waiting.
  late final Stream<List<Map<String, dynamic>>> _activeBookingsStream;
  late final Stream<List<Map<String, dynamic>>> _newRequestsStream;
  late final Stream<List<Map<String, dynamic>>> _declinedBookingsStream;
  late final Stream<List<Map<String, dynamic>>> _recentActivityStream;
  late final Stream<int> _unreadNotificationsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animationController.forward();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final db = FirebaseFirestore.instance;

    _activeBookingsStream = db
        .collection('bookings')
        .where('handymanId', isEqualTo: uid)
        .where('status', whereIn: ['confirmed', 'in_progress'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );

    _newRequestsStream = db
        .collection('bookings')
        .where('handymanId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );

    _declinedBookingsStream = db
        .collection('bookings')
        .where('handymanId', isEqualTo: uid)
        .where('status', isEqualTo: 'declined')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );

    _recentActivityStream = db
        .collection('activity')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );

    _unreadNotificationsStream = db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.length);

    _loadHandymanData();
  }

  Future<void> _callClient(BuildContext context, Map<String, dynamic> booking) async {
    final clientId   = booking['clientId']   as String?;
    final clientName = booking['clientName'] as String? ?? 'Client';

    if (clientId == null || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client information not available')),
      );
      return;
    }

    // Capture root navigator and scaffold messenger BEFORE popping the sheet,
    // so we can use them safely after the sheet's context is deactivated.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger     = ScaffoldMessenger.of(context);

    // Close the detail sheet
    Navigator.of(context).pop();

    // Use rootNavigator for everything after pop (sheet context is dead)
    rootNavigator.push(
      DialogRoute(
        context: rootNavigator.context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      ),
    );

    try {
      final result = await CallService().initiateCall(
        calleeId:   clientId,
        calleeName: clientName,
        callerName: _handymanName,
      );

      rootNavigator.pop(); // dismiss loading

      await rootNavigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId:     result['callId']!,
            remoteUid:  clientId,
            remoteName: clientName,
            isCaller:   true,
            agoraToken: result['token'],
          ),
        ),
      );
    } catch (e) {
      rootNavigator.pop(); // dismiss loading
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not start call. No active booking found.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadHandymanData({bool forceRefresh = false}) async {
    // Data freshness guard — skip if already loaded unless an explicit refresh is requested.
    if (_profileData != null && !forceRefresh) return;
    if (!mounted) return;

    setState(() => _isLoadingData = true);

    try {
      final results = await Future.wait([
        _handymanDataService.getHandymanProfile(),
        _handymanDataService.getHandymanStats(),
      ]);

      if (!mounted) return;

      final profileData = results[0];
      final statsData = results[1];

      setState(() {
        if (profileData != null) {
          _profileData = profileData;
          _handymanName = profileData['fullName'] ?? 'Handyman';
          _isAvailable = profileData['isAvailable'] as bool? ?? true;
        }
        if (statsData != null) {
          _statsData = statsData;
          _activeBookings = statsData['activeBookings'] ?? 0;
          _pendingRequests = statsData['pendingRequests'] ?? 0;
          _rating = (statsData['rating'] ?? 0.0).toDouble();
          _totalReviews = statsData['totalReviews'] ?? 0;
        }
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
    }
  }

  Widget _buildProfileAvatar() {
    final url = _profileData?['profilePicture']?.toString() ?? '';
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          backgroundColor: AppColors.textSecondaryColor(context),
          backgroundImage: imageProvider,
        ),
        placeholder: (context, _) => CircleAvatar(
          backgroundColor: AppColors.surfaceColor(context),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, _, __) => CircleAvatar(
          backgroundColor: AppColors.surfaceColor(context),
          child: Icon(Icons.person, color: AppColors.primaryColor, size: 28),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: AppColors.surfaceColor(context),
      child: Icon(Icons.person, color: AppColors.primaryColor, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    if (_isLoadingData) {
      // if (true) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _buildSkeletonLoading(),
      );
    }

    return CallListener(
      child: Scaffold(
        // floatingActionButton: FloatingActionButton.extended(
        //   onPressed: () {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (context) => BookingDiagnosticTool()),
        //     );
        //   },
        //   icon: Icon(Icons.bug_report),
        //   label: Text('Debug'),
        //   backgroundColor: Colors.orange,
        // ),
        backgroundColor: AppColors.surfaceColor(context),
        body: CustomScrollView(
          slivers: [
            _buildPremiumAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _animationController,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvailabilityCard(),
                      // SizedBox(height: 20),
                      // _buildEarningsSummary(),
                      SizedBox(height: 20),
                      _buildQuickStats(),
                      SizedBox(height: 24),

                      // ACTIVE BOOKINGS
                      _buildSectionHeader(
                        'Active Bookings',
                        Icons.work_outline,
                      ),
                      SizedBox(height: 12),
                      _buildActiveBookingsStream(),

                      SizedBox(height: 24),

                      // NEW REQUESTS
                      _buildSectionHeader(
                        'New Requests',
                        Icons.notifications_active,
                      ),
                      SizedBox(height: 12),
                      _buildNewRequestsStream(),

                      SizedBox(height: 24),

                      // DECLINED BOOKINGS - ✅ ADDED SECTION HEADER
                      _buildSectionHeader(
                        'Declined Bookings',
                        Icons.cancel_outlined,
                      ),
                      SizedBox(height: 12),
                      _buildDeclinedBookingsStream(),

                      SizedBox(height: 24),

                      // RECENT ACTIVITY
                      _buildSectionHeader('Recent Activity', Icons.history),
                      SizedBox(height: 12),
                      _buildRecentActivityStream(),

                      SizedBox(height: 24),

                      // REVIEWS
                      _buildSectionHeader(
                        'Reviews',
                        Icons.star_rounded,
                        trailing: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HandymanReviewsPage(),
                            ),
                          ),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildReviewsPreview(),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // CallListener
  }

  // Keeping all your existing widget methods...
  // (I'll include the complete file below)
  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        // Skeleton AppBar
        SliverAppBar(
          expandedHeight: 180,
          pinned: false,
          elevation: 0,
          backgroundColor: AppColors.surfaceColor(context),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleHeaderGradientThemed(context),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          // Skeleton Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.glassWhite,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Skeleton Welcome Text
                                Container(
                                  width: 100,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.glassWhite,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                SizedBox(height: 6),
                                // Skeleton Name
                                Container(
                                  width: 140,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(
                                      alpha: 0.4,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Skeleton Notification Bell
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.glassWhite,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // Skeleton Rating Badge
                      Container(
                        width: 150,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.glassWhite,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Skeleton Content
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skeleton Availability Card
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.inputFillColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                SizedBox(height: 20),

                // Skeleton Earnings Summary
                // Container(
                //   height: 200,
                //   decoration: BoxDecoration(
                //     gradient: AppColors.subtleGradientThemed(context),
                //     borderRadius: BorderRadius.circular(20),
                //   ),
                // ),
                // SizedBox(height: 20),

                // Skeleton Quick Stats
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.inputFillColor(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.inputFillColor(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Skeleton Section Header
                _buildSkeletonSectionHeader(),
                SizedBox(height: 12),

                // Skeleton Booking Cards
                _buildSkeletonBookingCard(),
                SizedBox(height: 12),
                _buildSkeletonBookingCard(),
                SizedBox(height: 24),

                // Another Section
                _buildSkeletonSectionHeader(),
                SizedBox(height: 12),
                _buildSkeletonBookingCard(),
                SizedBox(height: 12),
                _buildSkeletonBookingCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonSectionHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.inputFillColor(context),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        SizedBox(width: 10),
        Container(
          width: 140,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.inputFillColor(context),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonBookingCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFillColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputFillColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Skeleton Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.inputBorderColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Skeleton Name
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: 6),
                    // Skeleton Service
                    Container(
                      width: 90,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              // Skeleton Status Badge
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.inputBorderColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: AppColors.inputBorderColor(context)),
          SizedBox(height: 12),
          // Skeleton Location
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.inputBorderColor(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBookingsStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _activeBookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading bookings');
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return _buildEmptyActiveBookings();
        }

        return Column(
          children: bookings
              .map((booking) => _buildBookingCard(booking))
              .toList(),
        );
      },
    );
  }

  Widget _buildNewRequestsStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _newRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading requests');
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildEmptyRequests();
        }

        return Column(
          children: requests
              .map((request) => _buildRequestCard(request))
              .toList(),
        );
      },
    );
  }

  Widget _buildDeclinedBookingsStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _declinedBookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading declined bookings');
        }

        final declined = snapshot.data ?? [];

        if (declined.isEmpty) {
          return _buildEmptyDeclined();
        }

        return Column(
          children: declined
              .map((booking) => _buildDeclinedCard(booking))
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentActivityStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _recentActivityStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading activity');
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return _buildEmptyActivity();
        }

        return Column(
          children: activities
              .map((activity) => _buildActivityCard(activity))
              .toList(),
        );
      },
    );
  }

  // All your card builders and other widgets continue below...
  // (Copy the rest from your existing file)

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isInProgress = booking['status'] == 'in_progress';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBookingDetailsSheet(booking),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isInProgress
                  ? AppColors.textPrimaryColor(context)
                  : AppColors.inputFillColor(context),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor(context),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.2),
                          AppColors.secondaryColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.textPrimaryColor(context),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['clientName'] ?? 'Client',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          booking['service'] ?? 'Service',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isInProgress
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking['status'] == 'confirmed'
                          ? 'Scheduled'
                          : 'In Progress',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isInProgress ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1, color: AppColors.dividerColor(context)),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.iconColor(context),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking['location'] ?? 'Location',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ),
                  // Text(
                  //   '${(booking['amount'] ?? 0).toStringAsFixed(0)} DH',
                  //   style: TextStyle(
                  //     fontSize: 16,
                  //     fontWeight: FontWeight.bold,
                  //     color: AppColors.primaryColor,
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final createdAt = request['createdAt'];
    String timeAgo = 'Just now';

    if (createdAt != null) {
      final timestamp = createdAt is DateTime
          ? createdAt
          : (createdAt as Timestamp).toDate();
      final difference = DateTime.now().difference(timestamp);

      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} hours ago';
      } else {
        timeAgo = '${difference.inDays} days ago';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBookingDetailsSheet(request),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inputFillColor(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor(context),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: Colors.orange,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['clientName'] ?? 'Client',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          request['service'] ?? 'Service',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.iconColor(context),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request['location'] ?? 'Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ),
                  // Text(
                  //   '${(request['amount'] ?? 0).toStringAsFixed(0)} DH',
                  //   style: TextStyle(
                  //     fontSize: 15,
                  //     fontWeight: FontWeight.bold,
                  //     color: AppColors.primaryColor,
                  //   ),
                  // ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineRequest(request),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorColor(context),
                        side: BorderSide(color: AppColors.errorColor(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel,
                            color: AppColors.errorColor(context),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text('Decline'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _acceptRequest(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mainButtonColor(context),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Container(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeclinedCard(Map<String, dynamic> booking) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBookingDetailsSheet(booking),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.errorColor(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLightColor(context),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cancel, color: Colors.red, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['clientName'] ?? 'Client',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          booking['service'] ?? 'Service',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor(
                        context,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Declined',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              if ((booking['declineReason'] ?? booking['cancellationReason']) !=
                  null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.grey100Color(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textSecondaryColor(context),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reason: ${booking['declineReason'] ?? booking['cancellationReason']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.textSecondaryColor(context),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      booking['location'] ?? 'Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ),
                  // Text(
                  //   '${(booking['amount'] ?? 0).toStringAsFixed(0)} DH',
                  //   style: TextStyle(
                  //     fontSize: 14,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.grey[700],
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    IconData icon;
    Color color;

    switch (activity['type']) {
      case 'job_completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'payment_received':
        icon = Icons.account_balance_wallet;
        color = Colors.blue;
        break;
      case 'new_review':
        icon = Icons.star;
        color = Colors.amber;
        break;
      case 'booking_accepted':
        icon = Icons.check_circle_outline;
        color = Colors.teal;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    final createdAt = activity['createdAt'];
    String timeAgo = 'Just now';

    if (createdAt != null) {
      final timestamp = createdAt is DateTime
          ? createdAt
          : (createdAt as Timestamp).toDate();
      final difference = DateTime.now().difference(timestamp);

      if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} hours ago';
      } else {
        timeAgo = '${difference.inDays} days ago';
      }
    }

    final bookingId = activity['bookingId'] as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: bookingId != null
            ? () async {
                final doc = await FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(bookingId)
                    .get();
                if (doc.exists && mounted) {
                  _showBookingDetailsSheet({'id': doc.id, ...doc.data()!});
                }
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputFillColor(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title'] ?? 'Activity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      activity['description'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActiveBookings() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorderColor(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 60, color: Colors.green[300]),
          SizedBox(height: 16),
          Text(
            'No Active Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'re all caught up! New bookings will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequests() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorderColor(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 60,
            color: AppColors.iconColor(context),
          ),
          SizedBox(height: 16),
          Text(
            'No New Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'New booking requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeclined() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorderColor(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 60, color: Colors.green[300]),
          SizedBox(height: 16),
          Text(
            'No Declined Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You haven\'t declined any bookings recently.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 60, color: AppColors.iconColor(context)),
          SizedBox(height: 16),
          Text(
            'No Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your recent activities will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red[900])),
          ),
        ],
      ),
    );
  }

  void _acceptRequest(Map<String, dynamic> request) async {
    // Check for scheduling conflict before accepting
    final hasConflict = await _checkScheduleConflict(request);
    if (hasConflict && mounted) {
      final proceed = await _showConflictDialog(request);
      if (proceed != true) return;
    }

    final success = await _api.acceptBooking(request['id']);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Checks if the handyman already has a confirmed booking on the same day
  Future<bool> _checkScheduleConflict(Map<String, dynamic> request) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      // Parse the scheduled date from the request
      final rawDate = request['scheduledDate'];
      DateTime? requestDate;
      if (rawDate is Timestamp) {
        requestDate = rawDate.toDate();
      } else if (rawDate is String) {
        requestDate = DateTime.tryParse(rawDate);
      } else if (rawDate is DateTime) {
        requestDate = rawDate;
      }
      if (requestDate == null) return false;

      // Normalize to day only
      final dayStart = DateTime(requestDate.year, requestDate.month, requestDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // Query confirmed bookings for this handyman on the same day
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('handymanId', isEqualTo: uid)
          .where('status', whereIn: ['confirmed', 'in_progress'])
          .get();

      // Filter by date (Firestore can't do range + whereIn together easily)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final raw = data['scheduledDate'];
        DateTime? existingDate;
        if (raw is Timestamp) existingDate = raw.toDate();
        else if (raw is String) existingDate = DateTime.tryParse(raw);

        if (existingDate != null &&
            existingDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
            existingDate.isBefore(dayEnd)) {
          return true; // conflict found
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking schedule conflict: $e');
      return false;
    }
  }

  /// Shows a warning dialog when there's a scheduling conflict
  Future<bool?> _showConflictDialog(Map<String, dynamic> request) {
    final rawDate = request['scheduledDate'];
    String dateStr = 'this day';
    DateTime? d;
    if (rawDate is Timestamp) d = rawDate.toDate();
    else if (rawDate is String) d = DateTime.tryParse(rawDate);
    else if (rawDate is DateTime) d = rawDate;
    if (d != null) {
      dateStr = '${d.day}/${d.month}/${d.year}';
    }

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

  void _declineRequest(Map<String, dynamic> request) async {
    final success = await _api.declineBooking(request['id']);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request declined'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(dynamic raw) {
    if (raw == null) return 'N/A';
    DateTime dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is String) {
      dt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      return 'N/A';
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showBookingDetailsSheet(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryColor,
                              AppColors.secondaryColor,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.clipboardList,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        booking['service'] ?? 'Booking Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    _buildDetailRow('Client', booking['clientName'] ?? 'N/A'),
                    _buildDetailRow('Service', booking['service'] ?? 'N/A'),
                    _buildDetailRow('Phone', booking['clientPhone'] ?? 'N/A'),
                    _buildDetailRow('Address', booking['address'] ?? 'N/A'),
                    _buildDetailRow('City', booking['city'] ?? 'N/A'),
                    _buildDetailRow('Location', booking['location'] ?? 'N/A'),
                    _buildDetailRow(
                      'Scheduled',
                      _formatTimestamp(
                        booking['scheduledDate'] ?? booking['scheduledAt'],
                      ),
                    ),
                    _buildDetailRow(
                      'Booked At',
                      _formatTimestamp(booking['createdAt']),
                    ),
                    if (booking['acceptedAt'] != null)
                      _buildDetailRow(
                        'Accepted At',
                        _formatTimestamp(booking['acceptedAt']),
                      ),
                    if (booking['declinedAt'] != null)
                      _buildDetailRow(
                        'Declined At',
                        _formatTimestamp(booking['declinedAt']),
                      ),
                    if ((booking['declineReason'] ??
                            booking['cancellationReason']) !=
                        null)
                      _buildDetailRow(
                        'Decline Reason',
                        booking['declineReason'] ??
                            booking['cancellationReason'],
                      ),
                    if (booking['description'] != null &&
                        (booking['description'] as String).isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        booking['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                    // ── Call client (only for active bookings) ────────────
                    if (status == 'confirmed' || status == 'in_progress') ...[
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text(
                            'Call Client',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _callClient(context, booking),
                        ),
                      ),
                    ],
                    // ── Client review (visible once booking is completed) ──
                    if (status == 'completed' && booking['rating'] != null) ...[
                      SizedBox(height: 20),
                      _buildReviewCard(
                        rating: (booking['rating'] as num).toInt(),
                        comment: booking['reviewComment'] as String? ?? '',
                        clientName:
                            booking['clientName'] as String? ?? 'Client',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required int rating,
    required String comment,
    required String clientName,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
              SizedBox(width: 6),
              Text(
                'Review from $clientName',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Colors.amber,
                size: 22,
              ),
            ),
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 13,
                color: Colors.amber.shade900,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Keep all your existing build methods below
  Widget _buildPremiumAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: false,
      elevation: 0,
      backgroundColor: AppColors.surfaceColor(context),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppColors.subtleHeaderGradientThemed(context),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceColor(context),
                            width: 2,
                          ),
                        ),
                        child: _buildProfileAvatar(),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _handymanName,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: _unreadNotificationsStream,
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HandymanNotificationsPage(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceColor(
                                      context,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: AppColors.white,
                                    size: 24,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: TextStyle(
                                          color: AppColors.surfaceColor(
                                            context,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textDisabledColor(
                        context,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '$_rating ($_totalReviews reviews)',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isAvailable
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isAvailable ? Colors.green : Colors.orange).withValues(
              alpha: 0.4,
            ),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isAvailable ? Icons.check_circle : Icons.pause_circle,
              color: _isAvailable ? Colors.green : Colors.orange,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable ? 'You\'re Available' : 'You\'re Unavailable',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _isAvailable
                      ? 'Ready to accept new bookings'
                      : 'Not accepting bookings',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (value) async {
              final success = await _handymanDataService
                  .updateAvailabilityStatus(value);
              if (mounted) {
                setState(() => _isAvailable = value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? 'You\'re now available'
                          : 'You\'re now unavailable',
                    ),
                    backgroundColor: value ? Colors.green : Colors.orange,
                  ),
                );
              }
            },
            activeThumbColor: Theme.of(context).colorScheme.surface,
            activeTrackColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // Widget _buildEarningsSummary() {
  //   return StreamBuilder<Map<String, double>>(
  //     stream: _handymanDataService.streamEarningsData(),
  //     builder: (context, snapshot) {
  //       // Get earnings from stream or use defaults
  //       final earnings =
  //           snapshot.data ?? {'today': 0.0, 'week': 0.0, 'month': 0.0};

  //       final todayEarnings = earnings['today'] ?? 0.0;
  //       final weekEarnings = earnings['week'] ?? 0.0;
  //       final monthEarnings = earnings['month'] ?? 0.0;

  //       return Container(
  //         padding: EdgeInsets.all(20),
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             begin: Alignment.topLeft,
  //             end: Alignment.bottomRight,
  //             colors: [AppColors.primaryColor, AppColors.secondaryColor],
  //           ),
  //           borderRadius: BorderRadius.circular(20),
  //           boxShadow: [
  //             BoxShadow(
  //               color: AppColors.primaryColor.withValues(alpha: 0.3),
  //               blurRadius: 20,
  //               offset: Offset(0, 10),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(
  //                   Icons.account_balance_wallet,
  //                   color: Colors.white,
  //                   size: 24,
  //                 ),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   'Today\'s Earnings',
  //                   style: TextStyle(
  //                     color: Colors.white.withValues(alpha: 0.9),
  //                     fontSize: 14,
  //                   ),
  //                 ),
  //                 Spacer(),
  //                 // ✅ Loading indicator
  //                 if (snapshot.connectionState == ConnectionState.waiting)
  //                   SizedBox(
  //                     width: 16,
  //                     height: 16,
  //                     child: CircularProgressIndicator(
  //                       strokeWidth: 2,
  //                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
  //                     ),
  //                   ),
  //               ],
  //             ),
  //             SizedBox(height: 12),
  //             Text(
  //               '${todayEarnings.toStringAsFixed(0)} DH',
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 36,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             SizedBox(height: 16),
  //             Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
  //             SizedBox(height: 16),
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'This Week',
  //                         style: TextStyle(
  //                           color: Colors.white.withValues(alpha: 0.8),
  //                           fontSize: 12,
  //                         ),
  //                       ),
  //                       SizedBox(height: 4),
  //                       Text(
  //                         '${weekEarnings.toStringAsFixed(0)} DH',
  //                         style: TextStyle(
  //                           color: Colors.white,
  //                           fontSize: 18,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //                 Container(
  //                   width: 1,
  //                   height: 40,
  //                   color: Colors.white.withValues(alpha: 0.3),
  //                 ),
  //                 SizedBox(width: 16),
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'This Month',
  //                         style: TextStyle(
  //                           color: Colors.white.withValues(alpha: 0.8),
  //                           fontSize: 12,
  //                         ),
  //                       ),
  //                       SizedBox(height: 4),
  //                       Text(
  //                         '${monthEarnings.toStringAsFixed(0)} DH',
  //                         style: TextStyle(
  //                           color: Colors.white,
  //                           fontSize: 18,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildQuickStats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _activeBookingsStream,
      builder: (context, activeSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _newRequestsStream,
          builder: (context, requestsSnapshot) {
            final activeCount = activeSnapshot.data?.length ?? 0;
            final requestsCount = requestsSnapshot.data?.length ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: FontAwesomeIcons.briefcase,
                    value: '$activeCount',
                    label: 'Active Jobs',
                    color: AppColors.primaryColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: FontAwesomeIcons.bellConcierge,
                    value: '$requestsCount',
                    label: 'New Requests',
                    color: AppColors.hardOrange,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(icon, color: color, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsPreview() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('handymanId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Center(
              child: Text(
                'No reviews yet',
                style: TextStyle(
                  color: AppColors.textSecondaryColor(context),
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rating = (data['rating'] as num?)?.toInt() ?? 0;
            final comment = data['comment'] as String? ?? '';
            final clientName = data['clientName'] as String? ?? 'Client';
            final ts = data['createdAt'];
            final date = ts is Timestamp ? _formatTimestamp(ts) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryColor.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          clientName.isNotEmpty
                              ? clientName[0].toUpperCase()
                              : 'C',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            if (date.isNotEmpty)
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryColor(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryColor, AppColors.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.surface,
            size: 18,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
