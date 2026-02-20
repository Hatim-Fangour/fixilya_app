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

  const EmailVerificationScreen({
    super.key,
    required this.userType,
    required this.userName,
    required this.email,
    required this.phone,
    required this.fullName,
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
        print('✅ Fetched user data: ${data?['fullName']}');
      }
    } catch (e) {
      print('⚠️ Could not fetch user data: $e');
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
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        // ✅ Use GetX snackbar
        Get.snackbar(
          'Email Sent',
          'Verification email sent successfully!',
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

  Future<void> _handleVerification() async {
    setState(() => _isVerifying = true);

    try {
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
        setState(() => _isVerifying = false);
        return;
      }

      // Reload user
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser == null || !updatedUser.emailVerified) {
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

      // Create Firestore documents
      final result = await _authService.createUserDocuments(
        fullName: widget.fullName,
        phone: widget.phone,
        userType: widget.userType,
      );

      if (!result['success']) {
        throw Exception(result['message']);
      }

      // ✅ Navigate with GetX
      AppRoutes.toWelcomeAfterSignup(
        userType: widget.userType,
        userName: widget.userName,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
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
}
