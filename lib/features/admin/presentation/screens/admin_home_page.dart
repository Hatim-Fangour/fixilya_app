import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'admin_data_service.dart'; // ✅ Your service file

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  // Luxury Color Palette
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0A1929);
  static const Color charcoal = Color(0xFF1A2332);
  static const Color softWhite = Color(0xFFFAFAFA);
  static const Color accentRed = Color(0xFFE63946);
  static const Color accentGreen = Color(0xFF06D6A0);
  static const Color accentBlue = Color(0xFF118AB2);

  // final _adminService = AdminDataService();

  late TabController _tabController;
  bool _isLoading = true;

  // Stats
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingHandymen = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load all data in parallel
      await Future.wait([
        _loadStatistics(),
        _loadPendingHandymen(),
        _loadRecentActivity(),
      ]);
    } catch (e) {
      print('Error loading dashboard: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadStatistics() async {
    // TODO: Replace with actual service call
    // final stats = await _adminService.getAppStatistics();

    // Mock data for now
    await Future.delayed(Duration(milliseconds: 500));
    _stats = {
      'totalHandymen': 247,
      'totalClients': 1852,
      'pendingApprovals': 12,
      'activeBookings': 45,
      'completedBookings': 3421,
      'totalRevenue': 125430.50,
    };
  }

  Future<void> _loadPendingHandymen() async {
    // TODO: Replace with actual service call
    // _pendingHandymen = await _adminService.getPendingHandymen();

    await Future.delayed(Duration(milliseconds: 300));
    _pendingHandymen = []; // Mock empty for now
  }

  Future<void> _loadRecentActivity() async {
    // TODO: Replace with actual service call
    // _recentActivity = await _adminService.getAdminActivity();

    await Future.delayed(Duration(milliseconds: 300));
    _recentActivity = []; // Mock empty for now
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      body: _isLoading ? _buildLoadingState() : _buildDashboard(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Loading Dashboard...',
            style: TextStyle(
              color: softWhite,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return CustomScrollView(
      slivers: [
        // Luxury App Bar
        _buildLuxuryAppBar(),

        // Stats Overview
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                _buildWelcomeHeader(),

                SizedBox(height: 32),

                // Stats Cards
                _buildStatsGrid(),

                SizedBox(height: 32),

                // Tabs
                _buildTabBar(),

                SizedBox(height: 24),

                // Tab Content
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
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: charcoal,
      elevation: 0,
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
              // Decorative pattern
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryGold.withOpacity(0.1),
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
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: primaryGold,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Admin Dashboard',
              style: TextStyle(
                color: softWhite,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Notifications
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_outlined, color: softWhite),
              if (_stats['pendingApprovals'] != null &&
                  _stats['pendingApprovals'] > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accentRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_stats['pendingApprovals']}',
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
          onPressed: () {
            // Show notifications
          },
        ),

        // Admin profile
        Padding(
          padding: EdgeInsets.only(right: 16, left: 8),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            color: softWhite.withOpacity(0.7),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Administrator',
          style: TextStyle(
            color: softWhite,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGold, primaryGold.withOpacity(0)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Total Handymen',
          value: '${_stats['totalHandymen'] ?? 0}',
          icon: Icons.handyman_rounded,
          color: accentBlue,
          trend: '+12%',
        ),
        _buildStatCard(
          title: 'Total Clients',
          value: '${_stats['totalClients'] ?? 0}',
          icon: Icons.people_rounded,
          color: accentGreen,
          trend: '+8%',
        ),
        _buildStatCard(
          title: 'Pending Approvals',
          value: '${_stats['pendingApprovals'] ?? 0}',
          icon: Icons.pending_actions_rounded,
          color: Color(0xFFFFB703),
          trend: '',
          urgent: (_stats['pendingApprovals'] ?? 0) > 0,
        ),
        _buildStatCard(
          title: 'Active Bookings',
          value: '${_stats['activeBookings'] ?? 0}',
          icon: Icons.work_history_rounded,
          color: Color(0xFF8338EC),
          trend: '+5%',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    bool urgent = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(20),
        border: urgent
            ? Border.all(color: accentRed.withOpacity(0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (trend.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: accentGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
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
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: softWhite.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: deepNavy,
        unselectedLabelColor: softWhite.withOpacity(0.6),
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [primaryGold, Color(0xFFFFD700)]),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorPadding: EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        isScrollable: true,
        tabs: [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'APPROVALS'),
          Tab(text: 'HANDYMEN'),
          Tab(text: 'CLIENTS'),
          Tab(text: 'ACTIVITY'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      height: 500,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildApprovalsTab(),
          _buildHandymenTab(),
          _buildClientsTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  // Tab 1: Overview
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildRevenueCard(),
          SizedBox(height: 16),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [charcoal, deepNavy],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGold.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money_rounded, color: primaryGold, size: 28),
              SizedBox(width: 12),
              Text(
                'Revenue Overview',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            '\$${(_stats['totalRevenue'] ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              color: primaryGold,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Text(
            'Total Platform Revenue',
            style: TextStyle(color: softWhite.withOpacity(0.6), fontSize: 14),
          ),
          SizedBox(height: 16),
          Divider(color: softWhite.withOpacity(0.1)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRevenueMetric(
                'Completed',
                '${_stats['completedBookings'] ?? 0}',
                Icons.check_circle,
                accentGreen,
              ),
              _buildRevenueMetric(
                'Active',
                '${_stats['activeBookings'] ?? 0}',
                Icons.hourglass_bottom,
                accentBlue,
              ),
              _buildRevenueMetric(
                'Avg. Value',
                '\$${((_stats['totalRevenue'] ?? 0) / (_stats['completedBookings'] ?? 1)).toStringAsFixed(0)}',
                Icons.trending_up,
                primaryGold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: softWhite,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: softWhite.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              color: softWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionChip(
                'View Reports',
                Icons.assessment,
                accentBlue,
                () {},
              ),
              _buildQuickActionChip(
                'Export Data',
                Icons.file_download,
                accentGreen,
                () {},
              ),
              _buildQuickActionChip(
                'Settings',
                Icons.settings,
                Color(0xFF8338EC),
                () {},
              ),
              _buildQuickActionChip(
                'Support',
                Icons.support_agent,
                Color(0xFFFFB703),
                () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: softWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 2: Approvals (Pending Handymen)
  Widget _buildApprovalsTab() {
    if (_pendingHandymen.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: accentGreen, size: 64),
            SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: TextStyle(
                color: softWhite,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No pending approvals at the moment',
              style: TextStyle(color: softWhite.withOpacity(0.6), fontSize: 14),
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
        return _buildPendingHandymanCard(handyman);
      },
    );
  }

  Widget _buildPendingHandymanCard(Map<String, dynamic> handyman) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFB703).withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: handyman['profilePicture'] != null
                    ? NetworkImage(handyman['profilePicture'])
                    : null,
                backgroundColor: primaryGold.withOpacity(0.2),
                child: handyman['profilePicture'] == null
                    ? Icon(Icons.person, color: primaryGold)
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      handyman['fullName'] ?? 'Unknown',
                      style: TextStyle(
                        color: softWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      handyman['city'] ?? 'Unknown City',
                      style: TextStyle(
                        color: softWhite.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (handyman['skills'] as List<dynamic>? ?? [])
                .map((skill) => _buildSkillChip(skill))
                .toList(),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveHandyman(handyman['id']),
                  icon: Icon(Icons.check_circle, size: 20),
                  label: Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectHandyman(handyman['id']),
                  icon: Icon(Icons.cancel, size: 20),
                  label: Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentRed,
                    side: BorderSide(color: accentRed, width: 1.5),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentBlue.withOpacity(0.3), width: 1),
      ),
      child: Text(
        skill,
        style: TextStyle(
          color: accentBlue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Tab 3: Handymen Management
  Widget _buildHandymenTab() {
    return Center(
      child: Text(
        'Handymen Management\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(color: softWhite.withOpacity(0.6), fontSize: 16),
      ),
    );
  }

  // Tab 4: Clients Management
  Widget _buildClientsTab() {
    return Center(
      child: Text(
        'Clients Management\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(color: softWhite.withOpacity(0.6), fontSize: 16),
      ),
    );
  }

  // Tab 5: Activity Log
  Widget _buildActivityTab() {
    return Center(
      child: Text(
        'Activity Log\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(color: softWhite.withOpacity(0.6), fontSize: 16),
      ),
    );
  }

  // Actions
  Future<void> _approveHandyman(String handymanId) async {
    // TODO: Call service
    // await _adminService.approveHandyman(handymanId);

    Get.snackbar(
      'Success',
      'Handyman approved successfully',
      backgroundColor: accentGreen,
      colorText: Colors.white,
    );

    _loadPendingHandymen();
  }

  Future<void> _rejectHandyman(String handymanId) async {
    // TODO: Show rejection reason dialog
    // await _adminService.rejectHandyman(handymanId, reason: 'reason');

    Get.snackbar(
      'Rejected',
      'Handyman application rejected',
      backgroundColor: accentRed,
      colorText: Colors.white,
    );

    _loadPendingHandymen();
  }
}
