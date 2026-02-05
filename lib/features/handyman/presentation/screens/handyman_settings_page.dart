import 'dart:io';
import 'dart:ui';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class HandymanSettingsPage extends StatefulWidget {
  const HandymanSettingsPage({Key? key}) : super(key: key);

  @override
  State<HandymanSettingsPage> createState() => _HandymanSettingsPageState();
}

class _HandymanSettingsPageState extends State<HandymanSettingsPage>
    with SingleTickerProviderStateMixin {
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  final _handymanDataService = HandymanDataService();
  final _authService = AuthService();

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  // Settings
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = true;
  bool _isAvailable = true;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final profileData = await _handymanDataService.getHandymanProfile();

      if (profileData != null) {
        setState(() {
          _profileData = profileData;
          _isAvailable = profileData['isAvailable'] ?? true;
          _pushNotifications = profileData['pushNotifications'] ?? true;
          _emailNotifications = profileData['emailNotifications'] ?? false;
          _smsNotifications = profileData['smsNotifications'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSettings(Map<String, dynamic> updates) async {
    try {
      final success = await _handymanDataService.updateHandymanProfile(updates);

      if (success) {
        Get.snackbar(
          'Success',
          'Settings updated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: EdgeInsets.all(16),
          borderRadius: 16,
          icon: Icon(Icons.check_circle, color: Colors.white),
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update settings',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 16,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor, accentColor],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Loading Settings...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium App Bar with Profile
          _buildLuxuryAppBar(),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),

                  // Availability Section
                  // _buildLuxurySection(
                  //   'Availability',
                  //   Icons.access_time_rounded,
                  //   [
                  //     _buildLuxurySwitchTile(
                  //       'Available for Work',
                  //       'Toggle to accept new bookings',
                  //       Icons.work_outline_rounded,
                  //       _isAvailable,
                  //       (value) async {
                  //         setState(() => _isAvailable = value);
                  //         _updateSettings({'isAvailable': value});
                  //         final success = await _handymanDataService
                  //             .updateAvailabilityStatus(value);
                  //       },
                  //     ),
                  //   ],
                  // ),

                  // SizedBox(height: 24),

                  // Notifications Section
                  _buildLuxurySection(
                    'Notifications',
                    Icons.notifications_active_outlined,
                    [
                      _buildLuxurySwitchTile(
                        'Push Notifications',
                        'Receive instant updates',
                        Icons.notifications_rounded,
                        _pushNotifications,
                        (value) {
                          setState(() => _pushNotifications = value);
                          _updateSettings({'pushNotifications': value});
                        },
                      ),
                      _buildLuxurySwitchTile(
                        'Email Notifications',
                        'Get updates via email',
                        Icons.email_outlined,
                        _emailNotifications,
                        (value) {
                          setState(() => _emailNotifications = value);
                          _updateSettings({'emailNotifications': value});
                        },
                      ),
                      _buildLuxurySwitchTile(
                        'SMS Notifications',
                        'Receive text alerts',
                        Icons.message_outlined,
                        _smsNotifications,
                        (value) {
                          setState(() => _smsNotifications = value);
                          _updateSettings({'smsNotifications': value});
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Account Section
                  _buildLuxurySection('Account', Icons.person_outline_rounded, [
                    _buildLuxuryListTile(
                      'Edit Profile Information',
                      'Update your personal details',
                      Icons.edit_outlined,
                      () => _showEditProfileDialog(),
                    ),
                    _buildLuxuryListTile(
                      'Change Profile Picture',
                      'Upload a new photo',
                      Icons.camera_alt_outlined,
                      () => _changeProfilePicture(),
                    ),
                    _buildLuxuryListTile(
                      'Change Password',
                      'Update your security',
                      Icons.lock_outline_rounded,
                      () => _showChangePasswordDialog(),
                    ),
                  ]),

                  SizedBox(height: 24),

                  // Support Section
                  _buildLuxurySection(
                    'Support & Legal',
                    Icons.support_agent_outlined,
                    [
                      _buildLuxuryListTile(
                        'Help & Support',
                        'Get assistance',
                        Icons.help_outline_rounded,
                        () => _showHelpSupport(),
                      ),
                      _buildLuxuryListTile(
                        'Terms & Conditions',
                        'Read our terms',
                        Icons.description_outlined,
                        () => _showTerms(),
                      ),
                      _buildLuxuryListTile(
                        'Privacy Policy',
                        'Your data protection',
                        Icons.policy_outlined,
                        () => _showPrivacyPolicy(),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Danger Zone
                  _buildLuxurySection(
                    'Danger Zone',
                    Icons.warning_amber_rounded,
                    [
                      _buildLuxuryListTile(
                        'Delete Account',
                        'Permanently remove your account',
                        Icons.delete_forever_outlined,
                        () => _showDeleteAccountDialog(),
                        isDestructive: true,
                      ),
                      _buildLuxuryListTile(
                        'Logout',
                        'Sign out from your account',
                        Icons.logout_rounded,
                        () => _showLogoutDialog(),
                        isDestructive: true,
                      ),
                    ],
                  ),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryAppBar() {
    final profilePicture = _profileData?['profilePicture'] ?? '';
    final fullName = _profileData?['fullName'] ?? 'Handyman';
    final email = _profileData?['email'] ?? '';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryColor,
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
              child: CustomPaint(painter: _CirclePatternPainter()),
            ),

            // Content
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Profile Picture with Glow
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
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
                                    color: Colors.white.withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                backgroundImage: profilePicture.isNotEmpty
                                    ? NetworkImage(profilePicture)
                                    : null,
                                child: profilePicture.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: primaryColor,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 16),

                      // Name
                      Text(
                        fullName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 8),

                      // Email
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxurySection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: Offset(0, 5),
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
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Items Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxurySwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.15),
                  secondaryColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Switch
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: primaryColor,
              activeTrackColor: primaryColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isDestructive
                      ? LinearGradient(
                          colors: [
                            Colors.red.withValues(alpha: 0.15),
                            Colors.red.withValues(alpha: 0.1),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.15),
                            secondaryColor.withValues(alpha: 0.1),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // [Previous dialog methods remain the same - _showEditProfileDialog, _changeProfilePicture, etc.]
  // Copy all the dialog methods from your original file here

  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: _profileData?['fullName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: _profileData?['phone'] ?? '',
    );
    final cityController = TextEditingController(
      text: _profileData?['city'] ?? '',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Profile',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: Duration(milliseconds: 400),
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
                  constraints: BoxConstraints(maxWidth: 500),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.9),
                            ],
                          ),
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
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header with Gradient Icon
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 600),
                                    curve: Curves.elasticOut,
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          padding: EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                primaryColor,
                                                secondaryColor,
                                                accentColor,
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 30,
                                                offset: Offset(0, 15),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  SizedBox(height: 24),

                                  // Title with Gradient
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [primaryColor, accentColor],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: 12),

                                  // Subtitle
                                  Text(
                                    'Update your personal information',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  SizedBox(height: 32),

                                  // Full Name Field
                                  _buildLuxuryTextField(
                                    controller: nameController,
                                    label: 'Full Name',
                                    hint: 'Enter your full name',
                                    icon: Icons.person_rounded,
                                  ),

                                  SizedBox(height: 20),

                                  // Phone Field
                                  _buildLuxuryTextField(
                                    controller: phoneController,
                                    label: 'Phone Number',
                                    hint: 'Enter your phone number',
                                    icon: Icons.phone_rounded,
                                    keyboardType: TextInputType.phone,
                                  ),

                                  SizedBox(height: 20),

                                  // City Field
                                  _buildLuxuryTextField(
                                    controller: cityController,
                                    label: 'City',
                                    hint: 'Enter your city',
                                    icon: Icons.location_city_rounded,
                                  ),

                                  SizedBox(height: 32),

                                  // Action Buttons
                                  Row(
                                    children: [
                                      // Cancel Button
                                      Expanded(
                                        child: Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.grey[100]!,
                                                Colors.grey[50]!,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 2,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              onTap: () => Get.back(),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.close_rounded,
                                                      color: Colors.grey[700],
                                                      size: 22,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey[700],
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

                                      // Save Button
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                primaryColor,
                                                secondaryColor,
                                                accentColor,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 20,
                                                offset: Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              onTap: () async {
                                                // Validate
                                                if (nameController.text
                                                    .trim()
                                                    .isEmpty) {
                                                  Get.snackbar(
                                                    'Required',
                                                    'Please enter your name',
                                                    backgroundColor:
                                                        Colors.orange,
                                                    colorText: Colors.white,
                                                    borderRadius: 16,
                                                    margin: EdgeInsets.all(16),
                                                  );
                                                  return;
                                                }

                                                // Show loading
                                                Get.dialog(
                                                  Center(
                                                    child: Container(
                                                      padding: EdgeInsets.all(
                                                        32,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              24,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                            blurRadius: 30,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(primaryColor),
                                                            strokeWidth: 3,
                                                          ),
                                                          SizedBox(height: 24),
                                                          Text(
                                                            'Updating profile...',
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
                                                  barrierDismissible: false,
                                                );

                                                try {
                                                  await _updateSettings({
                                                    'fullName': nameController
                                                        .text
                                                        .trim(),
                                                    'phone': phoneController
                                                        .text
                                                        .trim(),
                                                    'city': cityController.text
                                                        .trim(),
                                                  });

                                                  // Close loading
                                                  if (Get.isDialogOpen ?? false)
                                                    Get.back();

                                                  // Close edit dialog
                                                  Get.back();

                                                  // Reload data
                                                  await _loadSettings();

                                                  // Success message
                                                  Get.snackbar(
                                                    'Success',
                                                    'Profile updated successfully!',
                                                    snackPosition:
                                                        SnackPosition.BOTTOM,
                                                    backgroundColor:
                                                        Colors.green,
                                                    colorText: Colors.white,
                                                    margin: EdgeInsets.all(16),
                                                    borderRadius: 16,
                                                    icon: Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.white,
                                                    ),
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
                                                  );
                                                } catch (e) {
                                                  // Close loading
                                                  if (Get.isDialogOpen ?? false)
                                                    Get.back();

                                                  // Error message
                                                  Get.snackbar(
                                                    'Error',
                                                    'Failed to update profile',
                                                    snackPosition:
                                                        SnackPosition.BOTTOM,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    margin: EdgeInsets.all(16),
                                                    borderRadius: 16,
                                                  );
                                                }
                                              },
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.check_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Save Changes',
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.white,
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
                                          Colors.blue[50]!,
                                          Colors.indigo[50]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.info_outline_rounded,
                                            color: Colors.blue[700],
                                            size: 16,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Changes will be saved to your account',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[900],
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
          ),
        );
      },
    );
  }

  // Helper method for luxury text fields
  Widget _buildLuxuryTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Text Field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
              prefixIcon: Container(
                margin: EdgeInsets.all(12),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.15),
                      secondaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 2.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      Get.dialog(
        Center(
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Uploading...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final cloudinaryService = Get.find<CloudinaryService>();
      final imageUrl = await cloudinaryService.uploadImage(
        imageFile: File(image.path),
        folder: 'profiles',
      );

      Get.back();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _updateSettings({'profilePicture': imageUrl});
        _loadSettings();
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Failed to upload image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 16,
      );
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.lock, color: Colors.white, size: 22),
            ),
            SizedBox(width: 14),
            Text(
              'Change Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  Get.snackbar(
                    'Error',
                    'Passwords do not match',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    borderRadius: 16,
                  );
                  return;
                }
                try {
                  await _authService.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  Get.back();
                  Get.snackbar(
                    'Success',
                    'Password changed successfully',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    borderRadius: 16,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    e.toString(),
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    borderRadius: 16,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('Change Password'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Delete Account?'),
          ],
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Info',
                'Account deletion coming soon',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                borderRadius: 16,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
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
                                              primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              secondaryColor.withValues(
                                                alpha: 0.05,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: primaryColor.withValues(
                                              alpha: 0.3,
                                            ),
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
                                                    color: primaryColor,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Stay',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: primaryColor,
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
                                            colors: [
                                              Color(0xFFFF6B6B),
                                              Color(0xFFEE5A6F),
                                              Color(0xFFC06C84),
                                            ],
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
                                                          32,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                24,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.2,
                                                                  ),
                                                              blurRadius: 30,
                                                            ),
                                                          ],
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
                                                                    primaryColor,
                                                                  ),
                                                              strokeWidth: 3,
                                                            ),
                                                            SizedBox(
                                                              height: 24,
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
                                                await _authService.signOut();

                                                print('✅ Logout successful');

                                                // Close loading dialog (if still open)
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }

                                                // Navigate to welcome screen
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
                                                  borderRadius: 16,
                                                  icon: Icon(
                                                    Icons.check_circle_rounded,
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
                                                  borderRadius: 16,
                                                  icon: Icon(
                                                    Icons.error_outline_rounded,
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
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Logout Now',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
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
                                        Colors.blue[50]!,
                                        Colors.indigo[50]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          color: Colors.blue[700],
                                          size: 16,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Your data is safe & secure',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[900],
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

  void _showPrivacySettings() {
    Get.snackbar('Info', 'Privacy settings coming soon', borderRadius: 16);
  }

  void _showHelpSupport() {
    Get.snackbar('Info', 'Help & support coming soon', borderRadius: 16);
  }

  void _showTerms() {
    Get.snackbar('Info', 'Terms & conditions coming soon', borderRadius: 16);
  }

  void _showPrivacyPolicy() {
    Get.snackbar('Info', 'Privacy policy coming soon', borderRadius: 16);
  }
}

// Custom Painter for Background Pattern
class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

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
