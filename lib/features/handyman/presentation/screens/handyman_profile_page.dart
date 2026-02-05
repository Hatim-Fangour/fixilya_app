import 'dart:io';
import 'dart:ui';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/features/auth/presentation/screens/login_screen.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/profile_service.dart';
import 'package:get/get.dart'; // ✅ Add this
import 'package:fixilya_app/data/controllers/theme_controller.dart'; // ✅ Add this
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class HandymanProfilePage extends StatefulWidget {
  const HandymanProfilePage({Key? key}) : super(key: key);

  @override
  State<HandymanProfilePage> createState() => _HandymanProfilePageState();
}

class _HandymanProfilePageState extends State<HandymanProfilePage>
    with TickerProviderStateMixin {
  final _profileService = ProfileService();

  bool _isEditing = false;
  int _profileCompletion = 0;
  bool _isAvailable = true;
  bool _isPickingImage = false;
  Map<String, dynamic>? _statsData;

  // ✅ ADD: For image upload
  bool _isUploadingPortfolioImage = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Premium Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  // ✅ ADD THESE NEW VARIABLES
  final _handymanDataService = HandymanDataService();
  bool _isLoadingData = true;
  Map<String, dynamic>? _profileData;

  // ✅ Add helper methods for theme-aware colors
  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).brightness == Brightness.dark
      ? Color(0xFF1E1E1E)
      : Colors.white;
  Color get _textColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87;
  Color get _subtextColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[400]!
      : Colors.grey[600]!;
  Color get _dividerColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[800]!
      : Colors.grey.shade200;
  Color get _borderColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[700]!
      : Colors.grey.shade200;

  // Handyman data
  final _formKey = GlobalKey<FormState>();
  String _name = 'Ahmed El Fassi';
  String _email = 'ahmed.fassi@handyman.ma';
  String _phone = '+212 6 12 34 56 78';
  String _city = 'Casablanca';
  String _experience = '8 years';
  String _bio =
      'Premium electrical professional specializing in residential and commercial projects with a focus on quality and safety.';
  double _hourlyRate = 150.0;

  // Skills
  List<Map<String, dynamic>> skills = [
    {'name': 'Electrical Wiring', 'icon': FontAwesomeIcons.bolt, 'price': 150},
    {'name': 'Panel Installation', 'icon': FontAwesomeIcons.plug, 'price': 200},
    {'name': 'Smart Home Setup', 'icon': FontAwesomeIcons.house, 'price': 180},
  ];

  // Previous work
  List<Map<String, dynamic>> previousWork = [];

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

    // ✅ ADD THIS LINE
    _loadProfileData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

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
    if (_hourlyRate > 0) completedFields++;
    if (_bio.isNotEmpty && _bio.length >= 20) completedFields++;
    if (skills.isNotEmpty) completedFields++;
    if (_profileData?['profilePicture']?.toString().isNotEmpty ?? false)
      completedFields++;
    if ((_profileData?['workImages'] as List?)?.isNotEmpty ?? false)
      completedFields++;

    return (completedFields / totalFields * 100).round();
  }

  // ✅ ADD THIS NEW METHOD
  Future<void> _loadProfileData() async {
    setState(() => _isLoadingData = true);

    try {
      final profileData = await _handymanDataService.getHandymanProfile();
      final statsData = await _handymanDataService.getHandymanStats();
      final isAvailable = await _handymanDataService.getAvailabilityStatus();

      print('profileData : $profileData');

      if (profileData != null) {
        setState(() {
          _profileData = profileData;
          _statsData = statsData;

          _name = profileData['fullName'] ?? 'Handyman';
          _email = profileData['email'] ?? '';
          _phone = profileData['phone'] ?? '';
          _city = profileData['city'] ?? '';
          _experience = profileData['experience'] ?? '';
          _bio = profileData['bio'] ?? '';
          _hourlyRate = (profileData['hourlyRate'] is int)
              ? (profileData['hourlyRate'] as int).toDouble()
              : (profileData['hourlyRate'] ?? 0.0);
          _isAvailable = isAvailable;

          // Load skills
          if (profileData['skills'] != null && profileData['skills'] is List) {
            final skillsData = profileData['skills'] as List;
            skills = skillsData.map((skillItem) {
              if (skillItem is String) {
                return {
                  'name': skillItem,
                  'icon': _getSkillIcon(skillItem),
                  'price': _hourlyRate.toInt(),
                };
              } else if (skillItem is Map) {
                final skillName = skillItem['name'] ?? '';
                final hourlyRate = skillItem['hourlyRate'] ?? _hourlyRate;
                return {
                  'name': skillName,
                  'icon': _getSkillIcon(skillName),
                  'price': (hourlyRate is int)
                      ? hourlyRate
                      : (hourlyRate as double).toInt(),
                };
              } else {
                return {
                  'name': 'Unknown',
                  'icon': _getSkillIcon('Unknown'),
                  'price': _hourlyRate.toInt(),
                };
              }
            }).toList();
          }

          // ✅ Load work images ONLY (simplified)
          if (profileData['workImages'] != null &&
              profileData['workImages'] is List) {
            final workImageUrls = profileData['workImages'] as List;
            previousWork = workImageUrls
                .asMap()
                .entries
                .map<Map<String, dynamic>>((entry) {
                  return <String, dynamic>{
                    // ✅ Explicit type
                    'id': 'image_${entry.key}',
                    'image': entry.value as String,
                  };
                })
                .toList();
          }

          _profileCompletion = _calculateProfileCompletion();
          _isLoadingData = false;
        });

        print('✅ Profile loaded with ${previousWork.length} images');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoadingData = false);
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
  Future<void> _saveProfileToFirebase() async {
    try {
      print('💾 Saving profile to Firebase...');

      // Convert skills
      final skillsData = skills
          .map((skill) => {'name': skill['name'], 'hourlyRate': skill['price']})
          .toList();

      // ✅ Convert portfolio to Firebase format
      final portfolioData = previousWork
          .map(
            (project) => {
              'id': project['id'],
              'title': project['title'],
              'clientName': project['client'],
              'date': project['date'],
              'imageUrl': project['image'],
              'description': project['description'] ?? '',
              'createdAt': FieldValue.serverTimestamp(),
            },
          )
          .toList();

      final success = await _handymanDataService.updateHandymanProfile({
        'fullName': _name,
        'email': _email,
        'phone': _phone,
        'city': _city,
        'experience': _experience,
        'hourlyRate': _hourlyRate,
        'bio': _bio,
        'skills': skillsData,
        'portfolio': portfolioData, // ✅ Save portfolio
      });

      if (success) {
        print('✅ Profile saved to Firebase successfully');
        print('   Portfolio projects: ${portfolioData.length}');
      } else {
        print('⚠️ Profile save returned false');
      }
    } catch (e) {
      print('❌ Error saving profile: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

                                                print('✅ Logout successful');

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
                                                print('❌ Logout error: $e');

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

  void _showEditPriceDialog(Map<String, dynamic> skill) {
    final priceController = TextEditingController(
      text: skill['price'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price - ${skill['name']}'),
        content: TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Hourly Rate (DH)',
            suffixText: 'DH/hour',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPrice = int.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                setState(() => skill['price'] = newPrice);
                Get.back();
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog() {
    List<XFile> selectedImages = []; // ✅ List of selected images
    List<String> uploadedUrls = []; // ✅ Uploaded Cloudinary URLs
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
                    color: primaryColor.withValues(alpha: 0.3),
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
                    // ✨ Premium Header
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
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
                            onPressed: () => Get.back(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            iconSize: 28,
                          ),
                        ],
                      ),
                    ),

                    // 📸 Content Area
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // ✨ Select Images Button
                            GestureDetector(
                              onTap: isUploading
                                  ? null
                                  : () async {
                                      try {
                                        final ImagePicker picker =
                                            ImagePicker();
                                        // ✅ Pick MULTIPLE images
                                        final List<XFile> images = await picker
                                            .pickMultiImage(imageQuality: 85);

                                        if (images.isNotEmpty) {
                                          setDialogState(() {
                                            selectedImages = images;
                                          });
                                        }
                                      } catch (e) {
                                        print('❌ Picker error: $e');
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
                                      primaryColor.withValues(alpha: 0.1),
                                      secondaryColor.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.3),
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
                                              primaryColor,
                                              secondaryColor,
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withValues(
                                                alpha: 0.3,
                                              ),
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
                                            : '${selectedImages.length} images selected',
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

                            // ✅ Preview Selected Images
                            if (selectedImages.isNotEmpty)
                              Container(
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
                                          color: primaryColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(
                                              File(selectedImages[index].path),
                                              fit: BoxFit.cover,
                                            ),
                                            // Remove button
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setDialogState(() {
                                                    selectedImages.removeAt(
                                                      index,
                                                    );
                                                  });
                                                },
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

                    // ✨ Action Buttons
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

                                      try {
                                        print(
                                          '📤 Uploading ${selectedImages.length} images...',
                                        );

                                        final cloudinaryService =
                                            Get.find<CloudinaryService>();

                                        // ✅ Upload all images
                                        for (var imageFile in selectedImages) {
                                          final imageUrl =
                                              await cloudinaryService
                                                  .uploadImage(
                                                    imageFile: File(
                                                      imageFile.path,
                                                    ),
                                                    folder: 'portfolio',
                                                  );

                                          if (imageUrl != null &&
                                              imageUrl.isNotEmpty) {
                                            uploadedUrls.add(imageUrl);
                                          }
                                        }

                                        print(
                                          '✅ ${uploadedUrls.length} images uploaded',
                                        );

                                        if (uploadedUrls.isNotEmpty) {
                                          // ✅ STEP 1: Add to local list
                                          for (var url in uploadedUrls) {
                                            previousWork.add({
                                              // 'id': "234",
                                              'id':
                                                  'image_${DateTime.now().millisecondsSinceEpoch}_${previousWork.length}',
                                              'image': url,
                                            });
                                          }

                                          // ✅ STEP 2: Save to Firebase
                                          final workImages = previousWork
                                              .map(
                                                (work) =>
                                                    work['image'] as String,
                                              )
                                              .toList();

                                          await _handymanDataService
                                              .updateHandymanProfile({
                                                'workImages': workImages,
                                              });

                                          Get.back();

                                          // ✅ STEP 3: Trigger rebuild
                                          setState(() {});

                                          Get.snackbar(
                                            'Success',
                                            '${uploadedUrls.length} images added to portfolio!',
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.green,
                                            colorText: Colors.white,
                                            margin: EdgeInsets.all(16),
                                            borderRadius: 12,
                                            icon: Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        print('❌ Upload error: $e');

                                        setDialogState(
                                          () => isUploading = false,
                                        );

                                        Get.snackbar(
                                          'Error',
                                          'Upload failed: ${e.toString()}',
                                          snackPosition: SnackPosition.BOTTOM,
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                          margin: EdgeInsets.all(16),
                                          borderRadius: 12,
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shadowColor: primaryColor.withValues(
                                  alpha: 0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isUploading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
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
  // ✨ LUXURY TEXT FIELD WIDGET

  Widget _buildLuxuryTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Container(
                margin: EdgeInsets.all(12),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.1),
                      secondaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 16 : 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  void _showEditProjectDialog(Map<String, dynamic> work) {
    final titleController = TextEditingController(text: work['title']);
    final clientController = TextEditingController(text: work['client']);
    final dateController = TextEditingController(text: work['date']);
    final descriptionController = TextEditingController(
      text: work['description'],
    );
    String currentImageUrl = work['image'] ?? '';
    String? newImageUrl;
    bool isUploading = false;

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
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Text('Edit Project', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Display/Change
                  Stack(
                    children: [
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: currentImageUrl.isNotEmpty
                              ? Image.network(
                                  currentImageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.image, size: 48),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, color: primaryColor),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 80,
                                    );

                                    if (image != null) {
                                      setDialogState(() => isUploading = true);

                                      try {
                                        final cloudinaryService =
                                            Get.find<CloudinaryService>();
                                        final imageUrl = await cloudinaryService
                                            .uploadImage(
                                              imageFile: File(image.path),
                                              folder: 'portfolio',
                                            );

                                        setDialogState(() {
                                          newImageUrl = imageUrl ?? '';
                                          currentImageUrl = imageUrl ?? '';
                                          isUploading = false;
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Image updated!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        setDialogState(
                                          () => isUploading = false,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to upload image',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ),
                      if (isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Same fields as Add dialog
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Project Title',
                      prefixIcon: Icon(Icons.title, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  TextField(
                    controller: clientController,
                    decoration: InputDecoration(
                      labelText: 'Client Name',
                      prefixIcon: Icon(Icons.person, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text =
                            '${_getMonthName(picked.month)} ${picked.day}, ${picked.year}';
                      }
                    },
                  ),
                  SizedBox(height: 12),

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      prefixIcon: Icon(Icons.description, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () {
                        if (titleController.text.trim().isEmpty ||
                            clientController.text.trim().isEmpty ||
                            dateController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please fill all required fields'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // Update the project
                        setState(() {
                          work['title'] = titleController.text.trim();
                          work['client'] = clientController.text.trim();
                          work['date'] = dateController.text.trim();
                          work['description'] = descriptionController.text
                              .trim();
                          if (newImageUrl != null) {
                            work['image'] = newImageUrl!;
                          }
                        });

                        Get.back();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Project updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteProjectDialog(Map<String, dynamic> work) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Delete Project?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this project?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work['title'] ?? 'Untitled',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Client: ${work['client']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                previousWork.remove(work);
              });

              Get.back();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Project deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Delete'),
          ),
        ],
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
                    return Container(
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
              SizedBox(height: 20),
              Text(
                'Loading profile...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      // backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.cardColor(context),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor, secondaryColor, accentColor],
                      ),
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
                                    color: _textColor,
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
                                        color: primaryColor,
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
                                Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Verified Professional',
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

                          // Rating
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
                                  Icons.star,
                                  color: Color(0xFFFFB800),
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '4.8',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '(127 reviews)',
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

                  // Edit Button
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
                        _buildGlassButton(
                          icon: _isEditing ? Icons.check : Icons.edit,
                          onPressed: () async {
                            setState(() {
                              if (_isEditing &&
                                  _formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                // ✅ ADD THIS LINE
                                _saveProfileToFirebase();
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
                                    backgroundColor: primaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }

                              _isEditing = !_isEditing;
                            });
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
                      _buildProfileCompletionCard(),

                      SizedBox(height: 20),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildPremiumStatCard(
                              icon: FontAwesomeIcons.briefcase,
                              value: '${_statsData?['completedJobs'] ?? 0}',
                              label: 'Jobs Completed',
                              gradient: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                              iconColor: Color(0xFF2196F3),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildPremiumStatCard(
                              icon: FontAwesomeIcons.clock,
                              value: _experience,
                              label: 'Experience',
                              gradient: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                              iconColor: Color(0xFFFF6F00),
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
                            _buildDivider(),
                            _buildEditableField(
                              label: 'City',
                              icon: Icons.location_city_outlined,
                              initialValue: _city,
                              onSaved: (value) => _city = value!,
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
                            _buildDivider(),
                            _buildEditableField(
                              label: 'Hourly Rate (DH)',
                              icon: Icons.attach_money,
                              initialValue: _hourlyRate.toString(),
                              keyboardType: TextInputType.number,
                              onSaved: (value) =>
                                  _hourlyRate = double.parse(value!),
                            ),
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
                                          color: primaryColor,
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
                                            color: primaryColor,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Professional Bio',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
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
                                          color: Colors.black87,
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

                      ...skills
                          .map((skill) => _buildPremiumSkillCard(skill))
                          .toList(),

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

                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: previousWork.length + (_isEditing ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index == previousWork.length && !_isEditing) {
                            return _buildAddWorkCard();
                          }

                          final work = previousWork[index];
                          return _buildPremiumWorkCard(work, index);
                        },
                      ),

                      SizedBox(height: 24),

                      // Availability Toggle
                      _buildAvailabilityCard(),

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

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
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
              child: Container(
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
          color: primaryColor.withValues(alpha: 0.2),
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
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete your profile to get more clients',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
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
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
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
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
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
            gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
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
            color: Colors.black87,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
      child: Divider(height: 1, color: Colors.grey.shade200),
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
                primaryColor.withValues(alpha: 0.1),
                secondaryColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
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
                    labelStyle: TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
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
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      initialValue,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
            primaryColor.withValues(alpha: 0.1),
            secondaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
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
                Icon(Icons.add, color: primaryColor, size: 18),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: primaryColor,
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
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                        primaryColor.withValues(alpha: 0.15),
                        secondaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(skill['icon'], color: primaryColor, size: 20),
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
                          color: Colors.black87,
                        ),
                      ),
                      _isEditing
                          ? _buildEditablePrice(skill)
                          : Text('${skill['price']} DH/hour'),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.payments, size: 14, color: primaryColor),
                          SizedBox(width: 4),
                          Text(
                            '${skill['price']} DH/hour',
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildEditablePrice(Map<String, dynamic> skill) {
    return InkWell(
      onTap: () => _showEditPriceDialog(skill),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${skill['price']} DH/hour'),
            SizedBox(width: 8),
            Icon(Icons.edit, size: 16, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkCard(Map<String, dynamic> work) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: work['image'] ?? ''.isNotEmpty
                      ? Image.network(
                          work['image'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                ),

                // Details
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 6),
                          Text(
                            work['client'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 6),
                          Text(
                            work['date'] ?? 'Recent',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (work['description']?.isNotEmpty ?? false) ...[
                        SizedBox(height: 8),
                        Text(
                          work['description']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ ADD: Edit and Delete buttons (only in edit mode)
          if (_isEditing)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  // Edit button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit, color: primaryColor, size: 20),
                      onPressed: () => _showEditProjectDialog(work),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Delete button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _showDeleteProjectDialog(work),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddWorkCard() {
    return InkWell(
      onTap: _showAddProjectDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate,
                color: Colors.white,
                size: 29,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'New Project',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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

                      // Update Firebase
                      final workImages = previousWork
                          .map((work) => work['image'] as String)
                          .toList();

                      await _handymanDataService.updateHandymanProfile({
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
    String skillName = '';
    double skillPrice = 0;
    IconData selectedIcon = FontAwesomeIcons.wrench;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text('Add New Skill', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Skill Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.build, color: primaryColor),
              ),
              onChanged: (value) => skillName = value,
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Price (DH/hour)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.attach_money, color: primaryColor),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => skillPrice = double.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                if (skillName.isNotEmpty && skillPrice > 0) {
                  setState(() {
                    skills.add({
                      'name': skillName,
                      'icon': selectedIcon,
                      'price': skillPrice.toInt(),
                    });
                  });
                  Get.back();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Add Skill'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWorkDialog() {
    String title = '';
    String client = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_photo_alternate,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text('Add Portfolio Item', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Project Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.work, color: primaryColor),
              ),
              onChanged: (value) => title = value,
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Client Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.person, color: primaryColor),
              ),
              onChanged: (value) => client = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty && client.isNotEmpty) {
                  setState(() {
                    previousWork.add({
                      'title': title,
                      'client': client,
                      'date': 'Today',
                      'image':
                          'https://picsum.photos/300/300?random=${previousWork.length + 10}',
                    });
                  });
                  Get.back();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Add to Portfolio'),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkDetails(Map<String, dynamic> work) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildGlassButton(
                  icon: Icons.close,
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Image.network(work['image'] ?? '', height: 300),
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            work['title'] ?? 'Untitled',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: primaryColor),
                              SizedBox(width: 6),
                              Text('Client: ${work['client'] ?? 'Unknown'}'),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: primaryColor,
                              ),
                              SizedBox(width: 6),
                              Text('Date: ${work['date'] ?? 'Recent'}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
