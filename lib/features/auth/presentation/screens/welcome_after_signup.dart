import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/admin_notification_service.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:fixilya_app/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// import 'package:get/get.dart';

class WelcomeAfterSignup extends StatefulWidget {
  final String userType;
  final String userName;

  const WelcomeAfterSignup({
    super.key,
    required this.userType,
    required this.userName,
  });

  @override
  State<WelcomeAfterSignup> createState() => _WelcomeAfterSignupState();
}

class _WelcomeAfterSignupState extends State<WelcomeAfterSignup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveProfileWithSkip({required String userType}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not found');

      // ✅ CRITICAL: Verify token is ready and has correct claims
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('🔄 Verifying token readiness before API call...');

      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser;

      if (freshUser != null) {
        // Get token with force refresh
        final token = await freshUser.getIdToken(true);
        if (token == null) {
          throw Exception('Failed to get authentication token');
        }

        // Verify token has correct claims
        final idTokenResult = await freshUser.getIdTokenResult(true);
        if (kDebugMode) debugPrint('📋 Token claims: ${idTokenResult.claims}');
        if (kDebugMode) debugPrint('   Email Verified: ${idTokenResult.claims?['email_verified']}');
        if (kDebugMode) debugPrint('   User Type: ${idTokenResult.claims?['userType']}');

        if (idTokenResult.claims?['email_verified'] != true) {
          if (kDebugMode) debugPrint('⚠️ Warning: email_verified claim is not true');
        }

        // ✅ Wait for token to propagate
        await Future.delayed(Duration(milliseconds: 500));
        if (kDebugMode) debugPrint('✅ Token verified and ready');
      }

      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Show progress dialog
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
                    'Setting up your profile...',
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

      //!SECTION Complete profile with skip API call
      //! this will fill all the values with default ones and set profileCompleted to false, so the user can complete it later from the profile page
      //! and push notification to admin if it's a handyman to review and approve the profile later
      final result = await _userService.completeProfileSkip(
        uid: user.uid,
        userType: widget.userType,
      );

      // Close dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (result['success']) {
        // Show success
        Get.snackbar(
          'Success!',
          result['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          icon: Icon(Icons.check_circle, color: Colors.white),
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          duration: Duration(seconds: 2),
        );

        await Future.delayed(Duration(milliseconds: 500));
        AppRoutes.toHome();
      } else {
        throw Exception(result['message'] ?? 'Failed to save profile');
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (kDebugMode) debugPrint('❌ DioException: ${e.response?.statusCode}');
      if (kDebugMode) debugPrint('❌ Response: ${e.response?.data}');

      Get.snackbar(
        'Error',
        e.response?.data['message'] ??
            'Failed to save profile. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (kDebugMode) debugPrint('❌ Exception: $e');

      Get.snackbar(
        'Error',
        'Failed to save profile. Please check your connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHandyman = widget.userType.toLowerCase() == 'handyman';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.appHeaderGradientThemed(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Spacer(flex: 1),

              // Success Icon with Animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: Offset(0, 15),
                      ),
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),

              SizedBox(height: 40),

              // Welcome Text
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        'Welcome, ${widget.userName}!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Account created successfully!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(flex: 1),

              // Info Card
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor(context),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Icon with gradient background
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryColor.withValues(alpha: 0.1),
                                  AppColors.secondaryColor.withValues(
                                    alpha: 0.05,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: FaIcon(
                              isHandyman
                                  ? FontAwesomeIcons.toolbox
                                  : FontAwesomeIcons.userTie,
                              size: 44,
                              color: AppColors.primaryColor,
                            ),
                          ),

                          SizedBox(height: 20),

                          Text(
                            isHandyman
                                ? 'Complete Your Handyman Profile'
                                : 'Complete Your Profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 12),

                          Text(
                            isHandyman
                                ? 'Let clients know about your skills, experience, and previous work to get more bookings!'
                                : 'Add your location and preferences to find the best handymen near you!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondaryColor(context),
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Spacer(flex: 1),

              // Buttons
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Complete Profile Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            // ✅ Use GetX navigation
                            AppRoutes.toProfileSetup(widget.userType);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline_rounded, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Complete Profile',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Skip Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            _saveProfileWithSkip(userType: widget.userType);
                            // ✅ Use GetX navigation
                            // AppRoutes.toHome();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Skip for now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
