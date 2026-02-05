// UPDATED HANDYMAN HOME PAGE WITH FIREBASE STREAMS
// Replace your existing handyman_home_page.dart with this

import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/bookings_service.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';

class HandymanHomePage extends StatefulWidget {
  const HandymanHomePage({Key? key}) : super(key: key);

  @override
  State<HandymanHomePage> createState() => _HandymanHomePageState();
}

class _HandymanHomePageState extends State<HandymanHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Premium Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  bool _isAvailable = true;

  // Services
  final _handymanDataService = HandymanDataService();
  final _bookingsService = BookingsService(); // ✅ ADD THIS

  bool _isLoadingData = true;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;

  String _handymanName = "Handyman";
  double _todayEarnings = 0.0;
  int _activeBookings = 0;
  int _pendingRequests = 0;
  double _weeklyEarnings = 0.0;
  double _monthlyEarnings = 0.0;
  double _rating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animationController.forward();
    _loadHandymanData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadHandymanData() async {
    // ✅ Check if widget is still mounted before first setState
    if (!mounted) return;

    setState(() => _isLoadingData = true);

    try {
      print('🔍 Loading handyman data...');

      final profileData = await _handymanDataService.getHandymanProfile();
      final statsData = await _handymanDataService.getHandymanStats();
      final isAvailable = await _handymanDataService.getAvailabilityStatus();

      // ✅ CRITICAL: Check mounted before setState after async operations
      if (!mounted) return;

      if (profileData != null) {
        setState(() {
          _profileData = profileData;
          _statsData = statsData;

          _handymanName = profileData['fullName'] ?? 'Handyman';
          _todayEarnings = (statsData['todayEarnings'] ?? 0.0).toDouble();
          _weeklyEarnings = (statsData['weeklyEarnings'] ?? 0.0).toDouble();
          _monthlyEarnings = (statsData['monthlyEarnings'] ?? 0.0).toDouble();
          _activeBookings = statsData['activeBookings'] ?? 0;
          _pendingRequests = statsData['pendingRequests'] ?? 0;
          _rating = (statsData['rating'] ?? 0.0).toDouble();
          _totalReviews = statsData['totalReviews'] ?? 0;
          _isAvailable = isAvailable;
          _isLoadingData = false;
        });

        print('✅ Handyman data loaded successfully');
      } else {
        print('⚠️ No handyman data found');

        // ✅ Check mounted before setState
        if (!mounted) return;
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      print('❌ Error loading handyman data: $e');

      // ✅ Check mounted before setState
      if (!mounted) return;
      setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
              SizedBox(height: 20),
              Text(
                'Loading dashboard...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                    SizedBox(height: 20),
                    _buildEarningsSummary(),
                    SizedBox(height: 20),
                    _buildQuickStats(),
                    SizedBox(height: 24),

                    // ✅ ACTIVE BOOKINGS - NOW STREAMING FROM FIREBASE
                    _buildSectionHeader('Active Bookings', Icons.work_outline),
                    SizedBox(height: 12),
                    _buildActiveBookingsStream(),

                    SizedBox(height: 24),

                    // ✅ NEW REQUESTS - NOW STREAMING FROM FIREBASE
                    _buildSectionHeader(
                      'New Requests',
                      Icons.notifications_active,
                    ),
                    SizedBox(height: 12),
                    _buildNewRequestsStream(),

                    SizedBox(height: 24),

                    // ✅ RECENT ACTIVITY - NOW STREAMING FROM FIREBASE
                    _buildSectionHeader('Recent Activity', Icons.history),
                    SizedBox(height: 12),
                    _buildRecentActivityStream(),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ✅ NEW: FIREBASE STREAM WIDGETS
  // ============================================

  Widget _buildActiveBookingsStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsService.streamActiveBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
      stream: _bookingsService.streamBookingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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

  Widget _buildRecentActivityStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsService.streamRecentActivity(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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

  // ============================================
  // CARD BUILDERS
  // ============================================

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isInProgress = booking['status'] == 'in_progress';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress
              ? primaryColor.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                      primaryColor.withOpacity(0.2),
                      secondaryColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person, color: primaryColor, size: 20),
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
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      booking['service'] ?? 'Service',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
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
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
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
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Text(
                booking['location'] ?? 'Location',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Spacer(),
              Text(
                '${(booking['amount'] ?? 0).toStringAsFixed(0)} DH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          if (isInProgress) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showMarkCompleteDialog(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Mark as Complete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final createdAt = request['createdAt'];
    String timeAgo = 'Just now';

    if (createdAt != null) {
      final timestamp = (createdAt).toDate();
      final difference = DateTime.now().difference(timestamp);

      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} hours ago';
      } else {
        timeAgo = '${difference.inDays} days ago';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: Colors.orange.withOpacity(0.1),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                request['location'] ?? 'Location',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Spacer(),
              Text(
                '${(request['amount'] ?? 0).toStringAsFixed(0)} DH',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Decline'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Accept'),
                ),
              ),
            ],
          ),
        ],
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
      final timestamp = (createdAt).toDate();
      final difference = DateTime.now().difference(timestamp);

      if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} hours ago';
      } else {
        timeAgo = '${difference.inDays} days ago';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  activity['description'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ============================================
  // EMPTY STATES & ERROR HANDLING
  // ============================================

  Widget _buildEmptyActiveBookings() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'re all caught up! New bookings will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequests() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'No New Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'New booking requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'No Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your recent activities will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

  // ============================================
  // ACTION HANDLERS
  // ============================================

  void _acceptRequest(Map<String, dynamic> request) async {
    final success = await _bookingsService.acceptBooking(request['id']);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _declineRequest(Map<String, dynamic> request) async {
    final success = await _bookingsService.declineBooking(request['id']);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request declined'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMarkCompleteDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete Job?'),
        content: Text('Mark this job as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _bookingsService.completeBooking(
                booking['id'],
              );

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Job completed!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text('Complete'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // KEEP ALL YOUR EXISTING WIDGETS
  // (Premium AppBar, Availability Card, Earnings, etc.)
  // ============================================

  Widget _buildPremiumAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryColor,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor, accentColor],
            ),
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
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child:
                            _profileData != null &&
                                _profileData!['profilePicture'] != null &&
                                _profileData!['profilePicture']
                                    .toString()
                                    .isNotEmpty
                            ? CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                backgroundImage: NetworkImage(
                                  _profileData!['profilePicture'],
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                child: Icon(
                                  Icons.person,
                                  color: primaryColor,
                                  size: 28,
                                ),
                              ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _handymanName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.surface,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification Badge with Stream
                      StreamBuilder<int>(
                        stream: _bookingsService
                            .streamUnreadNotificationsCount(),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withOpacity(0.2),
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
                            color: Theme.of(context).colorScheme.surface,
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
            color: (_isAvailable ? Colors.green : Colors.orange).withOpacity(
              0.4,
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
                    ).colorScheme.surface.withOpacity(0.9),
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
              if (success) {
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
            activeColor: Theme.of(context).colorScheme.surface,
            activeTrackColor: Theme.of(
              context,
            ).colorScheme.surface.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSummary() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.surface,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Today\'s Earnings',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '${_todayEarnings.toStringAsFixed(0)} DH',
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Divider(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
            height: 1,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_weeklyEarnings.toStringAsFixed(0)} DH',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_monthlyEarnings.toStringAsFixed(0)} DH',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsService.streamActiveBookings(),
      builder: (context, activeSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _bookingsService.streamBookingRequests(),
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
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: FontAwesomeIcons.bellConcierge,
                    value: '$requestsCount',
                    label: 'New Requests',
                    color: Colors.orange,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              color: color.withOpacity(0.1),
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
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.surface,
            size: 18,
          ),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
