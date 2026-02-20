// ignore_for_file: depend_on_referenced_packages

import 'dart:ui';
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/admin_data_service.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/client_data_service.dart'; // ✅ Use ClientDataService
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/firebase_image_service.dart';
import 'package:fixilya_app/shared/widgets/dropdown_list.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart'; // ✅ Add GetX
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage>
    with TickerProviderStateMixin {
  final _clientDataService = ClientDataService(); // ✅ Use service layer
  // ✅ ADD THESE NEW VARIABLES
  late final CloudinaryService _cloudinaryService;
  late final FirebaseImageService _firebaseImageService;
  bool _isAdmin = false; // ✅ Add this
  final _adminService = AdminDataService(); // ✅ Add this
  // ✅ GetX Controller - handles all business logic
  // late final ClientProfileController controller;

  bool _isEditing = false;
  int _profileCompletion = 0;
  bool _isLoading = true;

  // // Premium Colors - Same as Handyman
  // static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  // static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  // static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  // ✅ SERVICE INTEGRATION (Same as HandymanProfilePage)
  Map<String, dynamic>? _profileData;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;

  // Form
  final _formKey = GlobalKey<FormState>();

  // ✅ CLIENT DATA (from Firebase)
  String _name = 'Client';
  String _email = '';
  String _phone = '';
  String _address = '';
  String _profilePicture = '';
  String _clientType = '';
  DateTime? _memberSince;

  // ✅ STATS (from Firebase)
  int _totalBookings = 0;
  int _favoriteHandymen = 0;

  String? selectedCity;

  // ✅ RECENT BOOKINGS (from Firebase)
  List<Map<String, dynamic>> _recentBookings = [];

  // ✅ FAVORITE SERVICES (from Firebase)
  List<Map<String, dynamic>> _favoriteServices = [];

  @override
  void initState() {
    super.initState();

    try {
      _cloudinaryService = Get.find<CloudinaryService>();
      _firebaseImageService = Get.find<FirebaseImageService>();
    } catch (e) {}

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
    _fadeController.forward();
    _scaleController.forward();

    // ✅ LOAD DATA FROM FIREBASE (Same as HandymanProfilePage)
    _loadProfileData();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isAdmin = false);
        }
        return;
      }

      final isAdmin = await _adminService.isUserAdmin(currentUser.uid);
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    } catch (e) {
      print('❌ Error checking admin status: $e');
      if (mounted) {
        setState(() => _isAdmin = false);
      }
    }
  }

  /// ✅ PICK AND UPLOAD PROFILE PICTURE
  Future<void> _pickAndUploadProfilePicture() async {
    try {
      // Pick image
      final image = await _cloudinaryService.pickImage();

      if (image == null) {
        return;
      }

      setState(() {});

      // Show uploading dialog
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
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
                  SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Upload to Cloudinary
      final imageUrl = await _cloudinaryService.uploadImage(
        imageFile: image,
        folder: 'profiles',
        publicId: 'profile_${FirebaseAuth.instance.currentUser?.uid}',
        isProfilePicture: true,
        timeoutSeconds: 30,
      );

      if (imageUrl != null) {
        // Save URL to Firebase
        final success = await _firebaseImageService.saveProfileImageUrl(
          userId: FirebaseAuth.instance.currentUser!.uid,
          imageUrl: imageUrl,
          userType: 'clients',
        );

        if (success) {
          // Update local state
          if (mounted) {
            setState(() {
              _profilePicture = imageUrl;

              // Recalculate profile completion
              _profileCompletion = _calculateProfileCompletion();
            });
          }

          // Close uploading dialog
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }

          // Show success message
          Get.snackbar(
            '✅ Success',
            'Profile picture updated successfully!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            margin: EdgeInsets.all(16),
            borderRadius: 12,
            icon: Icon(Icons.check_circle, color: Colors.white),
            duration: Duration(seconds: 2),
          );
        } else {
          throw Exception('Failed to save URL to Firebase');
        }
      } else {
        throw Exception('Upload returned null');
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }

      // Close uploading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to upload profile picture: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 3),
      );
    }
  }

  // ✅ LOAD DATA FROM FIREBASE (Same pattern as HandymanProfilePage)
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true); // ✅ Set loading true

    try {
      final results = await Future.wait([
        _clientDataService.getClientProfile(),
        _clientDataService.getClientStats(),
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

          selectedCity = profileData['city'] ?? '';

          if (profileData['createdAt'] != null) {
            if (profileData['createdAt'] is Timestamp) {
              _memberSince = (profileData['createdAt'] as Timestamp).toDate();
            }
          }

          _totalBookings = statsData?['totalBookings'] ?? 0;
          _favoriteHandymen = statsData?['favoritesCount'] ?? 0;

          _profileCompletion = _calculateProfileCompletion();

          _isLoading = false; // ✅ Set loading false
        });

        await Future.wait([_loadRecentBookings(), _loadFavoriteServices()]);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // ✅ Set loading false on error
      }
    }
  }

  // ✅ CALCULATE PROFILE COMPLETION (Same as HandymanProfilePage)
  int _calculateProfileCompletion() {
    if (_profileData == null) return 0;

    int completedFields = 0;
    int totalFields = 6;

    // Full Name (20%)
    if (_name.isNotEmpty && _name != 'Client') completedFields++;

    // Phone (15%)
    if (_phone.isNotEmpty) completedFields++;

    // City (15%)
    if (selectedCity != null && selectedCity!.isNotEmpty) completedFields++;

    // Address (15%)
    if (_address.isNotEmpty) completedFields++;

    // Profile picture (35% - double weight)
    if (_profilePicture.isNotEmpty) {
      completedFields++;
      completedFields++; // Extra weight
    }

    return (completedFields / totalFields * 100).round();
  }

  // ✅ LOAD RECENT BOOKINGS
  Future<void> _loadRecentBookings() async {
    try {
      final bookings = await _clientDataService.getClientBookings();

      if (mounted) {
        setState(() {
          _recentBookings = bookings.take(5).map((booking) {
            return {
              'id': booking['id'],
              'handymanName': booking['handymanName'] ?? 'Unknown Handyman',
              'service': booking['service'] ?? 'Service',
              'date': _formatDate(booking['createdAt']),
              'status': booking['status'] ?? 'pending',
              'price': '${booking['amount'] ?? 0} DH',
              'rating': booking['rating']?.toDouble(),
            };
          }).toList();
        });
      }
    } catch (e) {}
  }

  // ✅ LOAD FAVORITE SERVICES
  Future<void> _loadFavoriteServices() async {
    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(_profileData?['uid'])
          .get();

      if (clientDoc.exists && mounted) {
        final favoriteServiceNames = List<String>.from(
          clientDoc.data()?['favoriteServices'] ?? [],
        );

        setState(() {
          _favoriteServices = favoriteServiceNames.map((serviceName) {
            return {'name': serviceName, 'icon': _getServiceIcon(serviceName)};
          }).toList();
        });
      }
    } catch (e) {}
  }

  // ✅ HELPER: Get service icon
  IconData _getServiceIcon(String serviceName) {
    final iconMap = {
      'Plumbing': FontAwesomeIcons.faucet,
      'Electrical Work': FontAwesomeIcons.bolt,
      'Carpentry': FontAwesomeIcons.hammer,
      'Painting': FontAwesomeIcons.paintRoller,
      'Cleaning': FontAwesomeIcons.broom,
      'Gardening': FontAwesomeIcons.seedling,
      'AC Repair': FontAwesomeIcons.snowflake,
      'Appliance Repair': FontAwesomeIcons.plug,
    };

    return iconMap[serviceName] ?? FontAwesomeIcons.wrench;
  }

  String _getClientType(String clientType) {
    final types = {
      '1': "New Client",
      '2': "Standard Client",
      '3': "Premium Client",
    };

    return types[clientType] ?? '1';
  }

  // ✅ HELPER: Format date
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recent';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recent';
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

      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Recent';
    }
  }

  // ✅ HELPER: Format member since
  String _formatMemberSince() {
    if (_memberSince == null) return 'Member since Jan 2024';

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

    return 'Member since ${months[_memberSince!.month - 1]} ${_memberSince!.year}';
  }

  // ✅ SAVE PROFILE TO FIREBASE (Same as HandymanProfilePage)
  Future<void> _saveProfileToFirebase() async {
    try {
      // ✅ Validate first
      // if (!_formKey.currentState!.validate()) {
      //   Get.snackbar(
      //     'Validation Error',
      //     'Please fill in all required fields',
      //     snackPosition: SnackPosition.BOTTOM,
      //     backgroundColor: Colors.orange,
      //     colorText: Colors.white,
      //     margin: EdgeInsets.all(16),
      //     borderRadius: 12,
      //   );
      //   return;
      // }

      // ✅ Save form to capture all values
      _formKey.currentState!.save();

      final success = await _clientDataService.updateClientProfile({
        'fullName': _name,
        'email': _email,
        'phone': _phone,
        'city': selectedCity,
        'address': _address,
      });

      if (success) {
        // ✅ UPDATE LOCAL STATE
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

            // Recalculate profile completion
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

  // ✅ LOGOUT DIALOG (Same as HandymanProfilePage)
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
                                        child: Icon(
                                          Icons.power_settings_new_rounded,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                SizedBox(height: 28),

                                // Title
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

                                // Buttons
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
                                            onTap: () async {
                                              try {
                                                Get.back();

                                                // Show loading
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

                                                // Sign out
                                                final authService =
                                                    AuthService();
                                                await authService.signOut();

                                                // Close loading
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }

                                                // Navigate to welcome
                                                AppRoutes.toWelcome();

                                                // Success message
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
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }

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

  @override
  Widget build(BuildContext context) {
    // ✅ LOADING STATE (Same as HandymanProfilePage)
    if (_isLoading) {
      // if (true) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: _buildSkeletonLoading(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar - Same style as Handyman
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

                          // Profile Picture
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
                                    // ✅ SHOW PROFILE PICTURE IF EXISTS
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
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryColor
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
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

                          // Client Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
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

                          // Member Since
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

                  // Action Button
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
                            // ← Make async
                            if (_isEditing) {
                              // ✅ User clicked CHECK button - save changes
                              await _saveProfileToFirebase();

                              // ✅ Exit edit mode only if save was successful
                              setState(() {
                                _isEditing = false;
                              });
                            } else {
                              // ✅ User clicked EDIT button - enter edit mode
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
                      // ✅ PROFILE COMPLETION CARD
                      _buildProfileCompletionCard(),

                      SizedBox(height: 20),

                      // ✅ STATS CARDS (from Firebase)
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
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Address Section
                      _buildSection(
                        'Address',
                        Icons.location_on_outlined,
                        child: _buildPremiumInfoCard(
                          children: [
                            _buildEditableField(
                              label: 'Street Address',
                              icon: Icons.home_outlined,
                              initialValue: _address,
                              onSaved: (value) => _address = value!,
                            ),
                            _buildDivider(),
                            // _buildEditableField(
                            //   label: 'City',
                            //   icon: Icons.location_city_outlined,
                            //   initialValue: _city,
                            //   onSaved: (value) => _city = value!,
                            // ),
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
                              prefixIcon: Icons.location_city_outlined,
                              primaryColor: AppColors.primaryColor,
                              secondaryColor: AppColors.secondaryColor,
                              isEditing:
                                  _isEditing, // Set to false for preview mode
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // ✅ FAVORITE SERVICES (from Firebase)
                      if (_favoriteServices.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Favorite Services',
                          Icons.star_outline,
                        ),
                        SizedBox(height: 16),
                        ..._favoriteServices.map(
                          (service) => _buildServiceCard(service),
                        ),
                        SizedBox(height: 24),
                      ],

                      // ✅ BOOKING HISTORY (from Firebase)
                      _buildSectionHeader('Recent Bookings', Icons.history),
                      SizedBox(height: 16),

                      if (_recentBookings.isEmpty)
                        _buildEmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: 'No bookings yet',
                        )
                      else
                        ..._recentBookings.map(
                          (booking) => Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _buildBookingCard(
                              handymanName: booking['handymanName'],
                              service: booking['service'],
                              date: booking['date'],
                              status: booking['status'],
                              statusColor: _getStatusColor(booking['status']),
                              // price: booking['price'],
                              rating: booking['rating'],
                            ),
                          ),
                        ),

                      SizedBox(height: 24),

                      // Quick Actions
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
                              onTap: () {
                                AppRoutes.toInvoices();
                                // Get.snackbar(
                                //   'Coming Soon',
                                //   'Invoices feature is under development',
                                //   snackPosition: SnackPosition.BOTTOM,
                                // );
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: FontAwesomeIcons.bell,
                              label: 'Notifications',
                              color: Color(0xFFFF9800),
                              onTap: () {
                                AppRoutes.toClientNotifications();
                                // Get.snackbar(
                                //   'Coming Soon',
                                //   'Notifications feature is under development',
                                //   snackPosition: SnackPosition.BOTTOM,
                                // );
                              },
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
                              onTap: () {
                                AppRoutes.toPayments();
                                // Get.snackbar(
                                //   'Coming Soon',
                                //   'Payments feature is under development',
                                //   snackPosition: SnackPosition.BOTTOM,
                                // );
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: FontAwesomeIcons.gear,
                              label: 'Settings',
                              color: Color(0xFF757575),
                              onTap: () {
                                AppRoutes.toClientSettings();
                                // Get.snackbar(
                                //   'Coming Soon',
                                //   'Settings feature is under development',
                                //   snackPosition: SnackPosition.BOTTOM,
                                // );
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

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

  // ✅ UI WIDGETS (Same as HandymanProfilePage)

  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        // Skeleton AppBar
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.backgroundColor(context),
          automaticallyImplyLeading: false,
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
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Skeleton Name
                        Container(
                          width: 150,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        SizedBox(height: 8),
                        // Skeleton Badge
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
              ],
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
                // Skeleton Profile Completion Card
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

                // Skeleton Section 1
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 180),
                SizedBox(height: 24),

                // Skeleton Section 2
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 120),
                SizedBox(height: 24),

                // Skeleton Bookings
                _buildSkeletonSectionHeader(),
                SizedBox(height: 16),
                _buildSkeletonCard(height: 100),
                SizedBox(height: 12),
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

  Widget _buildSkeletonCard({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
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
          child: _isEditing
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

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
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
  }

  Widget _buildBookingCard({
    required String handymanName,
    required String service,
    required String date,
    required String status,
    required Color statusColor,
    // required String price,
    double? rating,
  }) {
    return Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  SizedBox(height: 8),
                  // Text(
                  //   price,
                  //   style: TextStyle(
                  //     fontWeight: FontWeight.bold,
                  //     fontSize: 16,
                  //     color: AppColors.primaryColor,
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
          if (rating != null) ...[
            SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            SizedBox(height: 12),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating.floor() ? Icons.star : Icons.star_border,
                    color: Color(0xFFFFB800),
                    size: 18,
                  );
                }),
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

  Widget _buildPremiumLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showUltraLuxuryLogoutDialog,
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
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
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
  }

  // ✅ HELPER: Get status color
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
}

// Custom Painter for Background Pattern (Same as HandymanProfilePage)
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
