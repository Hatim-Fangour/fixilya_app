// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage>
    with SingleTickerProviderStateMixin {
  // Luxury Colors
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0A1929);
  static const Color charcoal = Color(0xFF1A2332);
  static const Color softWhite = Color(0xFFFAFAFA);
  static const Color accentRed = Color(0xFFE63946);
  static const Color accentGreen = Color(0xFF06D6A0);
  static const Color accentBlue = Color(0xFF118AB2);
  static const Color accentOrange = Color(0xFFFFB703);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  String? _currentUserId;

  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, suspended

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = _auth.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _isUserAdmin(String userId) async {
    try {
      final adminDoc = await _firestore.collection('admins').doc(userId).get();
      return adminDoc.exists && (adminDoc.data()?['isAdmin'] == true);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: charcoal,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: softWhite),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryGold.withValues(alpha: 0.2),
                  primaryGold.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.people_alt, color: primaryGold, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            'User Management',
            style: TextStyle(
              color: softWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(20),
      child: TextField(
        style: TextStyle(color: softWhite),
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: TextStyle(color: softWhite.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search, color: primaryGold),
          filled: true,
          fillColor: charcoal,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryGold.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryGold, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          SizedBox(width: 12),
          _buildFilterChip('Active', 'active'),
          SizedBox(width: 12),
          _buildFilterChip('Suspended', 'suspended'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;

    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [primaryGold, Color(0xFFFFD700)])
              : null,
          color: isSelected ? null : charcoal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : primaryGold.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? deepNavy : softWhite.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGold.withValues(alpha: 0.2)),
      ),
      child: TabBar(
        // dragStartBehavior: DragStartBehavior.start,
        padding: EdgeInsets.all(1),
        controller: _tabController,
        labelColor: deepNavy,
        unselectedLabelColor: softWhite.withValues(alpha: 0.6),
        // padding: EdgeInsets.all(0),
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [primaryGold, Color(0xFFFFD700)]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: EdgeInsets.symmetric(horizontal: -20, vertical: 6),
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        tabAlignment: TabAlignment.fill,
        tabs: [
          Tab(text: 'HANDYMEN'),
          Tab(text: 'CLIENTS'),
          Tab(text: 'ADMINS'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [_buildHandymenList(), _buildClientsList(), _buildAdminsList()],
    );
  }

  Widget _buildHandymenList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getHandymenStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No handymen found');
        }

        final users = snapshot.data!.docs.where((doc) {
          // Skip current user
          // if (doc.id == _currentUserId) return false;

          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullName'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            return _buildUserCard(user, userId, 'handyman');
          },
        );
      },
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    String userId,
    String userType,
  ) {
    final name = user['fullName'] ?? 'Unknown';
    final email = user['email'] ?? 'No email';
    final city = user['city'] ?? 'Unknown';
    final isSuspended = user['suspended'] ?? false;
    final isApproved = user['approved'] ?? false;
    final profilePicture = user['profilePicture'];

    // ✅ ADD: Check if this is the current user
    // final isCurrentUser = userId == _currentUserId;
    final isCurrentUser = _auth.currentUser?.uid == userId;

    return FutureBuilder<bool>(
      future: _isUserAdmin(userId),
      builder: (context, adminSnapshot) {
        final isAdmin = adminSnapshot.data ?? false;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [charcoal, deepNavy]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSuspended
                  ? accentRed.withValues(alpha: 0.4)
                  : isAdmin
                  ? primaryGold.withValues(alpha: 0.6)
                  : primaryGold.withValues(alpha: 0.3),
              width: isSuspended
                  ? 1.5
                  : isAdmin
                  ? 2
                  : 1,
            ),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Admin indicator on avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage:
                            profilePicture != null &&
                                profilePicture.toString().isNotEmpty
                            ? NetworkImage(profilePicture)
                            : null,
                        backgroundColor: primaryGold.withValues(alpha: 0.2),
                        child:
                            profilePicture == null ||
                                profilePicture.toString().isEmpty
                            ? Icon(Icons.person, color: primaryGold, size: 28)
                            : null,
                      ),
                      // Admin crown badge
                      if (isAdmin)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryGold, Color(0xFFFFD700)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: deepNavy, width: 2),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              size: 12,
                              color: deepNavy,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: softWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // ✅ ADD: "YOU" badge for current user
                            if (isCurrentUser)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accentBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentBlue.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: accentBlue,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            // Admin badge
                            if (isAdmin && !isCurrentUser)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryGold, Color(0xFFFFD700)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      size: 10,
                                      color: deepNavy,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        color: deepNavy,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isSuspended && !isAdmin)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accentRed.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentRed.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'SUSPENDED',
                                  style: TextStyle(
                                    color: accentRed,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (userType == 'handyman' &&
                                !isApproved &&
                                !isSuspended &&
                                !isAdmin)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accentOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentOrange.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'PENDING',
                                  style: TextStyle(
                                    color: accentOrange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: softWhite.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          city,
                          style: TextStyle(
                            color: softWhite.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  // ✅ Suspend/Unsuspend - Disabled for current user
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isCurrentUser
                          ? null // ✅ Disable for current user
                          : () =>
                                _toggleSuspend(userId, userType, !isSuspended),
                      icon: Icon(
                        isSuspended ? Icons.check_circle : Icons.block,
                        size: 16,
                      ),
                      label: Text(
                        isSuspended ? 'Unsuspend' : 'Suspend',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isCurrentUser
                            ? Colors
                                  .grey // ✅ Gray when disabled
                            : (isSuspended ? accentGreen : accentRed),
                        side: BorderSide(
                          color: isCurrentUser
                              ? Colors.grey.withValues(alpha: 0.3)
                              : (isSuspended ? accentGreen : accentRed),
                          width: 1.5,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  // ✅ Make Admin / Remove Admin - Disabled for current user
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (isCurrentUser && isAdmin)
                          ? null // ✅ Disable "Remove Admin" for yourself
                          : (isAdmin
                                ? () => _removeAdmin(userId, name)
                                : () => _makeAdmin(userId, name, email)),
                      icon: Icon(
                        isAdmin
                            ? Icons.remove_moderator
                            : Icons.admin_panel_settings,
                        size: 16,
                      ),
                      label: Text(
                        isAdmin ? 'Remove Admin' : 'Make Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isCurrentUser && isAdmin)
                            ? Colors
                                  .grey // ✅ Gray when disabled
                            : (isAdmin ? accentRed : primaryGold),
                        foregroundColor: (isCurrentUser && isAdmin)
                            ? Colors.grey.shade400
                            : deepNavy,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              // ✅ ADD: Info message for current user
              if (isCurrentUser && isAdmin) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: accentBlue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cannot remove your own admin privileges',
                          style: TextStyle(
                            fontSize: 11,
                            color: softWhite.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getClientsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No clients found');
        }

        // ✅ FILTER: Remove current user from list
        final users = snapshot.data!.docs.where((doc) {
          // Skip current user
          // if (doc.id == _currentUserId) return false;

          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullName'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        print("users :$users");

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            return _buildUserCard(user, userId, 'client');
          },
        );
      },
    );
  }

  Widget _buildAdminsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('admins').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No admins found');
        }

        final admins = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: admins.length,
          itemBuilder: (context, index) {
            final admin = admins[index].data() as Map<String, dynamic>;
            final adminId = admins[index].id;
            return _buildAdminCard(admin, adminId);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getHandymenStream() {
    Query query = _firestore.collection('handymen');

    if (_filterStatus == 'active') {
      query = query.where('suspended', isEqualTo: false);
    } else if (_filterStatus == 'suspended') {
      query = query.where('suspended', isEqualTo: true);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> _getClientsStream() {
    Query query = _firestore.collection('clients');

    if (_filterStatus == 'active') {
      query = query.where('suspended', isEqualTo: false);
    } else if (_filterStatus == 'suspended') {
      query = query.where('suspended', isEqualTo: true);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _toggleSuspend(
    String userId,
    String userType,
    bool suspend,
  ) async {
    try {
      final collection = userType == 'handyman' ? 'handymen' : 'clients';

      await _firestore.collection(collection).doc(userId).update({
        'suspended': suspend,
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
        'suspensionReason': suspend ? 'Suspended by admin' : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        suspend ? '🚫 Suspended' : '✅ Unsuspended',
        'User ${suspend ? "suspended" : "unsuspended"} successfully',
        backgroundColor: suspend ? accentRed : accentGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to ${suspend ? "suspend" : "unsuspend"} user',
        backgroundColor: accentRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _makeAdmin(String userId, String name, String email) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: charcoal,
        title: Text(
          'Make Admin',
          style: TextStyle(color: softWhite, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to make $name an admin? They will have full access to the admin dashboard.',
          style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: TextStyle(color: softWhite.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGold,
              foregroundColor: deepNavy,
            ),
            child: Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('admins').doc(userId).set({
        'isAdmin': true,
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
        'permissions': [
          'approve_handymen',
          'suspend_users',
          'view_analytics',
          'manage_bookings',
        ],
      });

      setState(() {}); // ✅ Refresh UI

      Get.snackbar(
        '✅ Success',
        '$name is now an admin',
        backgroundColor: accentGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to make user admin',
        backgroundColor: accentRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _removeAdmin(String adminId, String name) async {
    // ✅ ADD: Prevent removing yourself
    if (adminId == _currentUserId) {
      Get.snackbar(
        '⚠️ Warning',
        'You cannot remove your own admin privileges',
        backgroundColor: accentOrange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
      return; // ✅ Exit early
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: charcoal,
        title: Text(
          'Remove Admin',
          style: TextStyle(color: softWhite, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to remove $name from admins? They will lose all admin privileges.',
          style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: TextStyle(color: softWhite.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentRed,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('admins').doc(adminId).delete();

      setState(() {}); // ✅ Refresh UI

      Get.snackbar(
        '✅ Removed',
        '$name is no longer an admin',
        backgroundColor: accentGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to remove admin',
        backgroundColor: accentRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildAdminCard(Map<String, dynamic> admin, String adminId) {
    final name = admin['name'] ?? 'Unknown';
    final email = admin['email'] ?? 'No email';
    final isCurrentUser = _auth.currentUser?.uid == adminId;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGold, Color(0xFFFFD700)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.admin_panel_settings, color: deepNavy, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: softWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accentBlue.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            color: accentBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: softWhite.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrentUser)
            IconButton(
              icon: Icon(Icons.delete_outline, color: accentRed),
              onPressed: () => _removeAdmin(adminId, name),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: primaryGold.withValues(alpha: 0.5),
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: softWhite.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Future<void> _toggleSuspend(
  //   String userId,
  //   String userType,
  //   bool suspend,
  // ) async {
  //   try {
  //     final collection = userType == 'handyman' ? 'handymen' : 'clients';

  //     await _firestore.collection(collection).doc(userId).update({
  //       'suspended': suspend,
  //       'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
  //       'suspensionReason': suspend ? 'Suspended by admin' : null,
  //       'updatedAt': FieldValue.serverTimestamp(),
  //     });

  //     Get.snackbar(
  //       suspend ? '🚫 Suspended' : '✅ Unsuspended',
  //       'User ${suspend ? "suspended" : "unsuspended"} successfully',
  //       backgroundColor: suspend ? accentRed : accentGreen,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //       margin: EdgeInsets.all(16),
  //       borderRadius: 12,
  //     );
  //   } catch (e) {
  //     Get.snackbar(
  //       '❌ Error',
  //       'Failed to ${suspend ? "suspend" : "unsuspend"} user',
  //       backgroundColor: accentRed,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   }
  // }

  // Future<void> _makeAdmin(String userId, String name, String email) async {
  //   // Confirm dialog
  //   final confirm = await Get.dialog<bool>(
  //     AlertDialog(
  //       backgroundColor: charcoal,
  //       title: Text(
  //         'Make Admin',
  //         style: TextStyle(color: softWhite, fontWeight: FontWeight.w800),
  //       ),
  //       content: Text(
  //         'Are you sure you want to make $name an admin? They will have full access to the admin dashboard.',
  //         style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Get.back(result: false),
  //           child: Text(
  //             'Cancel',
  //             style: TextStyle(color: softWhite.withValues(alpha: 0.6)),
  //           ),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Get.back(result: true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: primaryGold,
  //             foregroundColor: deepNavy,
  //           ),
  //           child: Text(
  //             'Confirm',
  //             style: TextStyle(fontWeight: FontWeight.w700),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirm != true) return;

  //   try {
  //     await _firestore.collection('admins').doc(userId).set({
  //       'isAdmin': true,
  //       'email': email,
  //       'name': name,
  //       'createdAt': FieldValue.serverTimestamp(),
  //       'createdBy': _auth.currentUser?.uid,
  //       'permissions': [
  //         'approve_handymen',
  //         'suspend_users',
  //         'view_analytics',
  //         'manage_bookings',
  //       ],
  //     });

  //     Get.snackbar(
  //       '✅ Success',
  //       '$name is now an admin',
  //       backgroundColor: accentGreen,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //       margin: EdgeInsets.all(16),
  //       borderRadius: 12,
  //     );
  //   } catch (e) {
  //     Get.snackbar(
  //       '❌ Error',
  //       'Failed to make user admin',
  //       backgroundColor: accentRed,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   }
  // }

  // Future<void> _removeAdmin(String adminId, String name) async {
  //   final confirm = await Get.dialog<bool>(
  //     AlertDialog(
  //       backgroundColor: charcoal,
  //       title: Text(
  //         'Remove Admin',
  //         style: TextStyle(color: softWhite, fontWeight: FontWeight.w800),
  //       ),
  //       content: Text(
  //         'Are you sure you want to remove $name from admins? They will lose all admin privileges.',
  //         style: TextStyle(color: softWhite.withValues(alpha: 0.8)),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Get.back(result: false),
  //           child: Text(
  //             'Cancel',
  //             style: TextStyle(color: softWhite.withValues(alpha: 0.6)),
  //           ),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Get.back(result: true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: accentRed,
  //             foregroundColor: Colors.white,
  //           ),
  //           child: Text(
  //             'Remove',
  //             style: TextStyle(fontWeight: FontWeight.w700),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirm != true) return;

  //   try {
  //     await _firestore.collection('admins').doc(adminId).delete();

  //     Get.snackbar(
  //       '✅ Removed',
  //       '$name is no longer an admin',
  //       backgroundColor: accentGreen,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //       margin: EdgeInsets.all(16),
  //       borderRadius: 12,
  //     );
  //   } catch (e) {
  //     Get.snackbar(
  //       '❌ Error',
  //       'Failed to remove admin',
  //       backgroundColor: accentRed,
  //       colorText: Colors.white,
  //       snackPosition: SnackPosition.BOTTOM,
  //     );
  //   }
  // }
}
