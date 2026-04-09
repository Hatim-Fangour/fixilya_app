import 'package:flutter/foundation.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Check authentication status
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for animation to complete (minimum 2 seconds for better UX)
    await Future.delayed(Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Get current Firebase user
      final User? currentUser = _authService.getCurrentUser();

      if (kDebugMode) debugPrint(
        currentUser == null
            ? 'No user is currently logged in.'
            : 'User is logged in: ${currentUser.uid} ${currentUser.email}',
      );

      if (currentUser != null) {
        if (kDebugMode) debugPrint('✅ User found: ${currentUser.email}');

        // ✅ Try to reload user with comprehensive error handling
        bool userStillExists = true;

        try {
          await currentUser.reload();
          if (kDebugMode) debugPrint('✅ User reloaded successfully');
        } on FirebaseAuthException catch (e) {
          if (kDebugMode) debugPrint('⚠️ FirebaseAuthException during reload: ${e.code}');

          // ✅ Handle all possible Firebase Auth errors
          switch (e.code) {
            case 'user-not-found':
            case 'ERROR_USER_NOT_FOUND':
              if (kDebugMode) debugPrint('❌ User has been deleted from Firebase');
              userStillExists = false;
              break;

            case 'user-disabled':
              if (kDebugMode) debugPrint('❌ User account has been disabled');
              userStillExists = false;
              break;

            case 'user-token-expired':
            case 'invalid-user-token':
              if (kDebugMode) debugPrint('❌ User token has expired or is invalid');
              userStillExists = false;
              break;

            case 'network-request-failed':
              if (kDebugMode) debugPrint(
                '⚠️ Network error during reload, continuing with cached data',
              );
              // User might still exist, continue with cached data
              break;

            default:
              if (kDebugMode) debugPrint('⚠️ Unknown Firebase error: ${e.code} - ${e.message}');
              // For unknown errors, assume user might still exist
              break;
          }
        } on PlatformException catch (e) {
          // ✅ ADD THIS CATCH BLOCK FOR PlatformException
          if (kDebugMode) debugPrint('⚠️ PlatformException during reload: ${e.code} - ${e.message}');

          // Check for user not found errors
          if (e.code == 'ERROR_USER_NOT_FOUND' ||
              e.code == 'user-not-found' ||
              e.message?.toLowerCase().contains('no user record') == true ||
              e.message?.toLowerCase().contains('user may have been deleted') ==
                  true) {
            if (kDebugMode) debugPrint('❌ User not found (platform exception)');
            userStillExists = false;
          } else if (e.code == 'ERROR_USER_DISABLED' ||
              e.message?.toLowerCase().contains('disabled') == true) {
            if (kDebugMode) debugPrint('❌ User account disabled (platform exception)');
            userStillExists = false;
          } else {
            if (kDebugMode) debugPrint('Other platform error, continuing with cached data');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Unexpected error during reload: $e — continuing with cached data');
        }

        // ✅ If user was deleted, sign out and go to welcome
        if (!userStillExists) {
          if (kDebugMode) debugPrint('🔄 User no longer exists, signing out...');
          await _authService.signOut();
          if (!mounted) return;
          Get.offAllNamed(AppRoutes.welcome);
          return;
        }

        // ✅ Get fresh user instance after reload
        final User? refreshedUser = _authService.getCurrentUser();

        // ✅ Double-check user still exists
        if (refreshedUser == null) {
          if (kDebugMode) debugPrint('❌ User is null after reload');
          await _authService.signOut();
          if (!mounted) return;
          Get.offAllNamed(AppRoutes.welcome);
          return;
        }

        // ✅ Check email verification
        if (!refreshedUser.emailVerified) {
          if (kDebugMode) debugPrint('⚠️ Email not verified, signing out');
          await _authService.signOut();
          if (!mounted) return;
          Get.offAllNamed(AppRoutes.welcome);
          return;
        }

        if (kDebugMode) debugPrint('✅ Email verified');

        // ✅ Get user data from Firestore
        final userData = await _authService.getUserData();

        if (userData != null && userData.isNotEmpty) {
          if (kDebugMode) debugPrint('✅ User data found: ${userData['fullName']}');

          final String userType = userData['userType'] ?? 'client';
          if (kDebugMode) debugPrint('✅ User type: $userType');

          // ✅ Check mounted before navigation
          if (!mounted) return;

          // Navigate to WidgetTree
          Get.offAllNamed(AppRoutes.widgetTree);
        } else {
          if (kDebugMode) debugPrint('⚠️ No user data found in Firestore, signing out');
          await _authService.signOut();

          if (!mounted) return;
          Get.offAllNamed(AppRoutes.welcome);
        }
      } else {
        if (kDebugMode) debugPrint('ℹ️ No user logged in');
        if (!mounted) return;
        Get.offAllNamed(AppRoutes.welcome);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Fatal error in auth check: $e');
      // On any fatal error, sign out and go to welcome
      try {
        await _authService.signOut();
      } catch (signOutError) {
        if (kDebugMode) debugPrint('⚠️ Error during emergency sign out: $signOutError');
      }

      if (mounted) {
        Get.offAllNamed(AppRoutes.welcome);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryColor,
              AppColors.secondaryColor,
              AppColors.accentColor,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.handyman_rounded,
                      size: 60,
                      color: AppColors.primaryColor,
                    ),
                  ),

                  SizedBox(height: 30),

                  // App Name
                  Text(
                    'Fixilya',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10),

                  // Tagline
                  Text(
                    'Your Trusted Handyman Service',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),

                  SizedBox(height: 50),

                  // Loading Indicator
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
