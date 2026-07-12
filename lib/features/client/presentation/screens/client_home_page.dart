import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/app_config_service.dart';
import 'package:fixilya_app/features/call/presentation/widgets/call_listener.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/handyman_card.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:fixilya_app/services/notification_api_service.dart';
import 'package:fixilya_app/services/bookings_api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // ─── Services ────────────────────────────────
  final HandymanApiService _handymanService = HandymanApiService();
  final NotificationApiService _notificationApi = NotificationApiService();
  final BookingsApiService _api = BookingsApiService(); // ✅ mutations

  // ─── State ───────────────────────────────────
  List<Map<String, dynamic>> _allHandymen = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  List<String> _cities = GlobalVariables.cities;
  List<Map<String, dynamic>> _availableSkills =
      GlobalVariables.availableSkills;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late final Stream<int> _unreadNotificationsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _unreadNotificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.length);
    _checkIsAdmin();
    _loadHandymen();
    _loadConfig();
  }

  void _loadConfig() {
    AppConfigService().getCities().then((list) {
      if (mounted && list.isNotEmpty) {
        setState(() => _cities = ['All Cities', ...list]);
      }
    });
    AppConfigService().getSkills().then((list) {
      if (mounted && list.isNotEmpty) {
        final allEntry = GlobalVariables.availableSkills.first;
        setState(() => _availableSkills = [allEntry, ...list]);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────

  Future<void> _checkIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Use cached token (false = don't force refresh). Only refreshes if expired.
    final token = await user.getIdTokenResult(false);
    final userType = token.claims?['userType'] as String?;
    if (mounted && userType == 'admin') {
      setState(() => _isAdmin = true);
    }
  }

  Future<void> _loadHandymen() async {
    // Data freshness guard — skip re-fetch if we already have results this session.
    // initState only fires once with IndexedStack, but this guard future-proofs
    // against accidental extra calls (e.g. pull-to-refresh or didChangeDependencies).
    if (_allHandymen.isNotEmpty) return;
    setState(() => _isLoading = true);
    try {
      final handymen = await _handymanService.getAllHandymen();
      if (kDebugMode) debugPrint("Handymen : ${handymen}");

      if (mounted) {
        setState(() {
          _allHandymen = handymen;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ClientHomePage: failed to load handymen: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredHandymen {
    return _allHandymen.where((job) {
      final cityMatch =
          GlobalVariables.selectedCity == 'All Cities' ||
          job['city'] == GlobalVariables.selectedCity;

      bool categoryMatch = GlobalVariables.selectedCategory == 'All Services';
      if (!categoryMatch && job['skills'] is List) {
        categoryMatch = (job['skills'] as List).contains(
          GlobalVariables.selectedCategory,
        );
      }

      bool searchMatch = _searchQuery.isEmpty;
      if (!searchMatch) {
        searchMatch = job['name'].toString().toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
      }

      return cityMatch && categoryMatch && searchMatch;
    }).toList();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return CallListener(
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.dividerColor(context),
            ),
            _buildResultsCount(),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonLoading()
                  : _filteredHandymen.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _filteredHandymen.length,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: HandymanCard(job: _filteredHandymen[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  // ─────────────────────────────────────────────
  // HEADER  — ✅ SSE notification badge
  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.subtleHeaderGradientThemed(context),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Handyman',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppColors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Book professional services',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map shortcut button
                  InkWell(
                    onTap: () => AppRoutes.toHandymenMap(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceColor(
                          context,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  if (_isAdmin) ...[
                    SizedBox(width: 8),
                    InkWell(
                      onTap: () => AppRoutes.toAdmin(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor(context).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_outlined,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(width: 8),
                  // ✅ SSE live notification badge
                  _buildNotificationBadge(),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildSearchBar(),
        ],
      ),
    );
  }

  /// Real-time Firestore stream for unread notification count
  Widget _buildNotificationBadge() {
    return StreamBuilder<int>(
      stream: _unreadNotificationsStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        if (kDebugMode) debugPrint('🔔 Unread notifications count: $count');

        return InkWell(
          onTap: () => AppRoutes.toClientNotifications(),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.none, // ✅ let badge overflow the icon bounds
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -6, // ✅ float outside top-right corner
                  top: -6,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ), // ✅ white ring makes it pop
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
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
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search for services...',
          hintStyle: TextStyle(fontSize: 14),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.primaryColor,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.grey600, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FILTERS
  // ─────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  GlobalVariables.selectedCity = 'All Cities';
                  GlobalVariables.selectedCategory = 'All Services';
                }),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear All',
                  style: TextStyle(fontSize: 12, color: AppColors.primaryColor),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildCityDropdown()),
              SizedBox(width: 10),
              Expanded(child: _buildCategoryDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'City',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
        SizedBox(height: 6),
        Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: DropdownButton<String>(
            value: GlobalVariables.selectedCity,
            isExpanded: true,
            underline: SizedBox(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimaryColor(context),
            ),
            icon: FaIcon(
              FontAwesomeIcons.chevronDown,
              size: 12,
              color: AppColors.grey600,
            ),
            items: _cities.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (v) => setState(() => GlobalVariables.selectedCity = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
        SizedBox(height: 6),
        Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: DropdownButton<String>(
            value: GlobalVariables.selectedCategory,
            isExpanded: true,
            underline: SizedBox(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimaryColor(context),
            ),
            icon: FaIcon(
              FontAwesomeIcons.chevronDown,
              size: 12,
              color: AppColors.grey600,
            ),
            items: _availableSkills.map((cat) {
              return DropdownMenuItem<String>(
                value: cat['name'],
                child: Row(
                  children: [
                    FaIcon(
                      cat['icon'],
                      size: 12,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(cat['name'], overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) =>
                setState(() => GlobalVariables.selectedCategory = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCount() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 16, color: AppColors.primaryColor),
          SizedBox(width: 6),
          Text(
            _isLoading ? 'Loading...' : '${_filteredHandymen.length} Available',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY / SKELETON
  // ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.magnifyingGlass,
            size: 48,
            color: AppColors.grey400,
          ),
          SizedBox(height: 12),
          Text(
            'No handymen found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.grey600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 13, color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _buildSkeletonCard(),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.inputBorderColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorderColor(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorderColor(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderColor(context),
                        borderRadius: BorderRadius.circular(4),
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
}
