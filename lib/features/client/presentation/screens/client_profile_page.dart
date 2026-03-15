import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// ignore_for_file: depend_on_referenced_packages

import 'dart:ui';
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/admin_data_service.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/client_backend_service.dart'; // ✅ Backend service
import 'package:fixilya_app/services/location_privacy_service.dart';
import 'package:fixilya_app/services/location_service.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/firebase_image_service.dart';
import 'package:fixilya_app/shared/widgets/dropdown_list.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage>
    with TickerProviderStateMixin {
  // ─── Services ───────────────────────────────
  final _clientService = ClientBackendService(); // ✅ CHANGED
  late final CloudinaryService _cloudinaryService;
  late final FirebaseImageService _firebaseImageService;
  bool _isAdmin = false;
  final _adminService = AdminDataService();
  final _locationPrivacyService = LocationPrivacyService();
  final _locationService = LocationService();

  // ─── State ──────────────────────────────────
  bool _isEditing = false;
  int _profileCompletion = 0;
  bool _isLoading = true;
  bool _shareLocationOnBooking = false;

  Map<String, dynamic>? _profileData;

  // Animation
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();

  // Profile fields
  String _name = 'Client';
  String _email = '';
  String _phone = '';
  String _address = '';
  String _profilePicture = '';
  String _clientType = '';
  DateTime? _memberSince;
  String? selectedCity;

  // Stats
  int _totalBookings = 0;
  int _favoriteHandymen = 0;

  // Recent data
  late final Stream<QuerySnapshot> _recentBookingsStream;
  List<Map<String, dynamic>> _favoriteServices = [];

  @override
  void initState() {
    super.initState();

    try {
      _cloudinaryService = Get.find<CloudinaryService>();
      _firebaseImageService = Get.find<FirebaseImageService>();
    } catch (_) {}

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _scaleController.forward();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _recentBookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();

    _loadProfileData();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────

  Future<void> _checkAdminStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final isAdmin = await _adminService.isUserAdmin(currentUser.uid);
      if (mounted) setState(() => _isAdmin = isAdmin);
    } catch (e) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  /// ✅ All data from backend — no direct Firestore reads
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Parallel fetch
      final results = await Future.wait([
        _clientService.getClientProfile(),
        _clientService.getClientStats(),
      ]);

      final profileData = results[0];
      final statsData = results[1];

      if (profileData != null && mounted) {
        setState(() {
          _profileData = profileData;

          _name = profileData['fullName'] ?? 'Client';
          _email = profileData['email'] ?? '';
          _phone = profileData['phone'] ?? '';
          _address = profileData['address'] ?? '';
          _profilePicture = profileData['profilePicture'] ?? '';
          _clientType = _getClientType(profileData['clientType'] ?? '1');
          selectedCity = profileData['city'];

          // createdAt comes as ISO-8601 string from backend
          final raw = profileData['createdAt'];
          if (raw is String) _memberSince = DateTime.tryParse(raw);

          _totalBookings = (statsData?['totalBookings'] ?? 0) as int;
          _favoriteHandymen = (statsData?['favoritesCount'] ?? 0) as int;

          _profileCompletion = _calculateProfileCompletion();
          _isLoading = false;
        });

        // Load secondary data without blocking the main UI
        await Future.wait([
          _loadFavoriteServices(),
          _loadLocationSharePreference(),
        ]);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [_loadProfileData] $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ Backend — favorite handymen → extract service names
  Future<void> _loadFavoriteServices() async {
    try {
      final favorites = await _clientService.getClientFavorites();

      if (mounted) {
        setState(() {
          // Build a unique list of service names from favorite handymen's skills
          final Set<String> seen = {};
          _favoriteServices = [];
          for (final hm in favorites) {
            final skills = (hm['skills'] as List?)?.cast<String>() ?? [];
            for (final s in skills) {
              if (seen.add(s)) {
                _favoriteServices.add({'name': s, 'icon': _getServiceIcon(s)});
              }
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [_loadFavoriteServices] $e');
    }
  }

  Future<void> _loadLocationSharePreference() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final share = await _locationPrivacyService.getClientSharePreference(uid);
      if (mounted) setState(() => _shareLocationOnBooking = share);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [_loadLocationSharePreference] $e');
    }
  }

  /// ✅ Backend — save profile
  Future<void> _saveProfileToFirebase() async {
    try {
      _formKey.currentState!.save();

      final success = await _clientService.updateClientProfile({
        'fullName': _name,
        'email': _email,
        'phone': _phone,
        'city': selectedCity,
        'address': _address,
      });

      if (success) {
        if (mounted) {
          setState(() {
            _profileData = {
              ..._profileData ?? {},
              'fullName': _name,
              'email': _email,
              'phone': _phone,
              'city': selectedCity,
              'address': _address,
            };
            _profileCompletion = _calculateProfileCompletion();
          });
        }

        Get.snackbar(
          '✅ Success',
          'Profile updated successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          icon: Icon(Icons.check_circle, color: Colors.white),
          duration: Duration(seconds: 2),
        );
      } else {
        throw Exception('Update returned false');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update profile: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  // ─────────────────────────────────────────────
  // PROFILE PICTURE UPLOAD  (unchanged — Cloudinary path)
  // ─────────────────────────────────────────────

  Future<void> _pickAndUploadProfilePicture() async {
    try {
      final image = await _cloudinaryService.pickImage();
      if (image == null) return;

      setState(() {});

      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 32),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Uploading profile picture...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final imageUrl = await _cloudinaryService.uploadImage(
        imageFile: image,
        folder: 'profiles',
        publicId: 'profile_${FirebaseAuth.instance.currentUser?.uid}',
        isProfilePicture: true,
        timeoutSeconds: 30,
      );

      if (imageUrl != null) {
        // Persist via backend
        final success = await _clientService.updateClientProfile({
          'profilePicture': imageUrl,
        });

        if (success) {
          if (mounted) {
            setState(() {
              _profilePicture = imageUrl;
              _profileCompletion = _calculateProfileCompletion();
            });
          }
        }

        if (Get.isDialogOpen ?? false) Get.back();

        Get.snackbar(
          '✅ Success',
          'Profile picture updated!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          duration: Duration(seconds: 2),
        );
      } else {
        throw Exception('Upload returned null');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Failed to upload picture: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  int _calculateProfileCompletion() {
    if (_profileData == null) return 0;
    int done = 0;
    const total = 6;
    if (_name.isNotEmpty && _name != 'Client') done++;
    if (_phone.isNotEmpty) done++;
    if (selectedCity != null && selectedCity!.isNotEmpty) done++;
    if (_address.isNotEmpty) done++;
    if (_profilePicture.isNotEmpty) {
      done++;
      done++;
    } // double weight
    return (done / total * 100).round();
  }

  String _getClientType(String code) {
    const types = {
      '1': 'New Client',
      '2': 'Standard Client',
      '3': 'Premium Client',
    };
    return types[code] ?? 'New Client';
  }

  IconData _getServiceIcon(String name) {
    const map = <String, IconData>{
      'Plumbing': FontAwesomeIcons.faucet,
      'Electrical Work': FontAwesomeIcons.bolt,
      'Electricity': FontAwesomeIcons.bolt,
      'Carpentry': FontAwesomeIcons.hammer,
      'Painting': FontAwesomeIcons.paintRoller,
      'Cleaning': FontAwesomeIcons.broom,
      'Gardening': FontAwesomeIcons.seedling,
      'AC Repair': FontAwesomeIcons.snowflake,
      'Appliance Repair': FontAwesomeIcons.plug,
    };
    return map[name] ?? FontAwesomeIcons.wrench;
  }

  /// Accepts ISO-8601 strings (from backend) and Timestamps (legacy)
  String _formatDate(dynamic raw) {
    if (raw == null) return 'N/A';
    try {
      final DateTime date;
      if (raw is DateTime) {
        date = raw;
      } else if (raw is String) {
        date = DateTime.parse(raw);
      } else if (raw is Map) {
        // Firestore Timestamp serialised as {_seconds, _nanoseconds} from REST API
        final seconds = (raw['_seconds'] as num?) ?? (raw['seconds'] as num?);
        if (seconds == null) return 'N/A';
        date = DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      } else {
        // Firestore Timestamp from SDK (cloud_firestore package)
        date = (raw as dynamic).toDate() as DateTime;
      }
      const months = [
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
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '${months[date.month - 1]} ${date.day}, ${date.year} at $h:$m';
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatMemberSince() {
    if (_memberSince == null) return 'Member since Jan 2024';
    const months = [
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
    return 'Member since ${months[_memberSince!.month - 1]} ${_memberSince!.year}';
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
        return Colors.red;
      default:
        return const Color.fromARGB(255, 155, 169, 0);
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: _buildSkeletonLoading(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: false,
            elevation: 0,
            backgroundColor: AppColors.cardColor(context),
            automaticallyImplyLeading: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleHeaderGradientThemed(context),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _CirclePatternPainter()),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40),
                          GestureDetector(
                            onTap: _pickAndUploadProfilePicture,
                            child: Stack(
                              children: [
                                Hero(
                                  tag: 'profile_picture',
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.white.withValues(alpha: 0.5),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: _profilePicture.isNotEmpty
                                        ? CircleAvatar(
                                            radius: 50,
                                            backgroundImage: NetworkImage(
                                              _profilePicture,
                                            ),
                                            backgroundColor: Colors.white,
                                          )
                                        : CircleAvatar(
                                            radius: 50,
                                            backgroundColor: Colors.white,
                                            child: Icon(
                                              Icons.person,
                                              size: 50,
                                              color: AppColors.primaryColor,
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryColor,
                                          AppColors.secondaryColor,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  _clientType,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _formatMemberSince(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Row(
                      children: [
                        _buildGlassButton(
                          icon: Icons.settings,
                          onPressed: () => AppRoutes.toClientSettings(),
                        ),
                        SizedBox(width: 12),
                        if (_isAdmin) ...[
                          _buildGlassButton(
                            icon: Icons.admin_panel_settings,
                            onPressed: () => AppRoutes.toAdmin(),
                          ),
                          SizedBox(width: 12),
                        ],
                        _buildGlassButton(
                          icon: _isEditing ? Icons.check : Icons.edit,
                          onPressed: () async {
                            if (_isEditing) {
                              await _saveProfileToFirebase();
                              setState(() => _isEditing = false);
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCompletionCard(),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => AppRoutes.toClientBookings(),
                              child: _buildPremiumStatCard(
                                icon: FontAwesomeIcons.check,
                                value: '$_totalBookings',
                                label: 'Bookings',
                                gradient: AppColors.blueStateCardGradientThemed(
                                  context,
                                ),
                                iconColor: Color(0xFF2196F3),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => AppRoutes.toFavorites(),
                              child: _buildPremiumStatCard(
                                icon: FontAwesomeIcons.heart,
                                value: '$_favoriteHandymen',
                                label: 'Favorites',
                                gradient: AppColors.roseStateCardGradientThemed(
                                  context,
                                ),
                                iconColor: Color(0xFFE91E63),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      _buildSection(
                        'Personal Information',
                        Icons.person_outline,
                        child: _buildPremiumInfoCard(
                          children: [
                            _buildEditableField(
                              label: 'Full Name',
                              icon: Icons.person,
                              initialValue: _name,
                              onSaved: (v) => _name = v!,
                            ),
                            _buildDivider(),
                            _buildEditableField(
                              label: 'Email',
                              icon: Icons.email_outlined,
                              initialValue: _email,
                              readOnly: true,
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (v) => _email = v!,
                            ),
                            _buildDivider(),
                            _buildEditableField(
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              initialValue: _phone,
                              keyboardType: TextInputType.phone,
                              onSaved: (v) => _phone = v!,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildSection(
                        'Address',
                        Icons.location_on_outlined,
                        child: _buildPremiumInfoCard(
                          children: [
                            _buildEditableField(
                              label: 'Street Address',
                              icon: Icons.home_outlined,
                              initialValue: _address,
                              onSaved: (v) => _address = v!,
                            ),
                            _buildDivider(),
                            GenericDropdown<String>(
                              items: GlobalVariables.cities.skip(1).toList(),
                              value: selectedCity,
                              label: 'City',
                              hint: 'Select your city',
                              itemLabel: (c) => c,
                              onChanged: (v) =>
                                  setState(() => selectedCity = v),
                              validator: (v) =>
                                  v == null ? 'Please select a city' : null,
                              prefixIcon: Icons.location_city_outlined,
                              primaryColor: AppColors.primaryColor,
                              secondaryColor: AppColors.secondaryColor,
                              isEditing: _isEditing,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildLocationSharingCard(),
                      SizedBox(height: 24),
                      if (_favoriteServices.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Favorite Services',
                          Icons.star_outline,
                        ),
                        SizedBox(height: 16),
                        ..._favoriteServices.map((s) => _buildServiceCard(s)),
                        SizedBox(height: 24),
                      ],
                      _buildSectionHeader('Recent Bookings', Icons.history),
                      SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: _recentBookingsStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.primaryColor,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return _buildEmptyState(
                              icon: Icons.receipt_long_outlined,
                              message: 'No bookings yet',
                            );
                          }
                          return Column(
                            children: docs.map((doc) {
                              final b = {
                                'id': doc.id,
                                ...(doc.data() as Map<String, dynamic>),
                              };
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: _buildBookingCard(
                                  handymanName:
                                      b['handymanName'] ?? 'Unknown Handyman',
                                  service: b['service'] ?? 'Service',
                                  date: _formatDate(b['createdAt']),
                                  status: b['status'] ?? 'pending',
                                  statusColor: _getStatusColor(
                                    b['status'] ?? 'pending',
                                  ),
                                  rating: (b['rating'] as num?)?.toDouble(),
                                  onTap: () => _showBookingDetails(b),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      SizedBox(height: 24),
                      _buildSectionHeader(
                        'Quick Actions',
                        Icons.dashboard_outlined,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: FontAwesomeIcons.fileInvoice,
                              label: 'Invoices',
                              color: Color(0xFF2196F3),
                              onTap: () => AppRoutes.toInvoices(),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: FontAwesomeIcons.bell,
                              label: 'Notifications',
                              color: Color(0xFFFF9800),
                              onTap: () => AppRoutes.toClientNotifications(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: FontAwesomeIcons.creditCard,
                              label: 'Payments',
                              color: Color(0xFF4CAF50),
                              onTap: () => AppRoutes.toPayments(),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: FontAwesomeIcons.gear,
                              label: 'Settings',
                              color: Color(0xFF757575),
                              onTap: () => AppRoutes.toClientSettings(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      _buildPremiumLogoutButton(),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI HELPERS  (unchanged from original)
  // ─────────────────────────────────────────────

  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.backgroundColor(context),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleHeaderGradientThemed(context),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: 150,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonCard(height: 120),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildSkeletonCard(height: 140)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSkeletonCard(height: 140)),
                  ],
                ),
                SizedBox(height: 24),
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 180),
                SizedBox(height: 24),
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 100),
                SizedBox(height: 12),
                _buildSkeletonCard(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard({required double height}) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceColor(context),
      borderRadius: BorderRadius.circular(20),
    ),
  );

  Widget _buildSkeletonSectionHeader() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      SizedBox(width: 12),
      Container(
        width: 150,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ],
  );

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.iconColor(context).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCompletionCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.light
            ? AppColors.subtleGradient
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Strength',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete your profile for better service',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_profileCompletion%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _profileCompletion / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatCard({
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradient,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: iconColor, size: 22),
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
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSharingCard() {
    return _buildSection(
      'Location Sharing',
      Icons.share_location_outlined,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          title: Text(
            'Share my location when a booking is accepted',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Your GPS will be sent only to the handyman of confirmed bookings',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ),
          value: _shareLocationOnBooking,
          activeColor: AppColors.primaryColor,
          onChanged: (value) async {
            if (value) {
              // Check permission before enabling
              final granted = await _locationService.checkLocationPermission();
              if (!granted) {
                Get.snackbar(
                  'Permission Required',
                  'Location permission is needed to share your location.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                  margin: EdgeInsets.all(16),
                  borderRadius: 12,
                );
                return;
              }
            }
            setState(() => _shareLocationOnBooking = value);
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              try {
                await _locationPrivacyService.setClientSharePreference(
                  uid,
                  value,
                );
              } catch (_) {
                setState(() => _shareLocationOnBooking = !value);
                Get.snackbar(
                  'Error',
                  'Failed to save preference',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  margin: EdgeInsets.all(16),
                  borderRadius: 12,
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, {required Widget child}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, icon),
          SizedBox(height: 16),
          child,
        ],
      );

  Widget _buildSectionHeader(String title, IconData icon) => Row(
    children: [
      Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryColor, AppColors.secondaryColor],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      SizedBox(width: 12),
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryColor(context),
          letterSpacing: 0.3,
        ),
      ),
    ],
  );

  Widget _buildPremiumInfoCard({required List<Widget> children}) => Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.cardColor(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderColor(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _buildDivider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Divider(height: 1, color: AppColors.dividerColor(context)),
  );

  Widget _buildEditableField({
    required String label,
    required IconData icon,
    required String initialValue,
    TextInputType? keyboardType,
    bool readOnly = false,
    required Function(String?) onSaved,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor.withValues(alpha: 0.1),
                AppColors.secondaryColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 20),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _isEditing && !readOnly
              ? TextFormField(
                  initialValue: initialValue,
                  keyboardType: keyboardType,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required field' : null,
                  onSaved: onSaved,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      initialValue.isEmpty ? 'Not set' : initialValue,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) => Container(
    margin: EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: AppColors.cardColor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.borderColor(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withValues(alpha: 0.15),
                      AppColors.secondaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(
                  service['icon'],
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  service['name'],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondaryColor(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildBookingCard({
    required String handymanName,
    required String service,
    required String date,
    required String status,
    required Color statusColor,
    double? rating,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor(context)),
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
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.15),
                          AppColors.secondaryColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.handyman,
                      color: AppColors.primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handymanName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          service,
                          style: TextStyle(
                            color: AppColors.textSecondaryColor(context),
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: AppColors.textSecondaryColor(context),
                            ),
                            SizedBox(width: 4),
                            Text(
                              date,
                              style: TextStyle(
                                color: AppColors.textSecondaryColor(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (rating != null) ...[
                SizedBox(height: 12),
                Divider(height: 1, color: AppColors.dividerColor(context)),
                SizedBox(height: 12),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < rating.floor() ? Icons.star : Icons.star_border,
                        color: Color(0xFFFFB800),
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
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
                          color: _getStatusColor(
                            booking['status'] ?? 'pending',
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          booking['status'] ?? 'pending',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(
                              booking['status'] ?? 'pending',
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    _buildDetailRow(
                      'Handyman',
                      booking['handymanName'] ?? 'N/A',
                    ),
                    _buildDetailRow('Service', booking['service'] ?? 'N/A'),
                    _buildDetailRow('Phone', booking['clientPhone'] ?? 'N/A'),
                    _buildDetailRow('Address', booking['address'] ?? 'N/A'),
                    _buildDetailRow('City', booking['city'] ?? 'N/A'),
                    _buildDetailRow(
                      'Scheduled Date',
                      _formatDate(
                        booking['scheduledAt'] ?? booking['scheduledDate'],
                      ),
                    ),
                    _buildDetailRow(
                      'Booked At',
                      _formatDate(booking['createdAt']),
                    ),
                    if (booking['acceptedAt'] != null)
                      _buildDetailRow(
                        'Accepted At',
                        _formatDate(booking['acceptedAt']),
                      ),
                    if (booking['declinedAt'] != null)
                      _buildDetailRow(
                        'Declined At',
                        _formatDate(booking['declinedAt']),
                      ),
                    if ((booking['declineReason'] ??
                            booking['cancellationReason']) !=
                        null)
                      _buildDeclineReasonCard(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclineReasonCard(String reason) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade400),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decline Reason',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                ),
              ],
            ),
          ),
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

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(icon, color: color, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) =>
      Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondaryColor(context)),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      );

  Widget _buildPremiumLogoutButton() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade200, width: 1.5),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLogoutDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text(
                'Logout from Account',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: Duration(milliseconds: 500),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 60,
                              spreadRadius: 10,
                              offset: Offset(0, 30),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated Gradient Circle
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(milliseconds: 800),
                                  curve: Curves.elasticOut,
                                  builder: (context, double value, child) =>
                                      Transform.scale(
                                        scale: value,
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFFF6B6B),
                                                Color(0xFFEE5A6F),
                                                Color(0xFFC06C84),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 30,
                                                offset: Offset(0, 15),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.power_settings_new_rounded,
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                ),

                                SizedBox(height: 28),

                                // Title with gradient
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B6B),
                                      Color(0xFFC06C84),
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    'Logout Account',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 14),

                                Text(
                                  'You\'re about to end this session',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),

                                SizedBox(height: 8),

                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Are you sure you want to logout from your account?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 32),

                                Row(
                                  children: [
                                    // Stay Button
                                    Expanded(
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              AppColors.secondaryColor
                                                  .withValues(alpha: 0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primaryColor
                                                .withValues(alpha: 0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: () => Get.back(),
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.close_rounded,
                                                    color:
                                                        AppColors.primaryColor,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Stay',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors
                                                          .primaryColor,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 14),

                                    // Logout Button
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors:
                                                AppColors.logoutButtonGradient,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(
                                                0xFFFF6B6B,
                                              ).withValues(alpha: 0.5),
                                              blurRadius: 20,
                                              offset: Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: () async {
                                              try {
                                                Get.back();
                                                Get.dialog(
                                                  WillPopScope(
                                                    onWillPop: () async =>
                                                        false,
                                                    child: Center(
                                                      child: Container(
                                                        padding: EdgeInsets.all(
                                                          24,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            CircularProgressIndicator(
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                    Color
                                                                  >(
                                                                    AppColors
                                                                        .primaryColor,
                                                                  ),
                                                            ),
                                                            SizedBox(
                                                              height: 20,
                                                            ),
                                                            Text(
                                                              'Logging out...',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  barrierDismissible: false,
                                                );

                                                await AuthService().signOut();

                                                if (kDebugMode)
                                                  debugPrint(
                                                    '✅ Logout successful',
                                                  );

                                                if (Get.isDialogOpen ?? false)
                                                  Get.back();

                                                AppRoutes.toWelcome();

                                                // Get.snackbar(
                                                //   'Success',
                                                //   'You have been logged out successfully',
                                                //   snackPosition:
                                                //       SnackPosition.BOTTOM,
                                                //   backgroundColor: Colors.green,
                                                //   colorText: Colors.white,
                                                //   duration:
                                                //       Duration(seconds: 2),
                                                //   margin: EdgeInsets.all(16),
                                                //   borderRadius: 12,
                                                //   icon: Icon(
                                                //     Icons.check_circle,
                                                //     color: Colors.white,
                                                //   ),
                                                // );
                                              } catch (e) {
                                                if (kDebugMode)
                                                  debugPrint(
                                                    '❌ Logout error: $e',
                                                  );

                                                if (Get.isDialogOpen ?? false)
                                                  Get.back();

                                                Get.snackbar(
                                                  'Error',
                                                  'Logout failed: ${e.toString()}',
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  duration: Duration(
                                                    seconds: 3,
                                                  ),
                                                  margin: EdgeInsets.all(16),
                                                  borderRadius: 12,
                                                  icon: Icon(
                                                    Icons.error_outline,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              }
                                            },
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.logout_rounded,
                                                    color: AppColors.white,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Logout Now',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: AppColors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
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
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Decorative painter (same as handyman profile)
// ─────────────────────────────────────────────
class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.3),
        50.0 * (i + 1),
        paint,
      );
    }
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.7),
        40.0 * (i + 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
