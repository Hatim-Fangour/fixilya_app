import 'package:flutter/foundation.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/core/constants/app_strings.dart';
import 'package:fixilya_app/core/constants/app_icons.dart';
import 'package:fixilya_app/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/core/utils/validators.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Animation Controllers
  late AnimationController _headerController;
  late AnimationController _formController;
  late Animation<double> _headerAnimation;
  late Animation<double> _formAnimation;
  late Animation<Offset> _slideAnimation;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Colors
  static const primaryColor = Color(0xFF536EFE);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _formController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_formAnimation);

    // Start animations
    _headerController.forward();
    Future.delayed(Duration(milliseconds: 200), () {
      _formController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _formController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (result['success']) {
        // final userType = result['userType'];

        if (mounted) {
          // Show success message
          // Get.snackbar(
          //   'Success',
          //   'Welcome back!',
          //   snackPosition: SnackPosition.BOTTOM,
          //   backgroundColor: Colors.green,
          //   colorText: Colors.white,
          //   duration: Duration(seconds: 2),
          //   margin: EdgeInsets.all(16),
          //   borderRadius: 12,
          //   icon: Icon(Icons.check_circle, color: Colors.white),
          // );

          // Navigate to home using GetX
          // This will clear the navigation stack and go to WidgetTree
          AppRoutes.toHome();
        }
      } else if (result['needsVerification'] == true) {
        String fullName = '';
        String phone = '';

        try {
          // final userDoc = await FirebaseFirestore.instance
          //     .collection('users')
          //     .doc(result['userId'])
          //     .get();

          final doc = await FirebaseFirestore.instance
              .collection('handymen')
              .doc(result['userId'])
              .get();

          if (kDebugMode) debugPrint('User document data: ${doc.data()}');
          if (kDebugMode) debugPrint('doc[fullName]: ${doc['fullName']}');
          if (kDebugMode) debugPrint('doc[phone]: ${doc['phone']}');
          // final userData = userDoc.data();
          fullName = doc['fullName'] ?? '';
          phone = doc['phone'] ?? '';
        } catch (e) {
          if (kDebugMode) debugPrint('Could not fetch user data: $e');
        }

        // Navigate to email verification screen
        Get.off(
          () => EmailVerificationScreen(
            userType: result['userType'] ?? 'client',
            userName: fullName, // First name
            email: result['email'] ?? _emailController.text.trim(),
            phone: phone,
            fullName: fullName,
          ),
        );

        // Show message
        Get.snackbar(
          'Email Not Verified',
          'Please verify your email to continue',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: AppColors.white,
          icon: Icon(Icons.mail_outline, color: AppColors.white),
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          duration: Duration(seconds: 4),
        );
      } else {
        _showError(result['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError('An error occurred: ${e.toString()}');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // ✅ Ask user type first
      final userType = await _showUserTypeDialog();

      if (userType == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Call Google Sign-In
      final result = await _authService.signInWithGoogle(userType);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      // ✅ Handle cancelled sign-in
      if (result['cancelled'] == true) {
        return; // Don't show error for cancellation
      }

      // ✅ Handle success
      if (result['success']) {
        if (mounted) {
          // ✅ Handle pending approval for handymen
          if (result['pendingApproval'] == true) {
            Get.snackbar(
              'Pending Approval',
              'Your handyman account is pending admin approval. You\'ll be notified once approved.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: Duration(seconds: 4),
              margin: EdgeInsets.all(16),
              borderRadius: 12,
              icon: Icon(Icons.pending_outlined, color: Colors.white),
            );

            // Sign out and return to login
            await _authService.signOut();
            return;
          }

          // ✅ Show success message
          Get.snackbar(
            'Success',
            result['isNewUser'] == true
                ? 'Welcome to Fixilya!'
                : 'Welcome back!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
            borderRadius: 12,
            icon: Icon(Icons.check_circle, color: Colors.white),
          );

          // ✅ Navigate to home
          AppRoutes.toHome();
        }
      } else {
        // ✅ Handle specific error cases
        if (result['wrongUserType'] == true) {
          _showError(
            result['message'] ?? 'User type mismatch',
            duration: Duration(seconds: 5),
          );
        } else if (result['suspended'] == true) {
          _showError(
            result['message'] ?? 'Account suspended',
            duration: Duration(seconds: 5),
          );
        } else {
          _showError(result['message'] ?? 'Google sign in failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError('Google sign in failed: ${e.toString()}');
    }
  }

  Future<String?> _showUserTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
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
              child: Icon(Icons.person_outline, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'Select Account Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how you want to use Fixilya',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            SizedBox(height: 16),
            _buildUserTypeOption(
              type: 'client',
              icon: FontAwesomeIcons.userTie,
              title: 'Client',
              subtitle: 'Looking for handyman services',
            ),
            SizedBox(height: 12),
            _buildUserTypeOption(
              type: 'handyman',
              icon: FontAwesomeIcons.toolbox,
              title: 'Handyman',
              subtitle: 'Offering services',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeOption({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FaIcon(icon, color: primaryColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showError(String message, {Duration? duration}) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: duration ?? Duration(seconds: 4),
      margin: EdgeInsets.all(16),
      borderRadius: 12,
      icon: Icon(Icons.error_outline, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.appHeaderGradientThemed(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildForm()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerAnimation,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Animated Icon
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 600),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.toolbox,
                      color: primaryColor,
                      size: 32,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 12),

            Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),

            SizedBox(height: 4),

            Text(
              'Sign in to continue',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _formAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),

                    SizedBox(height: 16),

                    _buildAnimatedTextField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      delay: 100,
                      validator: Validators.validateEmail,
                    ),

                    SizedBox(height: 12),

                    _buildAnimatedTextField(
                      label: 'Password',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      delay: 200,
                      validator: Validators.validatePassword,
                    ),

                    SizedBox(height: 8),

                    // Forgot Password
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                AppRoutes.to(AppRoutes.forgotPassword);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Sign In Button
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 800),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Divider with "OR"
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  thickness: 0.7,
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  thickness: 0.7,
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 14),

                    // Google Sign In Button
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    SocialIcons.google,
                                    color: SocialColors.google,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    AppStrings.continueWithGoogle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Sign Up Link
                    Center(
                      child: TextButton(
                        onPressed: () {
                          AppRoutes.toUserTypeSelection();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: RichText(
                          text: TextSpan(
                            text: 'Don\'t have an account? ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign Up',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required int delay,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(50 * (1 - value), 0),
            child: TextFormField(
              controller: controller,
              obscureText: obscureText && _obscurePassword,
              keyboardType: keyboardType,
              validator: validator,
              style: TextStyle(fontSize: 15),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: AppColors.textSecondaryColor(context),
                  fontSize: 14,
                ),
                prefixIcon: Container(
                  margin: EdgeInsets.all(10),
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primaryColor, size: 18),
                ),
                suffixIcon: obscureText
                    ? IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondaryColor(context),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.borderColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.borderColor(context),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.primaryColor,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.red, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                isDense: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
