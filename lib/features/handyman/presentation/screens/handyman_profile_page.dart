// ignore_for_file: unused_field

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/services/app_config_service.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/l10n/app_localizations.dart';
// import 'package:fixilya_app/features/auth/presentation/screens/login_screen.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/handyman_backend_service.dart';
import 'package:fixilya_app/shared/widgets/dropdown_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/profile_service.dart';
import 'package:path_provider/path_provider.dart';

import 'package:get/get.dart'; // ✅ Add this
// import 'package:fixilya_app/data/controllers/theme_controller.dart'; // ✅ Add this
// import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HandymanProfilePage extends StatefulWidget {
  const HandymanProfilePage({super.key});

  @override
  State<HandymanProfilePage> createState() => _HandymanProfilePageState();
}

class _HandymanProfilePageState extends State<HandymanProfilePage>
    with TickerProviderStateMixin {
  final _profileService = ProfileService();

  bool _isEditing = false;
  int _profileCompletion = 0;
  bool _isAvailable = true;
  final bool _isPickingImage = false;
  Map<String, dynamic>? _statsData;
  double _averageRating = 0.0;
  int _reviewCount = 0;

  // ✅ ADD: For image upload
  final bool _isUploadingPortfolioImage = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Premium Colors
  // static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  // static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  // static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  // ✅ ADD THESE NEW VARIABLES
  final _handymanBackendService = HandymanBackendService();
  final bool _isLoadingData = true;
  Map<String, dynamic>? _profileData;
  StreamSubscription? _statsSubscription;

  // ✅ Add helper methods for theme-aware colors
  // Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  // Color get _cardColor => Theme.of(context).brightness == Brightness.dark
  //     ? Color(0xFF1E1E1E)
  //     : Colors.white;
  // Color get _textColor => Theme.of(context).brightness == Brightness.dark
  //     ? Colors.white
  //     : Colors.black87;
  // Color get _subtextColor => Theme.of(context).brightness == Brightness.dark
  //     ? Colors.grey[400]!
  //     : Colors.grey[600]!;
  // Color get _dividerColor => Theme.of(context).brightness == Brightness.dark
  //     ? Colors.grey[800]!
  //     : Colors.grey.shade200;
  // Color get _borderColor => Theme.of(context).brightness == Brightness.dark
  // ? Colors.grey[700]!
  // : Colors.grey.shade200;

  // Handyman data
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _phone = '';
  String _city = '';
  String _experience = '';
  String _bio = '';
  double _hourlyRate = 150.0;
  bool _verifiedProfessional = false;
  bool _isLoading = true;

  // Skills
  List<Map<String, dynamic>> skills = [];
  // Available skills loaded from backend config (falls back to GlobalVariables)
  List<Map<String, dynamic>> _availableSkills =
      GlobalVariables.availableSkills.skip(1).toList();

  // Previous work
  List<Map<String, dynamic>> previousWork = [];

  Future<File> _xFileToTempFile(XFile xFile) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = xFile.name.isNotEmpty
        ? xFile.name
        : 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File('${tempDir.path}/$fileName');
    final bytes = await xFile.readAsBytes();
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  // List<Map<String, String>> previousWork = [
  //   {
  //     'title': 'Modern Villa Rewiring',
  //     'client': 'Hassan Alami',
  //     'date': 'Jan 15, 2026',
  //     'image': 'https://picsum.photos/300/300?random=1',
  //   },
  //   {
  //     'title': 'Office Complex Setup',
  //     'client': 'Fatima Zahra',
  //     'date': 'Jan 10, 2026',
  //     'image': 'https://picsum.photos/300/300?random=2',
  //   },
  //   {
  //     'title': 'Smart Home Integration',
  //     'client': 'Mohammed Berrada',
  //     'date': 'Dec 28, 2025',
  //     'image': 'https://picsum.photos/300/300?random=3',
  //   },
  //   {
  //     'title': 'Commercial Lighting',
  //     'client': 'Youssef Bennani',
  //     'date': 'Dec 15, 2025',
  //     'image': 'https://picsum.photos/300/300?random=4',
  //   },
  // ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _scaleController.forward();
    setState(() => _isLoading = true);

    // ✅ ADD THIS LINE
    Future.delayed(Duration(milliseconds: 500), () {
      _loadProfileData();
    });

    // Load available skills from backend config (non-blocking)
    AppConfigService().getSkills().then((list) {
      if (mounted && list.isNotEmpty) setState(() => _availableSkills = list);
    });
    // _checkAdminStatus();
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Future<void> _checkAdminStatus() async {
  //   try {
  //     // ✅ FIX: Pass current user's ID to isUserAdmin
  //     final currentUser = FirebaseAuth.instance.currentUser;
  //     if (currentUser == null) {
  //       if (mounted) {
  //         setState(() => _isAdmin = false);
  //       }
  //       return;
  //     }

  //     final isAdmin = await _adminService.isUserAdmin(currentUser.uid);
  //     if (mounted) {
  //       setState(() => _isAdmin = isAdmin);
  //     }
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error checking admin status: $e');
  //     if (mounted) {
  //       setState(() => _isAdmin = false);
  //     }
  //   }
  // }

  int _calculateProfileCompletion() {
    if (_profileData == null) return 0;

    int completedFields = 0;
    int totalFields = 10;

    // Check each field (each worth 10%)
    if (_name.isNotEmpty && _name != 'Handyman') completedFields++;
    if (_email.isNotEmpty) completedFields++;
    if (_phone.isNotEmpty) completedFields++;
    if (_city.isNotEmpty) completedFields++;
    if (_experience.isNotEmpty) completedFields++;
    // if (_hourlyRate > 0) completedFields++;
    if (_bio.isNotEmpty && _bio.length >= 20) completedFields++;
    if (skills.isNotEmpty) completedFields++;
    if (_profileData?['profilePicture']?.toString().isNotEmpty ?? false) {
      completedFields++;
    }
    if ((_profileData?['workImages'] as List?)?.isNotEmpty ?? false) {
      completedFields++;
    }

    return (completedFields / totalFields * 100).round();
  }

  // ✅ ADD THIS NEW METHOD
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _handymanBackendService.getHandymanProfile(),
        _handymanBackendService.getRatingStats(),
      ]);

      if (results[0] != null && results[1] != null) {
        final profileData = results[0] as Map<String, dynamic>;
        final ratingStats = results[1] as Map<String, dynamic>;

        // Load stats in background
        _loadStats();

        if (!mounted) return;
        setState(() {
          _profileData = profileData;

          // ✅ FIXED: Safely cast to double
          _averageRating = (ratingStats['rating'] is int)
              ? (ratingStats['rating'] as int).toDouble()
              : (ratingStats['rating'] ?? 0.0);
          _reviewCount = ratingStats['reviewCount'] ?? 0;

          _name = profileData['fullName'] ?? 'Handyman';
          _email = profileData['email'] ?? '';
          _phone = profileData['phone'] ?? '';
          _city = profileData['city'] ?? '';

          // ✅ FIXED: Safely convert to string
          _experience = (profileData['experience'] is int)
              ? (profileData['experience'] as int).toString()
              : (profileData['experience'] ?? '').toString();

          _bio = profileData['bio'] ?? '';

          // ✅ FIXED: Safely cast to double
          _hourlyRate = (profileData['hourlyRate'] is int)
              ? (profileData['hourlyRate'] as int).toDouble()
              : (profileData['hourlyRate'] ?? 0.0);

          _isAvailable = profileData['isAvailable'] ?? true;
          _verifiedProfessional =
              profileData['approved'] == true &&
              profileData['profileCompleted'] == true;

          selectedCity = profileData['city'];

          // Load skills
          if (profileData['skills'] != null) {
            final skillsData = profileData['skills'] as List;
            skills = skillsData.map((skillItem) {
              if (skillItem is String) {
                return {'name': skillItem, 'icon': _getSkillIcon(skillItem)};
              }
              return {'name': 'Unknown', 'icon': _getSkillIcon('Unknown')};
            }).toList();
          }

          // Load work images
          if (profileData['workImages'] != null) {
            final workImageUrls = profileData['workImages'] as List;
            previousWork = workImageUrls.asMap().entries.map((entry) {
              return <String, dynamic>{
                // ← explicit type forces Map<String, dynamic>
                'id': 'image_${entry.key}',
                'image': entry.value as String,
              };
            }).toList();
          }

          _profileCompletion = _calculateProfileCompletion();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ NEW: Load stats separately
  Future<void> _loadStats() async {
    try {
      final stats = await _handymanBackendService.getHandymanStats();
      if (stats != null && mounted) {
        setState(() {
          _statsData = stats;

          // ✅ FIXED: Safely cast to double
          _averageRating = (stats['rating'] is int)
              ? (stats['rating'] as int).toDouble()
              : (stats['rating'] ?? 0.0);

          _reviewCount = stats['totalReviews'] ?? 0;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading stats: $e');
    }
  }

  // ✅ ADD THIS HELPER METHOD
  IconData _getSkillIcon(String skillName) {
    final iconMap = {
      'Plumbing': FontAwesomeIcons.faucet,
      'Electricity': FontAwesomeIcons.bolt,
      'Carpentry': FontAwesomeIcons.hammer,
      'Painting': FontAwesomeIcons.paintRoller,
      'Cleaning': FontAwesomeIcons.broom,
      'Gardening': FontAwesomeIcons.seedling,
      'AC Repair': FontAwesomeIcons.snowflake,
      'Appliance Repair': FontAwesomeIcons.plug,
    };

    return iconMap[skillName] ?? FontAwesomeIcons.wrench;
  }

  // ✅ ADD THIS METHOD TO SAVE TO FIREBASE
  // ✅ UPDATED: Save profile to backend
  Future<void> _saveProfileToFirebase() async {
    try {
      if (kDebugMode) debugPrint('💾 Saving profile to backend...');
      if (kDebugMode) debugPrint('📋 Current values:');
      if (kDebugMode) debugPrint('   Name: $_name');
      if (kDebugMode) debugPrint('   Email: $_email');
      if (kDebugMode) debugPrint('   Phone: $_phone');
      if (kDebugMode) debugPrint('   City: $selectedCity');
      if (kDebugMode) debugPrint('   Experience: $_experience');
      if (kDebugMode) debugPrint('   Hourly Rate: $_hourlyRate');
      if (kDebugMode) debugPrint('   Bio: $_bio');
      if (kDebugMode)
        debugPrint('   Skills: ${skills.map((s) => s['name']).toList()}');

      final skillsData = skills.map((s) => s['name']).toList();

      final updateData = {
        'fullName': _name,
        'email': _email,
        'phone': _phone,
        'city': selectedCity,
        'experience': _experience, // ✅ This is now a string
        'hourlyRate': _hourlyRate, // ✅ This is now a double
        'bio': _bio,
        'skills': skillsData,
      };

      if (kDebugMode) debugPrint('📤 Sending to backend: $updateData');

      final success = await _handymanBackendService.updateHandymanProfile(
        updateData,
      );

      if (success) {
        if (kDebugMode) debugPrint('✅ Backend confirmed update');

        Get.snackbar(
          'Success',
          'Profile updated successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          icon: Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        if (kDebugMode) debugPrint('⚠️ Backend returned false');
        throw Exception('Update failed');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('❌ Error saving profile: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');

      Get.snackbar(
        'Error',
        'Failed to update profile: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );

      rethrow;
    }
  }

  void _showUltraLuxuryLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: Duration(milliseconds: 500),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
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
                                  builder: (context, double value, child) {
                                    return Transform.scale(
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
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Pulsing effect
                                            TweenAnimationBuilder(
                                              tween: Tween<double>(
                                                begin: 1,
                                                end: 1.2,
                                              ),
                                              duration: Duration(seconds: 1),
                                              builder:
                                                  (
                                                    context,
                                                    double scale,
                                                    child,
                                                  ) {
                                                    return Transform.scale(
                                                      scale: scale,
                                                      child: Container(
                                                        width: 100,
                                                        height: 100,
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .red
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                                width: 2,
                                                              ),
                                                            ),
                                                      ),
                                                    );
                                                  },
                                              onEnd: () {
                                                // Repeat animation
                                              },
                                            ),
                                            Icon(
                                              Icons.power_settings_new_rounded,
                                              color: Colors.white,
                                              size: 48,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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

                                // Subtitle
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

                                // Description
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

                                // Premium Buttons
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
                                          color: AppColors.transparent,
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
                                          color: AppColors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),

                                            // REPLACE WITH THIS CODE:
                                            onTap: () async {
                                              try {
                                                // Close the logout dialog
                                                Get.back();

                                                // Show loading dialog
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

                                                // Sign out from Firebase
                                                final authService =
                                                    AuthService();
                                                await authService.signOut();

                                                if (kDebugMode)
                                                  debugPrint(
                                                    '✅ Logout successful',
                                                  );

                                                // Close loading dialog (if still open)
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }

                                                // Navigate to welcome screen using GetX
                                                AppRoutes.toWelcome();

                                                // Show success message
                                                Get.snackbar(
                                                  'Success',
                                                  'You have been logged out successfully',
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  backgroundColor: Colors.green,
                                                  colorText: Colors.white,
                                                  duration: Duration(
                                                    seconds: 2,
                                                  ),
                                                  margin: EdgeInsets.all(16),
                                                  borderRadius: 12,
                                                  icon: Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              } catch (e) {
                                                if (kDebugMode)
                                                  debugPrint(
                                                    '❌ Logout error: $e',
                                                  );

                                                // Close loading dialog if open
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }

                                                // Show error message
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
                                                      letterSpacing: 0.8,
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

                                SizedBox(height: 20),

                                // Info Badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.blue50,
                                        AppColors.indigo50,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.blue200,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lock_outline,
                                          color: Colors.blue.shade700,
                                          size: 16,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Your data is safe & secure',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  

  void _showAddProjectDialog() {
    // Explicit types prevent the Map<String, dynamic> → Map<String, String> cast crash.
    List<XFile> selectedImages = [];
    List<String> uploadedUrls = [];
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Container(
              constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: Offset(0, 20),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryColor,
                            AppColors.secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.collections_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Portfolio Images',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Select multiple images at once',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isUploading ? null : () => Get.back(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            iconSize: 28,
                          ),
                        ],
                      ),
                    ),

                    // ── Image picker + preview ───────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Tap-to-pick area
                            GestureDetector(
                              onTap: isUploading
                                  ? null
                                  : () async {
                                      try {
                                        final picker = ImagePicker();
                                        final List<XFile> images = await picker
                                            .pickMultiImage(imageQuality: 85);
                                        if (images.isNotEmpty) {
                                          setDialogState(
                                            () => selectedImages = images,
                                          );
                                        }
                                      } catch (e) {
                                        if (kDebugMode)
                                          debugPrint('❌ Picker error: $e');
                                      }
                                    },
                              child: Container(
                                height: 190,
                                padding: EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      AppColors.secondaryColor.withValues(
                                        alpha: 0.05,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primaryColor,
                                              AppColors.secondaryColor,
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryColor
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 20,
                                              offset: Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        selectedImages.isEmpty
                                            ? 'Select Images'
                                            : '${selectedImages.length} image${selectedImages.length == 1 ? '' : 's'} selected',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to choose from gallery',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 24),

                            // Preview strip
                            if (selectedImages.isNotEmpty)
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      width: 100,
                                      margin: EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primaryColor
                                              .withValues(alpha: 0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // ✅ FIX 1: Read XFile as bytes — works on
                                            // Android content:// URIs and real paths alike.
                                            FutureBuilder<Uint8List>(
                                              future: selectedImages[index]
                                                  .readAsBytes(),
                                              builder: (ctx, snap) {
                                                if (snap.hasData) {
                                                  return Image.memory(
                                                    snap.data!,
                                                    fit: BoxFit.cover,
                                                  );
                                                }
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            // Remove button
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => setDialogState(
                                                  () => selectedImages.removeAt(
                                                    index,
                                                  ),
                                                ),
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Action buttons ───────────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isUploading ? null : () => Get.back(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (isUploading || selectedImages.isEmpty)
                                  ? null
                                  : () async {
                                      setDialogState(() => isUploading = true);
                                      uploadedUrls = []; // reset for fresh run

                                      try {
                                        final cloudinaryService =
                                            Get.find<CloudinaryService>();

                                        // ✅ FIX 2: Convert each XFile to a real
                                        // temp File before uploading. This handles
                                        // Android content:// URIs correctly.
                                        for (final xFile in selectedImages) {
                                          final File tempFile =
                                              await _xFileToTempFile(xFile);

                                          if (!tempFile.existsSync()) {
                                            if (kDebugMode)
                                              debugPrint(
                                                '⚠️ Temp file missing, skipping: ${xFile.name}',
                                              );
                                            continue;
                                          }

                                          final String? imageUrl =
                                              await cloudinaryService
                                                  .uploadImage(
                                                    imageFile: tempFile,
                                                    folder: 'portfolio',
                                                  );

                                          if (imageUrl != null &&
                                              imageUrl.isNotEmpty) {
                                            uploadedUrls.add(imageUrl);
                                            if (kDebugMode)
                                              debugPrint(
                                                '✅ Uploaded: $imageUrl',
                                              );
                                          } else {
                                            if (kDebugMode)
                                              debugPrint(
                                                '⚠️ Upload returned null/empty for ${xFile.name}',
                                              );
                                          }

                                          // Clean up temp file
                                          try {
                                            await tempFile.delete();
                                          } catch (_) {}
                                        }

                                        if (kDebugMode)
                                          debugPrint(
                                            '📦 ${uploadedUrls.length}/${selectedImages.length} images uploaded',
                                          );

                                        if (uploadedUrls.isEmpty) {
                                          throw Exception(
                                            'No images were uploaded successfully',
                                          );
                                        }

                                        // ✅ FIX 3: Explicit Map<String, dynamic>
                                        // — prevents the Map cast crash.
                                        for (final String url in uploadedUrls) {
                                          final Map<String, dynamic> entry = {
                                            'id':
                                                'img_${DateTime.now().millisecondsSinceEpoch}_${previousWork.length}',
                                            'image': url,
                                          };
                                          previousWork.add(entry);
                                        }

                                        // Persist updated work images via backend
                                        final List<dynamic> workImages =
                                            previousWork
                                                .map(
                                                  (w) => w['image'] as String,
                                                )
                                                .toList();

                                        if (kDebugMode) debugPrint("this 1");

                                        await _handymanBackendService
                                            .updateHandymanProfile({
                                              'workImages': workImages,
                                            });
                                        if (kDebugMode) debugPrint("this 2");

                                        Get.back();
                                        setState(() {}); // refresh grid

                                        Get.snackbar(
                                          'Success',
                                          '${uploadedUrls.length} image${uploadedUrls.length == 1 ? '' : 's'} added to portfolio!',
                                          snackPosition: SnackPosition.BOTTOM,
                                          backgroundColor: Colors.green,
                                          colorText: Colors.white,
                                          margin: EdgeInsets.all(16),
                                          borderRadius: 12,
                                        );
                                      } catch (e) {
                                        if (kDebugMode)
                                          debugPrint('❌ Upload error: $e');
                                        setDialogState(
                                          () => isUploading = false,
                                        );

                                        Get.snackbar(
                                          'Upload Failed',
                                          e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                          snackPosition: SnackPosition.BOTTOM,
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                          margin: EdgeInsets.all(16),
                                          borderRadius: 12,
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isUploading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Uploading...',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_upload_rounded,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Upload Images',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  

  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Full image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 400,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? selectedCity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      // if (true) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: _buildSkeletonLoading(),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surfaceColor(context),
      // backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 320,
            pinned: false,
            elevation: 0,
            backgroundColor: AppColors.surfaceColor(context),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleHeaderGradientThemed(context),
                    ),
                  ),

                  // Decorative Pattern
                  Positioned.fill(
                    child: CustomPaint(painter: CirclePatternPainter()),
                  ),

                  // Content
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40),

                          // Profile Picture with Gradient Border
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
                                    color: AppColors.shadowColor(context),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              // ✅ CHECK IF PICTURE EXISTS
                              child:
                                  _profileData != null &&
                                      _profileData!['profilePicture'] != null &&
                                      _profileData!['profilePicture']
                                          .toString()
                                          .isNotEmpty
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: NetworkImage(
                                        _profileData!['profilePicture'],
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

                          SizedBox(height: 16),

                          // Name
                          Text(
                            _name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 8),

                          // Verified Badge
                          if (_verifiedProfessional)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.textDisabledColor(
                                  context,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.textDisabledColor(
                                    context,
                                  ).withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),

                                  Text(
                                    'Verified Pro',
                                    // l10n.verifiedPro,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),

                                  Text(
                                    'Not Verified',
                                    // l10n.verifiedPro,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(height: 12),

                          // Rating
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textDisabledColor(
                                context,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.textDisabledColor(
                                  context,
                                ).withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Color(0xFFFFB800),
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _averageRating > 0
                                      ? _averageRating.toStringAsFixed(1)
                                      : 'No rating',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _reviewCount > 0
                                      ? '($_reviewCount ${_reviewCount == 1 ? 'review' : 'reviews'})'
                                      : '(No reviews yet)',
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

                  //  Buttons
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Row(
                      children: [
                        // Settings Button
                        _buildGlassButton(
                          icon: Icons.settings,
                          onPressed: () => AppRoutes.toHandymanSettings(),
                        ),
                        SizedBox(width: 12),

                        // if (_isAdmin) ...[
                        //   _buildGlassButton(
                        //     icon: Icons.admin_panel_settings,
                        //     onPressed: () => AppRoutes.toAdmin(),
                        //   ),
                        //   SizedBox(width: 12),
                        // ],
                        SizedBox(width: 12),
                        _buildGlassButton(
                          icon: _isEditing ? Icons.check : Icons.edit,
                          onPressed: () async {
                            if (_isEditing) {
                              if (_formKey.currentState!.validate()) {
                                // ✅ SAVE FORM VALUES
                                _formKey.currentState!.save();

                                // ✅ SAVE TO BACKEND
                                await _saveProfileToFirebase();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 12),
                                        Text('Profile updated successfully!'),
                                      ],
                                    ),
                                    backgroundColor: AppColors.primaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );

                                // ✅ ONLY THEN TOGGLE EDIT MODE
                                setState(() {
                                  _isEditing = false;
                                });
                              }
                            } else {
                              // ✅ ENTERING EDIT MODE
                              setState(() {
                                _isEditing = true;
                              });
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

          // Content
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
                      // Profile Completion Card
                      _buildProfileCompletionCard(l10n),

                      SizedBox(height: 20),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildPremiumStatCard(
                              icon: FontAwesomeIcons.briefcase,
                              value: '${_statsData?['completedJobs'] ?? 0}',
                              label: 'Jobs Completed',
                              gradient: AppColors.blueStateCardGradientThemed(
                                context,
                              ),
                              iconColor: AppColors.primaryColor,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildPremiumStatCard(
                              icon: FontAwesomeIcons.clock,
                              value: _experience,
                              label: 'Experience',
                              gradient: AppColors.orangeStateCardGradientThemed(
                                context,
                              ),
                              iconColor: AppColors.hardOrange,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Personal Information
                      _buildSection(
                        'Personal Information',
                        Icons.person_outline,
                        child: _buildPremiumInfoCard(
                          children: [
                            _buildEditableField(
                              label: 'Full Name',
                              icon: Icons.person,
                              initialValue: _name,
                              onSaved: (value) => _name = value!,
                            ),
                            _buildDivider(),
                            _buildEditableField(
                              label: 'Email',
                              icon: Icons.email_outlined,
                              initialValue: _email,
                              readOnly: true,
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (value) => _email = value!,
                            ),

                            _buildDivider(),
                            _buildEditableField(
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              initialValue: _phone,
                              keyboardType: TextInputType.phone,
                              onSaved: (value) => _phone = value!,
                            ),
                            _buildDivider(),
                            GenericDropdown<String>(
                              items: GlobalVariables.cities.skip(1).toList(),
                              value: selectedCity,
                              label: 'City',
                              hint: 'Select your city',
                              itemLabel: (city) => city,
                              onChanged: (value) =>
                                  setState(() => selectedCity = value),
                              validator: (value) =>
                                  value == null ? 'Please select a city' : null,
                              prefixIcon: Icons.location_city,
                              primaryColor: AppColors.primaryColor,
                              secondaryColor: AppColors.secondaryColor,
                              isEditing:
                                  _isEditing, // Set to false for preview mode
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Professional Info
                      _buildSection(
                        'Professional Details',
                        Icons.work_outline,
                        child: _buildPremiumInfoCard(
                          children: [
                            _buildEditableField(
                              label: 'Years of Experience',
                              icon: Icons.schedule,
                              initialValue: _experience,
                              onSaved: (value) => _experience = value!,
                            ),
                            // _buildDivider(),
                            // _buildEditableField(
                            //   label: 'Hourly Rate (DH)',
                            //   icon: Icons.attach_money,
                            //   initialValue: _hourlyRate.toString(),
                            //   keyboardType: TextInputType.number,
                            //   onSaved: (value) =>
                            //       _hourlyRate = double.parse(value!),
                            // ),
                            _buildDivider(),
                            _isEditing
                                ? TextFormField(
                                    initialValue: _bio,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      labelText: 'Professional Bio',
                                      labelStyle: TextStyle(fontSize: 13),
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
                                    ),
                                    onSaved: (value) => _bio = value!,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: AppColors.primaryColor,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Professional Bio',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondaryColor(
                                                    context,
                                                  ),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        _bio,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimaryColor(
                                            context,
                                          ),
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Skills & Pricing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            'Skills & Pricing',
                            Icons.build_outlined,
                          ),
                          if (!_isEditing)
                            _buildAddButton(
                              label: 'Add Skill',
                              onPressed: _showAddSkillDialog,
                            ),
                        ],
                      ),
                      SizedBox(height: 16),

                      if (skills.isEmpty)
                        _buildEmptySkills()
                      else
                        ...skills.map((skill) => _buildPremiumSkillCard(skill)),
                      SizedBox(height: 24),

                      // Previous Work
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            'Portfolio',
                            Icons.photo_library_outlined,
                          ),
                          if (!_isEditing)
                            _buildAddButton(
                              label: 'Add Project',
                              onPressed: _showAddProjectDialog,
                            ),
                        ],
                      ),
                      SizedBox(height: 16),

                      if (previousWork.isEmpty)
                        _buildEmptyPortfolio()
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                          itemCount: previousWork
                              .length, // ✅ FIXED: Was previousWork.length - 1
                          itemBuilder: (context, index) {
                            final work = previousWork[index];
                            return _buildPremiumWorkCard(work, index);
                          },
                        ),

                      // SizedBox(height: 24),

                      // // Availability Toggle
                      // _buildAvailabilityCard(),
                      SizedBox(height: 40),

                      // Logout Button
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

  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        // Skeleton AppBar
        SliverAppBar(
          expandedHeight: 320,
          pinned: false,
          elevation: 0,
          backgroundColor: AppColors.backgroundColor(context),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleHeaderGradientThemed(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleHeaderGradientThemed(context),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40),
                          // Skeleton Avatar
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.glassWhite,
                            ),
                          ),
                          SizedBox(height: 16),
                          // Skeleton Name
                          Container(
                            width: 150,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.glassWhite,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Skeleton Badge
                          Container(
                            width: 140,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.glassWhite,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          SizedBox(height: 12),
                          // Skeleton Rating
                          Container(
                            width: 160,
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
                ],
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
                // Skeleton Profile Completion
                _buildSkeletonCard(height: 120),
                SizedBox(height: 20),

                // Skeleton Stats
                Row(
                  children: [
                    Expanded(child: _buildSkeletonCard(height: 140)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSkeletonCard(height: 140)),
                  ],
                ),
                SizedBox(height: 24),

                // Skeleton Personal Info
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 220),
                SizedBox(height: 24),

                // Skeleton Professional Details
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 180),
                SizedBox(height: 24),

                // Skeleton Skills
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 80),
                SizedBox(height: 12),
                _buildSkeletonCard(height: 80),
                SizedBox(height: 24),

                // Skeleton Portfolio
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.inputFillColor(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  },
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
        color: AppColors.inputFillColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildSkeletonSectionHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.inputFillColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        SizedBox(width: 12),
        Container(
          width: 150,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.inputFillColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySkills() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.2),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          // Icon(
          //   Icons.build_outlined,
          //   size: 60,
          //   color: AppColors.primaryColor.withValues(alpha: 0.5),
          // ),
          // SizedBox(height: 16),
          Text(
            'No skills added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap "Add Skill" to showcase your expertise',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPortfolio() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.2),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          // Icon(
          //   Icons.build_outlined,
          //   size: 60,
          //   color: AppColors.primaryColor.withValues(alpha: 0.5),
          // ),
          // SizedBox(height: 16),
          Text(
            'No projects added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap "Add Project" to showcase your work',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

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
          width: 1,
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

  Widget _buildProfileCompletionCard(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.light
            ? AppColors.subtleGradient
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.infoColor(context).withValues(alpha: 0.2),
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
                    // l10n.profileStrength,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete your profile to get more clients',
                    // l10n.completeProfile,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey600Color(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.mainButtonColor(context),
                      AppColors.infoColor(context),
                    ],
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
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.mainButtonColor(context),
              ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
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

  Widget _buildSection(String title, IconData icon, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildSectionHeader(title, icon), SizedBox(height: 16), child],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
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
  }

  Widget _buildPremiumInfoCard({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor(context)),
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
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: AppColors.dividerColor(context)),
    );
  }

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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryColor(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.borderColor(context),
                      ),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required field';
                    }
                    return null;
                  },
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
                      initialValue,
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

  Widget _buildAddButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.1),
            AppColors.secondaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: AppColors.primaryColor, size: 18),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSkillCard(Map<String, dynamic> skill) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLightColor(context),
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
                    skill['icon'],
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      // _isEditing
                      //     ? _buildEditablePrice(skill)
                      //     : Text('${skill['price']} DH/hour'),
                    ],
                  ),
                ),
                if (_isEditing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          skills.remove(skill);
                        });
                      },
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildEditablePrice(Map<String, dynamic> skill) {
  //   return InkWell(
  //     onTap: () => _showEditPriceDialog(skill),
  //     child: Container(
  //       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //       decoration: BoxDecoration(
  //         color: AppColors.primaryColor.withValues(alpha: 0.1),
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(
  //           color: AppColors.primaryColor.withValues(alpha: 0.3),
  //         ),
  //       ),
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text('${skill['price']} DH/hour'),
  //           SizedBox(width: 8),
  //           Icon(Icons.edit, size: 16, color: AppColors.primaryColor),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildWorkCard(Map<String, dynamic> work) {
  //   return Container(
  //     margin: EdgeInsets.only(bottom: 16),
  //     decoration: BoxDecoration(
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.08),
  //           blurRadius: 12,
  //           offset: Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Stack(
  //       children: [
  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(16),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               // Image
  //               AspectRatio(
  //                 aspectRatio: 16 / 9,
  //                 child: work['image'] ?? ''.isNotEmpty
  //                     ? Image.network(
  //                         work['image'] ?? '',
  //                         fit: BoxFit.cover,
  //                         errorBuilder: (context, error, stackTrace) {
  //                           return Container(
  //                             color: Colors.grey[200],
  //                             child: Center(
  //                               child: Icon(
  //                                 Icons.image_not_supported,
  //                                 size: 48,
  //                                 color: Colors.grey[400],
  //                               ),
  //                             ),
  //                           );
  //                         },
  //                         loadingBuilder: (context, child, loadingProgress) {
  //                           if (loadingProgress == null) return child;
  //                           return Container(
  //                             color: Colors.grey[200],
  //                             child: Center(
  //                               child: CircularProgressIndicator(
  //                                 value:
  //                                     loadingProgress.expectedTotalBytes != null
  //                                     ? loadingProgress.cumulativeBytesLoaded /
  //                                           loadingProgress.expectedTotalBytes!
  //                                     : null,
  //                               ),
  //                             ),
  //                           );
  //                         },
  //                       )
  //                     : Container(
  //                         color: Colors.grey[200],
  //                         child: Center(
  //                           child: Icon(
  //                             Icons.image,
  //                             size: 48,
  //                             color: Colors.grey[400],
  //                           ),
  //                         ),
  //                       ),
  //               ),

  //               // Details
  //               Container(
  //                 padding: EdgeInsets.all(16),
  //                 decoration: BoxDecoration(
  //                   color: Theme.of(context).colorScheme.surface,
  //                   borderRadius: BorderRadius.only(
  //                     bottomLeft: Radius.circular(16),
  //                     bottomRight: Radius.circular(16),
  //                   ),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       work['title'] ?? 'Untitled',
  //                       style: TextStyle(
  //                         fontSize: 16,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.black87,
  //                       ),
  //                     ),
  //                     SizedBox(height: 8),
  //                     Row(
  //                       children: [
  //                         Icon(
  //                           Icons.person_outline,
  //                           size: 16,
  //                           color: Colors.grey[600],
  //                         ),
  //                         SizedBox(width: 6),
  //                         Text(
  //                           work['client'] ?? 'Unknown',
  //                           style: TextStyle(
  //                             fontSize: 14,
  //                             color: Colors.grey[700],
  //                           ),
  //                         ),
  //                         Spacer(),
  //                         Icon(
  //                           Icons.calendar_today,
  //                           size: 16,
  //                           color: Colors.grey[600],
  //                         ),
  //                         SizedBox(width: 6),
  //                         Text(
  //                           work['date'] ?? 'Recent',
  //                           style: TextStyle(
  //                             fontSize: 14,
  //                             color: Colors.grey[700],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                     if (work['description']?.isNotEmpty ?? false) ...[
  //                       SizedBox(height: 8),
  //                       Text(
  //                         work['description']!,
  //                         style: TextStyle(
  //                           fontSize: 13,
  //                           color: Colors.grey[600],
  //                         ),
  //                         maxLines: 2,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ],
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),

  //         // ✅ ADD: Edit and Delete buttons (only in edit mode)
  //         if (_isEditing)
  //           Positioned(
  //             top: 8,
  //             right: 8,
  //             child: Row(
  //               children: [
  //                 // Edit button
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     color: Colors.white,
  //                     shape: BoxShape.circle,
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: Colors.black.withValues(alpha: 0.2),
  //                         blurRadius: 8,
  //                       ),
  //                     ],
  //                   ),
  //                   child: IconButton(
  //                     icon: Icon(
  //                       Icons.edit,
  //                       color: AppColors.primaryColor,
  //                       size: 20,
  //                     ),
  //                     onPressed: () => _showEditProjectDialog(work),
  //                   ),
  //                 ),
  //                 SizedBox(width: 8),
  //                 // Delete button
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     color: Colors.white,
  //                     shape: BoxShape.circle,
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: Colors.black.withValues(alpha: 0.2),
  //                         blurRadius: 8,
  //                       ),
  //                     ],
  //                   ),
  //                   child: IconButton(
  //                     icon: Icon(Icons.delete, color: Colors.red, size: 20),
  //                     onPressed: () => _showDeleteProjectDialog(work),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildAddWorkCard() {
  //   return InkWell(
  //     onTap: _showAddProjectDialog,
  //     borderRadius: BorderRadius.circular(12),
  //     child: Container(
  //       margin: EdgeInsets.only(bottom: 16),
  //       padding: EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: AppColors.primaryColor.withValues(alpha: 0.05),
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(
  //           color: AppColors.primaryColor.withValues(alpha: 0.3),
  //           width: 1.5,
  //         ),
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         // crossAxisAlignment: CrossAxisAlignment.end,
  //         children: [
  //           Container(
  //             padding: EdgeInsets.all(20),
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [AppColors.primaryColor, AppColors.secondaryColor],
  //               ),
  //               shape: BoxShape.circle,
  //             ),
  //             child: Icon(
  //               Icons.add_photo_alternate,
  //               color: Colors.white,
  //               size: 29,
  //             ),
  //           ),
  //           SizedBox(height: 16),
  //           Text(
  //             'New Project',
  //             style: TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.bold,
  //               color: AppColors.primaryColor,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildPremiumWorkCard(Map<String, dynamic> work, int index) {
    return GestureDetector(
      onTap: () => _showImageFullScreen(work['image']),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ✅ Image only
              Image.network(
                work['image'] ?? '',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),

              // ✅ Delete button (only in edit mode)
              if (_isEditing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () async {
                      // Remove from list
                      setState(() {
                        previousWork.removeAt(index);
                      });

                      // ✅ Update backend instead of Firestore
                      final workImages = previousWork
                          .map((work) => work['image'] as String)
                          .toList();
                      await _handymanBackendService.updateHandymanProfile({
                        'workImages': workImages,
                      });

                      Get.snackbar(
                        'Deleted',
                        'Image removed from portfolio',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                        margin: EdgeInsets.all(16),
                        borderRadius: 12,
                        duration: Duration(seconds: 2),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
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
              final success = await _handymanBackendService
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
            activeThumbColor: Theme.of(context).colorScheme.surface,
            activeTrackColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _showUltraLuxuryLogoutDialog(), // Use ultra luxury dialog
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.red, size: 20),
                SizedBox(width: 10),
                Text(
                  'Logout from Account ',
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
  }

  void _showAddSkillDialog() {
    // ✅ Track selected skills in dialog state
    List<Map<String, dynamic>> tempSelectedSkills = List.from(skills);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.build, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage Skills', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 4),
                      Text(
                        'Select your skills',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Selected Count Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.1),
                          AppColors.secondaryColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primaryColor,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${tempSelectedSkills.length} skill${tempSelectedSkills.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ✅ Scrollable Skills Grid
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: _availableSkills.map((skill) {
                              final isSelected = tempSelectedSkills.any(
                                (s) => s['name'] == skill['name'],
                              );
                              return _buildCompactSkillChip(
                                skill,
                                isSelected,
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      // ✅ Remove skill
                                      tempSelectedSkills.removeWhere(
                                        (s) => s['name'] == skill['name'],
                                      );
                                    } else {
                                      // ✅ Add skill
                                      tempSelectedSkills.add({
                                        'name': skill['name'],
                                        'icon': skill['icon'],
                                      });
                                    }
                                  });
                                },
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    if (kDebugMode)
                      debugPrint('Selected skills: $tempSelectedSkills');
                    if (kDebugMode)
                      debugPrint(
                        'Selected skills with map: ${tempSelectedSkills.map((s) => s['name']).toList()}',
                      );
                    // if (false) {
                    if (tempSelectedSkills.isNotEmpty) {
                      // ✅ Show loading indicator
                      Get.back(); // Close dialog first

                      Get.dialog(
                        WillPopScope(
                          onWillPop: () async => false,
                          child: Center(
                            child: Container(
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
                                    'Updating skills...',
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

                      try {
                        // ✅ Update local state
                        setState(() {
                          skills = List.from(tempSelectedSkills);
                        });

                        // ✅ Prepare skills data for Firebase
                        final skillsData = tempSelectedSkills
                            .map((s) => s['name'])
                            .toList();

                        if (kDebugMode) debugPrint('skillsData : $skillsData');

                        // ✅ Save to backend
                        final success = await _handymanBackendService
                            .updateHandymanProfile({'skills': skillsData});

                        // Close loading dialog
                        if (Get.isDialogOpen ?? false) {
                          Get.back();
                        }

                        if (success) {
                          if (kDebugMode)
                            debugPrint('✅ Skills updated successfully');
                          if (kDebugMode)
                            debugPrint('   Skills count: ${skillsData.length}');

                          // ✅ Show success message
                          Get.snackbar(
                            'Success',
                            'Skills updated successfully!',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            duration: Duration(seconds: 2),
                            margin: EdgeInsets.all(16),
                            borderRadius: 12,
                            icon: Icon(Icons.check_circle, color: Colors.white),
                          );
                        } else {
                          if (kDebugMode)
                            debugPrint('⚠️ Skills update returned false');

                          Get.snackbar(
                            'Warning',
                            'Skills updated locally but may not have synced',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                            duration: Duration(seconds: 2),
                            margin: EdgeInsets.all(16),
                            borderRadius: 12,
                          );
                        }
                      } catch (e) {
                        if (kDebugMode)
                          debugPrint('❌ Error updating skills: $e');

                        // Close loading dialog if open
                        if (Get.isDialogOpen ?? false) {
                          Get.back();
                        }

                        // ✅ Show error message
                        Get.snackbar(
                          'Error',
                          'Failed to update skills: ${e.toString()}',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          duration: Duration(seconds: 3),
                          margin: EdgeInsets.all(16),
                          borderRadius: 12,
                          icon: Icon(Icons.error_outline, color: Colors.white),
                        );
                      }
                    } else {
                      // ✅ Validation error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please select at least one skill'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                    // }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Skills',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactSkillChip(
    Map<String, dynamic> skill,
    bool isSelected, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor.withValues(alpha: 0.5)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              skill['icon'],
              size: 16,
              color: isSelected ? Colors.white : AppColors.primaryColor,
            ),
            SizedBox(width: 8),
            Text(
              skill['name'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 6),
              Icon(Icons.check, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  // void _showAddWorkDialog() {
  //   String title = '';
  //   String client = '';

  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       title: Row(
  //         children: [
  //           Container(
  //             padding: EdgeInsets.all(8),
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [AppColors.primaryColor, AppColors.secondaryColor],
  //               ),
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //             child: Icon(
  //               Icons.add_photo_alternate,
  //               color: Colors.white,
  //               size: 20,
  //             ),
  //           ),
  //           SizedBox(width: 12),
  //           Text('Add Portfolio Item', style: TextStyle(fontSize: 18)),
  //         ],
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           TextField(
  //             decoration: InputDecoration(
  //               labelText: 'Project Title',
  //               border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               prefixIcon: Icon(Icons.work, color: AppColors.primaryColor),
  //             ),
  //             onChanged: (value) => title = value,
  //           ),
  //           SizedBox(height: 16),
  //           TextField(
  //             decoration: InputDecoration(
  //               labelText: 'Client Name',
  //               border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               prefixIcon: Icon(Icons.person, color: AppColors.primaryColor),
  //             ),
  //             onChanged: (value) => client = value,
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Get.back(),
  //           child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
  //         ),
  //         Container(
  //           decoration: BoxDecoration(
  //             gradient: LinearGradient(
  //               colors: [AppColors.primaryColor, AppColors.secondaryColor],
  //             ),
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: ElevatedButton(
  //             onPressed: () {
  //               if (title.isNotEmpty && client.isNotEmpty) {
  //                 setState(() {
  //                   previousWork.add({
  //                     'title': title,
  //                     'client': client,
  //                     'date': 'Today',
  //                     'image':
  //                         'https://picsum.photos/300/300?random=${previousWork.length + 10}',
  //                   });
  //                 });
  //                 Get.back();
  //               }
  //             },
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.transparent,
  //               shadowColor: Colors.transparent,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //             ),
  //             child: Text('Add to Portfolio'),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // void _showWorkDetails(Map<String, dynamic> work) {
  //   showDialog(
  //     context: context,
  //     barrierColor: Colors.black87,
  //     builder: (context) => Dialog(
  //       backgroundColor: Colors.transparent,
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.end,
  //             children: [
  //               _buildGlassButton(
  //                 icon: Icons.close,
  //                 onPressed: () => Get.back(),
  //               ),
  //             ],
  //           ),
  //           SizedBox(height: 12),
  //           ClipRRect(
  //             borderRadius: BorderRadius.circular(20),
  //             child: Container(
  //               color: Colors.white,
  //               child: Column(
  //                 children: [
  //                   Image.network(work['image'] ?? '', height: 300),
  //                   Padding(
  //                     padding: EdgeInsets.all(20),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                           work['title'] ?? 'Untitled',
  //                           style: TextStyle(
  //                             fontSize: 20,
  //                             fontWeight: FontWeight.bold,
  //                           ),
  //                         ),
  //                         SizedBox(height: 8),
  //                         Row(
  //                           children: [
  //                             Icon(
  //                               Icons.person,
  //                               size: 16,
  //                               color: AppColors.primaryColor,
  //                             ),
  //                             SizedBox(width: 6),
  //                             Text('Client: ${work['client'] ?? 'Unknown'}'),
  //                           ],
  //                         ),
  //                         SizedBox(height: 4),
  //                         Row(
  //                           children: [
  //                             Icon(
  //                               Icons.calendar_today,
  //                               size: 16,
  //                               color: AppColors.primaryColor,
  //                             ),
  //                             SizedBox(width: 6),
  //                             Text('Date: ${work['date'] ?? 'Recent'}'),
  //                           ],
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}

// Custom Painter for Background Pattern
class CirclePatternPainter extends CustomPainter {
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
