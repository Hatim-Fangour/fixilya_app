import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailVerificationScreen extends StatefulWidget {
  static const String routeName = '/email-verification';

  final String userType;
  final String userName;
  final String email;
  final String phone;
  final String fullName;

  /// `true` when the backend successfully dispatched the verification email
  /// during signup, `false` when the dispatch failed (e.g. invalid SendGrid
  /// key). When `false` the screen shows a warning banner so the user knows
  /// to tap "Resend" instead of waiting forever for an email that won't come.
  final bool emailWasSent;

  const EmailVerificationScreen({
    super.key,
    required this.userType,
    required this.userName,
    required this.email,
    required this.phone,
    required this.fullName,
    this.emailWasSent = true,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();

  // Animation Controllers
  late AnimationController _iconController;
  late AnimationController _contentController;
  late Animation<double> _iconAnimation;
  late Animation<double> _contentAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isVerifying = false;
  bool _canResend = true;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    if (widget.fullName.isEmpty || widget.phone.isEmpty) {
      _fetchUserData();
    }

    // Initialize animations
    _iconController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _iconAnimation = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );

    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_contentAnimation);

    // Start animations
    _iconController.forward();
    Future.delayed(Duration(milliseconds: 300), () {
      _contentController.forward();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        // You might want to store this in state variables if needed
        if (kDebugMode) debugPrint('✅ Fetched user data: ${data?['fullName']}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Could not fetch user data: $e');
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _contentController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend) return;

    setState(() => _canResend = false);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        Get.snackbar(
          'Error',
          'No user logged in',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          icon: Icon(Icons.error_outline, color: Colors.white),
          margin: EdgeInsets.all(16),
          borderRadius: 12,
        );
        setState(() => _canResend = true);
        return;
      }

      if (user.emailVerified) {
        Get.snackbar(
          'Already Verified',
          'Your email is already verified!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          icon: Icon(Icons.check_circle, color: Colors.white),
          margin: EdgeInsets.all(16),
          borderRadius: 12,
        );
        setState(() => _canResend = true);
        return;
      }

      if (!user.emailVerified) {
        // ✅ Call backend API to resend verification email
        final result = await _authService.resendVerificationEmail();

        if (result['success']) {
          Get.snackbar(
            'Email Sent',
            result['message'] ?? 'Verification email sent successfully!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: Colors.white,
            icon: Icon(Icons.check_circle, color: Colors.white),
            margin: EdgeInsets.all(16),
            borderRadius: 12,
          );

          // Start countdown
          setState(() => _resendCountdown = 60);
          _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
            setState(() {
              if (_resendCountdown > 0) {
                _resendCountdown--;
              } else {
                _canResend = true;
                timer.cancel();
              }
            });
          });
        }
      }
    } catch (e) {
      // ✅ Use GetX snackbar for errors

      Get.snackbar(
        'Error',
        'Failed to send email: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
      setState(() => _canResend = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.appHeaderGradientThemed(context),
        ),
        child: SafeArea(
          child: _isVerifying ? _buildVerifying() : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildVerifying() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 32),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor(context).withValues(alpha: 0.2),
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated loading indicator
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Setting up your profile...',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'This will only take a moment',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!widget.emailWasSent) _buildEmailDispatchFailedBanner(),

          Spacer(flex: 1),

          // Animated Email Icon
          ScaleTransition(
            scale: _iconAnimation,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor(
                      context,
                    ).withValues(alpha: 0.15),
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
              child: FaIcon(
                FontAwesomeIcons.envelopeCircleCheck,
                size: 56,
                color: AppColors.primaryColor,
              ),
            ),
          ),

          SizedBox(height: 32),

          // Animated Title
          FadeTransition(
            opacity: _contentAnimation,
            child: Text(
              'Verify Your Email',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: 12),

          // Email Display
          FadeTransition(
            opacity: _contentAnimation,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.borderColor(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.borderColor(context).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.email_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
              opacity: _contentAnimation,
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor(
                        context,
                      ).withValues(alpha: 0.1),
                      blurRadius: 30,
                      offset: Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Instructions
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryColor.withValues(alpha: 0.1),
                            AppColors.secondaryColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check Your Inbox',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimaryColor(context),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'We\'ve sent a verification link to your email. Click it, then return and tap below.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondaryColor(
                                      context,
                                    ),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Verify Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryColor,
                            AppColors.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _handleVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'I\'ve Verified My Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 14),

                    // Resend Email Button
                    TextButton(
                      onPressed: _canResend ? _resendVerificationEmail : null,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: _canResend
                                ? AppColors.primaryColor
                                : AppColors.textHint,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _canResend
                                ? 'Resend Verification Email'
                                : 'Resend in ${_resendCountdown}s',
                            style: TextStyle(
                              color: _canResend
                                  ? AppColors.primaryColor
                                  : AppColors.textHint,
                              fontWeight: FontWeight.w600,
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
          ),

          SizedBox(height: 20),

          // Spam Folder Tip
          FadeTransition(
            opacity: _contentAnimation,
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.borderColor(context).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Check your spam folder',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // ✅ Use GetX navigation
                AppRoutes.offAll(AppRoutes.welcome);
              },
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 16,
              ),
              label: Text(
                'Go Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          Spacer(flex: 1),
        ],
      ),
    );
  }

  /// Check email verification status via backend
  Future<void> _checkVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isVerifying = true);

    try {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('📧 CHECKING EMAIL VERIFICATION STATUS');
      if (kDebugMode) debugPrint('User ID: ${user.uid}');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Call backend to check verification status
      final result = await _authService.checkEmailVerificationBackend(user.uid);
      // result will be 
      // {
      //     'success': true,
      //     'message': data['message'],
      //     'userData': data['data'],
      //   };

      if (!result['success']) {
        
        throw Exception(result['message'] ?? 'Failed to check verification');
      }

      final isVerified = result['verified'] ?? false;
      if (kDebugMode) debugPrint('📊 Email verified: $isVerified');

      if (!isVerified) {
        if (kDebugMode) debugPrint('⚠️ Email not yet verified');
        Get.snackbar(
          'Not Verified',
          'Please check your inbox and click the verification link',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
          icon: Icon(Icons.mail_outline, color: Colors.white),
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          duration: Duration(seconds: 4),
        );
        setState(() => _isVerifying = false);
        return;
      }

      // ✅ Email is verified - complete registration
      await _completeRegistration(user.uid);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking verification: $e');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      Get.snackbar(
        'Error',
        'Failed to check verification status: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
        icon: Icon(Icons.error_outline, color: AppColors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
      setState(() => _isVerifying = false);
    }
  }

  /// Complete registration via backend
  Future<void> _completeRegistration(String uid) async {
    try {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('📝 COMPLETING REGISTRATION VIA BACKEND');
      if (kDebugMode) debugPrint('User ID: $uid');
      if (kDebugMode) debugPrint('User Type: ${widget.userType}');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Call backend to complete registration
      final result = await _authService.completeRegistration(
        uid: uid,
        fullName: widget.fullName,
        phone: widget.phone,
        userType: widget.userType,
      );

      if (!result['success']) {
        throw Exception(result['message'] ?? 'Failed to complete registration');
      }

      if (kDebugMode) debugPrint('✅ Backend registration completed successfully');

      // ✅ CRITICAL: Force user reload and token refresh to get updated custom claims
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('🔄 Forcing Firebase user reload and token refresh...');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Force reload to get latest user state
        await user.reload();

        // Get fresh user reference
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser != null) {
          // Force token refresh to get updated custom claims
          final token = await freshUser.getIdToken(
            true,
          ); // true = force refresh
          if (token != null) {
            if (kDebugMode) debugPrint('✅ Fresh token obtained: ${token.substring(0, 20)}...');

            // Verify token has correct claims
            final idTokenResult = await freshUser.getIdTokenResult(true);
            if (kDebugMode) debugPrint('📋 Token claims: ${idTokenResult.claims}');
            if (kDebugMode) debugPrint(
              '   Email Verified: ${idTokenResult.claims?['email_verified']}',
            );
            if (kDebugMode) debugPrint('   User Type: ${idTokenResult.claims?['userType']}');
            if (kDebugMode) debugPrint('   Role: ${idTokenResult.claims?['role']}');

            // ✅ Wait for token to propagate (important!)
            await Future.delayed(Duration(milliseconds: 2000));
            if (kDebugMode) debugPrint('✅ Token refresh complete and propagated');
          } else {
            if (kDebugMode) debugPrint('⚠️ Warning: Token is null after refresh');
          }
        }
      }

      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('✅ REGISTRATION FULLY COMPLETE');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Show success message
      Get.snackbar(
        'Success',
        'Your account has been verified!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 2),
      );

      // ✅ Wait for user to see message
      await Future.delayed(Duration(milliseconds: 1000));

      // ✅ Navigate to welcome screen
      if (mounted) {
        AppRoutes.toWelcomeAfterSignup(
          userType: widget.userType,
          userName: widget.userName,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error completing registration: $e');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      Get.snackbar(
        'Error',
        'Failed to complete registration: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
        icon: Icon(Icons.error_outline, color: AppColors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
      setState(() => _isVerifying = false);
    }
  }

  /// Manual verification check
  Future<void> _handleVerification() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Get.snackbar(
        'Session Expired',
        'Please sign in again',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
        icon: Icon(Icons.error_outline, color: AppColors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    await _checkVerificationStatus();
  }

  /// Resend verification email via backend
  // Future<void> _handleResendEmail() async {
  //   setState(() => _isResending = true);

  //   try {
  //     if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     if (kDebugMode) debugPrint('📧 RESENDING VERIFICATION EMAIL');
  //     if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  //     // ✅ Call backend to resend email
  //     final result = await _authService.resendVerificationEmail();

  //     if (!result['success']) {
  //       throw Exception(result['message'] ?? 'Failed to resend email');
  //     }

  //     if (kDebugMode) debugPrint('✅ Verification email resent successfully');
  //     if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  //     Get.snackbar(
  //       'Email Sent',
  //       'Verification email has been sent. Please check your inbox.',
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: AppColors.success,
  //       colorText: Colors.white,
  //       icon: Icon(Icons.check_circle, color: Colors.white),
  //       margin: EdgeInsets.all(16),
  //       borderRadius: 12,
  //       duration: Duration(seconds: 3),
  //     );
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ Error resending email: $e');
  //     if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  //     Get.snackbar(
  //       'Error',
  //       e.toString(),
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: AppColors.error,
  //       colorText: AppColors.white,
  //       icon: Icon(Icons.error_outline, color: AppColors.white),
  //       margin: EdgeInsets.all(16),
  //       borderRadius: 12,
  //       duration: Duration(seconds: 4),
  //     );
  //   } finally {
  //     setState(() => _isResending = false);
  //   }
  // }

  /// Warning banner shown at the top of the verification screen when the
  /// backend failed to dispatch the welcome email at signup time.
  ///
  /// Why this exists: without it, users sit on this screen indefinitely
  /// waiting for an email that never arrives — the worst possible silent
  /// failure mode. Now they get an explicit "tap Resend" prompt.
  ///
  /// TODO(hatim): pick the final UX for this banner. Three reasonable
  /// directions, each with trade-offs:
  ///
  ///   (1) Current: inline amber banner above the icon. Calm, doesn't
  ///       block flow. Risk: easy to miss.
  ///   (2) Show a one-shot dialog when emailWasSent=false on first build.
  ///       Forces acknowledgment. Risk: feels accusatory.
  ///   (3) Replace the entire "check your inbox" copy with "we couldn't
  ///       send your email — tap Resend to try again". Strongest signal
  ///       but loses the welcoming tone for users where this is rare.
  ///
  /// Localization: copy below is hardcoded English. Add i18n keys to
  /// app_en.arb / app_ar.arb / app_fr.arb when you settle on final wording.
  Widget _buildEmailDispatchFailedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5), // soft amber
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB547), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB35900),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "We couldn't send your verification email",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A4400),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your account was created. Tap "Resend" below to try '
                  'again. If this keeps happening, contact support.',
                  style: TextStyle(
                    color: const Color(0xFF7A4400),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
