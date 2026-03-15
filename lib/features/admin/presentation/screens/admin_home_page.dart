import 'package:flutter/foundation.dart';
// ignore_for_file: depend_on_referenced_packages, unused_local_variable

import 'dart:async';

import 'package:fixilya_app/features/admin/presentation/screens/admin_analytics_page.dart';
import 'package:fixilya_app/features/admin/presentation/screens/admin_config_page.dart';
import 'package:fixilya_app/features/admin/presentation/screens/admin_notifications_page.dart';
import 'package:fixilya_app/features/admin/presentation/screens/admin_user_management_page.dart';
import 'package:fixilya_app/services/admin_data_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/gestures.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with TickerProviderStateMixin {
  // ✨ Luxury Color Palette
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0A1929);
  static const Color charcoal = Color(0xFF1A2332);
  static const Color softWhite = Color(0xFFFAFAFA);
  static const Color accentRed = Color(0xFFE63946);
  static const Color accentGreen = Color(0xFF06D6A0);
  static const Color accentBlue = Color(0xFF118AB2);
  static const Color accentPurple = Color(0xFF8338EC);
  static const Color accentOrange = Color(0xFFFFB703);

  final _adminService = AdminDataService();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isAdmin = true;

  // Stats
  int _totalHandymen = 0;
  int _totalClients = 0;
  int _pendingApprovals = 0;
  int _activeBookings = 0;
  int _completedBookings = 0;
  double _totalRevenue = 0;
  double _approvalRate = 0;
  double _activeRate = 0;

  List<Map<String, dynamic>> _topHandymen = [];
  List<Map<String, dynamic>> _trendingSkills = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _cityDistribution = [];
  Map<String, dynamic> _platformHealth = {};

  // Real-time updates
  Timer? _refreshTimer;
  DateTime? _lastRefresh;

  List<Map<String, dynamic>> _pendingHandymen = [];
  List<Map<String, dynamic>> _allHandymen = [];
  List<Map<String, dynamic>> _allClients = [];
  int _unreadNotificationCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationCountSub;
  String _handymenFilter = 'all';
  String _handymenSearchQuery = '';
  String _clientsSearchQuery = '';

  @override
  void initState() {
    super.initState();

    // ✅ Start auto-refresh every 30 seconds
    _startAutoRefresh();
    _tabController = TabController(length: 6, vsync: this);
    // Defer until after first frame so GetMaterialApp navigator is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdminAccess());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // ✅ Cancel timer
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && _isAdmin && !_isLoading) {
        if (kDebugMode) debugPrint('🔄 Auto-refreshing dashboard data...');
        _loadDashboardData();
      }
    });
  }

  // Future<int> _getPendingNotificationCount() async {
  //   try {
  //     final snapshot = await FirebaseFirestore.instance
  //         .collection('admin_notifications')
  //         .where('read', isEqualTo: false)
  //         .get();

  //     return snapshot.size;
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error getting notification count: $e');
  //     return 0;
  //   }
  // }

  int _calculateHandymanCompletion(Map<String, dynamic> handyman) {
    int completed = 0;
    int total = 8;

    if (handyman['fullName']?.toString().isNotEmpty ?? false) completed++;
    if (handyman['email']?.toString().isNotEmpty ?? false) completed++;
    if (handyman['phone']?.toString().isNotEmpty ?? false) completed++;
    if (handyman['city']?.toString().isNotEmpty ?? false) completed++;
    if (handyman['experience']?.toString().isNotEmpty ?? false) completed++;
    if ((handyman['skills'] as List?)?.isNotEmpty ?? false) completed++;
    if (handyman['profilePicture']?.toString().isNotEmpty ?? false) completed++;
    if ((handyman['workImages'] as List?)?.isNotEmpty ?? false) completed++;

    return (completed / total * 100).round();
  }

  // Helper: Get missing items
  String _getMissingItems(Map<String, dynamic> handyman) {
    List<String> missing = [];

    if (!(handyman['profilePicture']?.toString().isNotEmpty ?? false)) {
      missing.add('Profile Picture');
    }
    if (!((handyman['skills'] as List?)?.isNotEmpty ?? false)) {
      missing.add('Skills');
    }
    if (!(handyman['experience']?.toString().isNotEmpty ?? false)) {
      missing.add('Experience');
    }
    if (!((handyman['workImages'] as List?)?.isNotEmpty ?? false)) {
      missing.add('Portfolio');
    }

    return missing.isEmpty ? 'None' : missing.join(', ');
  }

  /// ✅ Check if current user is admin
  Future<void> _checkAdminAccess() async {
    try {
      final isAdmin = await _adminService.isAdmin();
      // final isAdmin = true;

      if (!isAdmin) {
        // if (kDebugMode) debugPrint('❌ Access denied: User is not admin');
        _showAccessDenied();
        return;
      }

      setState(() => _isAdmin = true);
      await _loadDashboardData();
    } catch (e) {
      // if (kDebugMode) debugPrint('❌ Error checking admin access: $e');
      _showAccessDenied();
    }
  }

  void _showAccessDenied() {
    Get.offAllNamed(AppRoutes.widgetTree);
    Get.snackbar(
      '🚫 Access Denied',
      'You do not have admin privileges',
      backgroundColor: accentRed,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: 4),
      icon: Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
      margin: EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ Load all data in parallel for better performance
      final results = await Future.wait([
        _loadStatistics(),
        _loadPendingHandymen(),
        _adminService.getTopHandymen(limit: 5),
        _adminService.getTrendingSkills(limit: 5),
        _adminService.getRecentActivity(limit: 15),
        _adminService.getCityDistribution(),
        _adminService.getPlatformHealth(),
      ]);

      if (!mounted) return;

      setState(() {
        _topHandymen = results[2] as List<Map<String, dynamic>>;
        _trendingSkills = results[3] as List<Map<String, dynamic>>;
        _recentActivity = results[4] as List<Map<String, dynamic>>;
        _cityDistribution = results[5] as List<Map<String, dynamic>>;
        _platformHealth = results[6] as Map<String, dynamic>;
        _lastRefresh = DateTime.now();
        _isLoading = false; // ✅ Combined with other updates
      });

      // if (kDebugMode) debugPrint('✅ Dashboard loaded successfully');
      // if (kDebugMode) debugPrint('   Top handymen: ${_topHandymen.length}');
      // if (kDebugMode) debugPrint('   Trending skills: ${_trendingSkills.length}');
      // if (kDebugMode) debugPrint('   Recent activities: ${_recentActivity.length}');
    } catch (e) {
      // if (kDebugMode) debugPrint('❌ Error loading dashboard: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _adminService.getAppStatistics();

      setState(() {
        _totalHandymen = stats['totalHandymen'] ?? 0;
        _totalClients = stats['totalClients'] ?? 0;
        _pendingApprovals = stats['pendingApprovals'] ?? 0;
        _activeBookings = stats['activeBookings'] ?? 0;
        _completedBookings = stats['completedBookings'] ?? 0;
        _totalRevenue = (stats['totalRevenue'] ?? 0).toDouble();
        _approvalRate = (stats['approvalRate'] ?? 0).toDouble();
        _activeRate = (stats['activeRate'] ?? 0).toDouble();
      });

      // if (kDebugMode) debugPrint('✅ Statistics loaded successfully');
    } catch (e) {
      // if (kDebugMode) debugPrint('❌ Error loading statistics: $e');
    }
  }

  Future<void> _loadPendingHandymen() async {
    try {
      final pending = await _adminService.getPendingHandymen(limit: 20);

      setState(() {
        _pendingHandymen = pending;
      });

      // if (kDebugMode) debugPrint('✅ Loaded ${_pendingHandymen.length} pending handymen');
    } catch (e) {
      // if (kDebugMode) debugPrint('❌ Error loading pending handymen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: deepNavy,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: deepNavy,
      body: _isLoading
          ? _buildSkeletonLoading()
          : _buildDashboard(), // ✅ Updated
    );
  }

  
  Widget _buildDashboard() {
    return CustomScrollView(
      slivers: [
        _buildLuxuryAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                SizedBox(height: 0),
                _buildStatsGrid(),
                SizedBox(height: 16),
                _buildTabBar(),
                SizedBox(height: 20),
                _buildTabContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: charcoal,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back(),
        tooltip: '', // ✅ Disable tooltip
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [charcoal, deepNavy],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryGold.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryGold.withValues(alpha: 0.2),
                    primaryGold.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryGold.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: primaryGold,
                size: 22,
              ),
            ),
            SizedBox(width: 12),
          ],
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: softWhite,
                size: 24,
              ),
              onPressed: () => Get.to(() => AdminNotificationsPage()),
              tooltip: '', // ✅ Disable tooltip with empty string
            ),
            if (_pendingApprovals > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$_pendingApprovals',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.analytics_outlined, color: softWhite, size: 24),
          onPressed: () => Get.to(() => AdminAnalyticsPage()),
          tooltip: '', // ✅ Disable tooltip with empty string
        ),
        SizedBox(width: 8),
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: primaryGold,
            child: Icon(Icons.person, color: deepNavy, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [charcoal, charcoal.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              color: primaryGold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Administrator',
            style: TextStyle(
              color: softWhite,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: 150,
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGold, Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2,
      children: [
        _buildStatCard(
          title: 'Handymen',
          value: '$_totalHandymen',
          icon: Icons.handyman_rounded,
          color: accentBlue,
          gradient: [accentBlue, accentBlue.withValues(alpha: 0.7)],
        ),
        _buildStatCard(
          title: 'Clients',
          value: '$_totalClients',
          icon: Icons.people_rounded,
          color: accentGreen,
          gradient: [accentGreen, accentGreen.withValues(alpha: 0.7)],
        ),
        _buildStatCard(
          title: 'Pending',
          value: '$_pendingApprovals',
          icon: Icons.pending_actions_rounded,
          color: accentOrange,
          gradient: [accentOrange, Color(0xFFFF9E00)],
          urgent: _pendingApprovals > 0,
        ),
        _buildStatCard(
          title: 'Active Jobs',
          value: '$_activeBookings',
          icon: Icons.work_history_rounded,
          color: accentPurple,
          gradient: [accentPurple, accentPurple.withValues(alpha: 0.7)],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
    bool urgent = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [charcoal, deepNavy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? accentRed.withValues(alpha: 0.6)
              : color.withValues(alpha: 0.3),
          width: urgent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: softWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: softWhite.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGold.withValues(alpha: 0.2), width: 1),
      ),
      child: TabBar(
        dragStartBehavior: DragStartBehavior.start,
        controller: _tabController,
        labelColor: deepNavy,
        unselectedLabelColor: softWhite.withValues(alpha: 0.6),
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [primaryGold, Color(0xFFFFD700)]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: EdgeInsets.symmetric(horizontal: -9, vertical: 6),
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'APPROVALS'),
          Tab(text: 'HANDYMEN'),
          Tab(text: 'CLIENTS'),
          Tab(text: 'ACTIVITY'),
          Tab(text: 'CONFIG'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 700,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildApprovalsTab(),
          _buildHandymenTab(),
          _buildClientsTab(),
          _buildActivityTab(),
          const AdminConfigPage(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last refresh time
          if (_lastRefresh != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: primaryGold),
                  SizedBox(width: 6),
                  Text(
                    'Last updated: ${_formatTimeAgo(_lastRefresh!)}',
                    style: TextStyle(
                      color: softWhite.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 16),

          _buildRevenueCard(),
          SizedBox(height: 16),
          _buildPlatformHealthCard(),
          SizedBox(height: 16),
          _buildTopHandymenCard(),
          SizedBox(height: 16),
          _buildTrendingSkillsCard(),
          SizedBox(height: 16),
          _buildCityDistributionCard(),
          SizedBox(height: 16),
          _buildQuickStats(),
        ],
      ),
    );
  }

  // ✅ PLATFORM HEALTH CARD
  Widget _buildPlatformHealthCard() {
    final activeUsers = _platformHealth['activeUsers24h'] ?? 0;
    final newUsers = _platformHealth['newUsers7d'] ?? 0;
    final completionRate = (_platformHealth['bookingCompletionRate'] ?? 0.0)
        .toDouble();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [charcoal, deepNavy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentGreen.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentGreen, accentGreen.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.health_and_safety,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Platform Health',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildHealthMetric(
                  'Active (24h)',
                  '$activeUsers',
                  accentBlue,
                  Icons.trending_up,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildHealthMetric(
                  'New (7d)',
                  '$newUsers',
                  accentGreen,
                  Icons.person_add,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildHealthMetric(
                  'Complete Rate',
                  '${completionRate.toStringAsFixed(1)}%',
                  primaryGold,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: softWhite,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: softWhite.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ✅ TOP HANDYMEN CARD
  Widget _buildTopHandymenCard() {
    if (_topHandymen.isEmpty) {
      return _buildEmptyCard('No handymen data yet');
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGold, Color(0xFFFFD700)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.emoji_events, color: deepNavy, size: 24),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Top Performers',
                    style: TextStyle(
                      color: softWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Top ${_topHandymen.length}',
                  style: TextStyle(
                    color: primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          ...List.generate(_topHandymen.length, (index) {
            final handyman = _topHandymen[index];
            final rank = index + 1;
            final medal = rank == 1
                ? '🥇'
                : rank == 2
                ? '🥈'
                : rank == 3
                ? '🥉'
                : '$rank';

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rank <= 3
                    ? primaryGold.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rank <= 3
                      ? primaryGold.withValues(alpha: 0.3)
                      : softWhite.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: rank <= 3
                          ? LinearGradient(
                              colors: [primaryGold, Color(0xFFFFD700)],
                            )
                          : null,
                      color: rank > 3 ? charcoal : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        medal,
                        style: TextStyle(
                          fontSize: rank <= 3 ? 20 : 16,
                          fontWeight: FontWeight.w900,
                          color: rank <= 3 ? deepNavy : softWhite,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),

                  // Profile picture
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: handyman['profilePicture'] != null
                        ? NetworkImage(handyman['profilePicture'])
                        : null,
                    backgroundColor: primaryGold.withValues(alpha: 0.2),
                    child: handyman['profilePicture'] == null
                        ? Icon(Icons.person, color: primaryGold)
                        : null,
                  ),
                  SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handyman['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: softWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: softWhite.withValues(alpha: 0.6),
                            ),
                            SizedBox(width: 4),
                            Text(
                              handyman['city'] ?? 'Unknown',
                              style: TextStyle(
                                color: softWhite.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work, size: 14, color: accentGreen),
                          SizedBox(width: 4),
                          Text(
                            '${handyman['completedJobs']}',
                            style: TextStyle(
                              color: accentGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: accentOrange),
                          SizedBox(width: 4),
                          Text(
                            (handyman['rating'] as double).toStringAsFixed(1),
                            style: TextStyle(
                              color: accentOrange,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ✅ TRENDING SKILLS CARD
  Widget _buildTrendingSkillsCard() {
    if (_trendingSkills.isEmpty) {
      return _buildEmptyCard('No skills data yet');
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPurple.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentPurple, accentPurple.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.trending_up, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'Trending Skills',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          ...List.generate(_trendingSkills.length, (index) {
            final skill = _trendingSkills[index];
            final percentage = double.parse(skill['percentage']);

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        skill['name'],
                        style: TextStyle(
                          color: softWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${skill['count']} (${skill['percentage']}%)',
                        style: TextStyle(
                          color: accentPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: softWhite.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(accentPurple),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ✅ CITY DISTRIBUTION CARD
  Widget _buildCityDistributionCard() {
    if (_cityDistribution.isEmpty) {
      return _buildEmptyCard('No city data yet');
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBlue.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentBlue, accentBlue.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.location_city, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'City Distribution',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cityDistribution.take(6).map((city) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16, color: accentBlue),
                    SizedBox(width: 6),
                    Text(
                      city['city'],
                      style: TextStyle(
                        color: softWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${city['count']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ✅ EMPTY STATE HELPER
  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: softWhite.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: softWhite.withValues(alpha: 0.3),
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: softWhite.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ TIME AGO FORMATTER
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildRevenueCard() {
    final avgValue = _completedBookings > 0
        ? _totalRevenue / _completedBookings
        : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [charcoal, deepNavy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGold, Color(0xFFFFD700)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: deepNavy,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Revenue Overview',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            '\$${_totalRevenue.toStringAsFixed(2)}',
            style: TextStyle(
              color: primaryGold,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Text(
            'Total Platform Revenue',
            style: TextStyle(
              color: softWhite.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16),
          Divider(color: softWhite.withValues(alpha: 0.1), thickness: 1),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Completed', '$_completedBookings', accentGreen),
              Container(
                width: 1,
                height: 40,
                color: softWhite.withValues(alpha: 0.1),
              ),
              _buildMetric('Active', '$_activeBookings', accentBlue),
              Container(
                width: 1,
                height: 40,
                color: softWhite.withValues(alpha: 0.1),
              ),
              _buildMetric(
                'Avg Value',
                '\$${avgValue.toStringAsFixed(0)}',
                primaryGold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: softWhite.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.2), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Health',
            style: TextStyle(
              color: softWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          _buildHealthRow(
            'Total Users',
            '${_totalHandymen + _totalClients}',
            accentBlue,
          ),
          _buildHealthRow(
            'Approval Rate',
            '${_approvalRate.toStringAsFixed(1)}%',
            accentGreen,
          ),
          _buildHealthRow(
            'Active Rate',
            '${_activeRate.toStringAsFixed(1)}%',
            accentPurple,
          ),

          SizedBox(height: 16),
          Divider(color: softWhite.withValues(alpha: 0.1)),
          SizedBox(height: 16),

          // NEW: User Management Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => AdminUserManagementPage()),
              icon: Icon(Icons.people_alt, size: 20),
              label: Text(
                'Manage Users',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGold,
                foregroundColor: deepNavy,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: softWhite.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsTab() {
    if (_pendingHandymen.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentGreen.withValues(alpha: 0.2),
                    accentGreen.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: accentGreen,
                size: 60,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'All Caught Up!',
              style: TextStyle(
                color: softWhite,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No pending approvals',
              style: TextStyle(
                color: softWhite.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _pendingHandymen.length,
      itemBuilder: (context, index) {
        final handyman = _pendingHandymen[index];
        return _buildPendingCard(handyman);
      },
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> handyman) {
    final skills = (handyman['skills'] as List<dynamic>?) ?? [];
    final hasProfilePicture =
        handyman['profilePicture'] != null &&
        handyman['profilePicture'].toString().isNotEmpty;
    final hasWorkImages =
        (handyman['workImages'] as List?)?.isNotEmpty ?? false;
    final profileCompletion = _calculateHandymanCompletion(handyman);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentOrange.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentOrange.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentOrange.withValues(alpha: 0.2),
                  accentOrange.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: hasProfilePicture
                          ? NetworkImage(handyman['profilePicture'])
                          : null,
                      backgroundColor: primaryGold.withValues(alpha: 0.2),
                      child: !hasProfilePicture
                          ? Icon(Icons.person, color: primaryGold, size: 32)
                          : null,
                    ),
                    if (!hasProfilePicture)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accentRed,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              handyman['fullName'] ?? 'Unknown',
                              style: TextStyle(
                                color: softWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentOrange, Color(0xFFFF9E00)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: softWhite.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            handyman['city'] ?? 'Unknown City',
                            style: TextStyle(
                              color: softWhite.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: softWhite.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            handyman['phone'] ?? 'No phone',
                            style: TextStyle(
                              color: softWhite.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Profile Completion
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile Completion',
                                style: TextStyle(
                                  color: softWhite.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '$profileCompletion%',
                                style: TextStyle(
                                  color: profileCompletion >= 80
                                      ? accentGreen
                                      : accentOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: profileCompletion / 100,
                              minHeight: 6,
                              backgroundColor: softWhite.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation(
                                profileCompletion >= 80
                                    ? accentGreen
                                    : accentOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skills
                if (skills.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.build, size: 16, color: accentBlue),
                      SizedBox(width: 8),
                      Text(
                        'Skills (${skills.length})',
                        style: TextStyle(
                          color: softWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skills.take(5).map((skill) {
                      final skillName = skill is String
                          ? skill
                          : skill['name'] ?? '';
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accentBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentBlue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          skillName,
                          style: TextStyle(
                            color: accentBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                ],

                // Missing Items Warning
                if (profileCompletion < 100) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: accentRed,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Incomplete Profile',
                                style: TextStyle(
                                  color: accentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _getMissingItems(handyman),
                                style: TextStyle(
                                  color: softWhite.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                // Action Buttons
                Row(
                  children: [
                    // Request Info Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRequestInfoDialog(handyman),
                        icon: Icon(Icons.info_outline, size: 16),
                        label: Text(
                          'Request Info',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentOrange,
                          side: BorderSide(color: accentOrange, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),

                    // Reject Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(handyman),
                        icon: Icon(Icons.cancel, size: 16),
                        label: Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentRed,
                          side: BorderSide(color: accentRed, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),

                    // Approve Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _showApproveDialog(handyman),
                        icon: Icon(Icons.check_circle, size: 18),
                        label: Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGreen,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show Approve Dialog
  void _showApproveDialog(Map<String, dynamic> handyman) {
    final messageController = TextEditingController(
      text: 'Congratulations! Your profile has been approved.',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentGreen, accentGreen.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Approve Handyman',
              style: TextStyle(color: softWhite, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve ${handyman['fullName']}?',
              style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
            ),
            SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              style: TextStyle(color: softWhite),
              decoration: InputDecoration(
                labelText: 'Message to Handyman',
                labelStyle: TextStyle(color: softWhite.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: softWhite.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentGreen, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: softWhite)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();

              final success = await _adminService.approveHandymanWithMessage(
                handyman['id'],
                customMessage: messageController.text,
              );

              if (success) {
                Get.snackbar(
                  '✅ Success',
                  '${handyman['fullName']} approved successfully',
                  backgroundColor: accentGreen,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: EdgeInsets.all(16),
                  borderRadius: 12,
                );
                await _loadDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Approve'),
          ),
        ],
      ),
    );
  }

  // Show Reject Dialog
  void _showRejectDialog(Map<String, dynamic> handyman) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.cancel, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Reject Application',
              style: TextStyle(color: softWhite, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reject ${handyman['fullName']}?',
              style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
            ),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: TextStyle(color: softWhite),
              decoration: InputDecoration(
                labelText: 'Reason for Rejection *',
                labelStyle: TextStyle(color: softWhite.withValues(alpha: 0.6)),
                hintText: 'e.g., Incomplete information, fake documents...',
                hintStyle: TextStyle(color: softWhite.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: softWhite.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentRed, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: softWhite)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                Get.snackbar(
                  'Error',
                  'Please provide a rejection reason',
                  backgroundColor: accentRed,
                  colorText: Colors.white,
                );
                return;
              }

              Get.back();

              final success = await _adminService.rejectHandymanWithReason(
                handyman['id'],
                reason: reasonController.text.trim(),
              );

              if (success) {
                Get.snackbar(
                  'Rejected',
                  '${handyman['fullName']} application rejected',
                  backgroundColor: accentRed,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: EdgeInsets.all(16),
                  borderRadius: 12,
                );
                await _loadDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  // Show Request Info Dialog
  void _showRequestInfoDialog(Map<String, dynamic> handyman) {
    final messageController = TextEditingController();
    final List<String> selectedFields = [];
    final possibleFields = [
      'Profile Picture',
      'Work Images/Portfolio',
      'Skills',
      'Experience Details',
      'Contact Information',
      'City/Location',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: charcoal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Request Information',
                  style: TextStyle(color: softWhite, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request additional info from ${handyman['fullName']}',
                    style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
                  ),
                  SizedBox(height: 16),

                  Text(
                    'Missing Fields:',
                    style: TextStyle(
                      color: softWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),

                  ...possibleFields.map((field) {
                    return CheckboxListTile(
                      value: selectedFields.contains(field),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedFields.add(field);
                          } else {
                            selectedFields.remove(field);
                          }
                        });
                      },
                      title: Text(
                        field,
                        style: TextStyle(color: softWhite, fontSize: 13),
                      ),
                      activeColor: accentOrange,
                      checkColor: Colors.white,
                    );
                  }),

                  SizedBox(height: 16),

                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    style: TextStyle(color: softWhite),
                    decoration: InputDecoration(
                      labelText: 'Additional Message',
                      labelStyle: TextStyle(
                        color: softWhite.withValues(alpha: 0.6),
                      ),
                      hintText:
                          'Provide details about what needs to be updated...',
                      hintStyle: TextStyle(
                        color: softWhite.withValues(alpha: 0.3),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: softWhite.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accentOrange, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel', style: TextStyle(color: softWhite)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (messageController.text.trim().isEmpty &&
                      selectedFields.isEmpty) {
                    Get.snackbar(
                      'Error',
                      'Please select fields or provide a message',
                      backgroundColor: accentRed,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  Get.back();

                  final success = await _adminService.requestMoreInfo(
                    handyman['id'],
                    message: messageController.text.trim(),
                    missingFields: selectedFields,
                  );

                  if (success) {
                    Get.snackbar(
                      '✅ Sent',
                      'Information request sent to ${handyman['fullName']}',
                      backgroundColor: accentOrange,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      margin: EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHandymenTab() {
    return _buildComingSoon('Handymen Management');
  }

  Widget _buildClientsTab() {
    return _buildComingSoon('Clients Management');
  }

  Widget _buildActivityTab() {
    if (_recentActivity.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: softWhite.withValues(alpha: 0.3),
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              'No recent activity',
              style: TextStyle(
                color: softWhite.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _recentActivity.length,
      itemBuilder: (context, index) {
        final activity = _recentActivity[index];
        final timestamp = (activity['timestamp'] as Timestamp?)?.toDate();

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [charcoal, deepNavy]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (activity['color'] as Color).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (activity['color'] as Color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title'],
                      style: TextStyle(
                        color: softWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      activity['description'],
                      style: TextStyle(
                        color: softWhite.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (timestamp != null)
                Text(
                  _formatTimeAgo(timestamp),
                  style: TextStyle(
                    color: softWhite.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComingSoon(String feature) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            color: primaryGold.withValues(alpha: 0.5),
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            feature,
            style: TextStyle(
              color: softWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: softWhite.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        // Skeleton AppBar
        SliverAppBar(
          expandedHeight: 80,
          pinned: true,
          backgroundColor: charcoal,
          elevation: 0,
          leading: IconButton(
            // ✅ Add this to explicitly set back button color
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [charcoal, deepNavy],
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primaryGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            _buildSkeletonCircle(size: 24),
            SizedBox(width: 16),
            _buildSkeletonCircle(size: 24),
            SizedBox(width: 16),
            _buildSkeletonCircle(size: 36),
            SizedBox(width: 16),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skeleton Welcome Header
                _buildSkeletonCard(height: 120),
                SizedBox(height: 24),

                // Skeleton Stats Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2,
                  children: List.generate(
                    4,
                    (index) => _buildSkeletonCard(height: 140),
                  ),
                ),

                SizedBox(height: 24),

                // Skeleton Tab Bar
                _buildSkeletonCard(height: 48),

                SizedBox(height: 20),

                // Skeleton Content
                Column(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: _buildSkeletonCard(height: 120),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            charcoal.withValues(alpha: 0.5),
            charcoal.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _buildShimmerEffect(),
    );
  }

  Widget _buildSkeletonCircle({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: charcoal.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: _buildShimmerEffect(),
    );
  }

  Widget _buildShimmerEffect() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  primaryGold.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
      onEnd: () {
        // Repeat animation
        if (mounted && _isLoading) {
          setState(() {});
        }
      },
    );
  }

  // Future<void> _approveHandyman(String handymanId) async {
  //   try {
  //     final success = await _adminService.approveHandyman(handymanId);

  //     if (success) {
  //       Get.snackbar(
  //         '✅ Success',
  //         'Handyman approved successfully',
  //         backgroundColor: accentGreen,
  //         colorText: Colors.white,
  //         snackPosition: SnackPosition.BOTTOM,
  //         icon: Icon(Icons.check_circle, color: Colors.white),
  //         margin: EdgeInsets.all(16),
  //         borderRadius: 12,
  //       );

  //       await _loadDashboardData();
  //     }
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error approving: $e');
  //     Get.snackbar(
  //       '❌ Error',
  //       'Failed to approve handyman',
  //       backgroundColor: accentRed,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   }
  // }

  // Future<void> _rejectHandyman(String handymanId) async {
  //   try {
  //     final success = await _adminService.rejectHandyman(handymanId);

  //     if (success) {
  //       Get.snackbar(
  //         'Rejected',
  //         'Handyman application rejected',
  //         backgroundColor: accentRed,
  //         colorText: Colors.white,
  //         snackPosition: SnackPosition.BOTTOM,
  //         icon: Icon(Icons.cancel, color: Colors.white),
  //         margin: EdgeInsets.all(16),
  //         borderRadius: 12,
  //       );

  //       await _loadDashboardData();
  //     }
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error rejecting: $e');
  //     Get.snackbar(
  //       '❌ Error',
  //       'Failed to reject handyman',
  //       backgroundColor: accentRed,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   }
  // }
}
