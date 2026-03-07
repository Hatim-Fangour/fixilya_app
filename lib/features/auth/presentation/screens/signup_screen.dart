import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/core/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class SignUpScreen extends StatefulWidget {
  final String userType;

  const SignUpScreen({super.key, required this.userType});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
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
  final _nameController = TextEditingController(text: 'handy Hatim');
  final _emailController = TextEditingController(
    text: 'ing.hatim.fangour@gmail.com',
  );
  final _phoneController = TextEditingController(text: '+212666666666');
  final _passwordController = TextEditingController(text: '123ewq');
  final _confirmPasswordController = TextEditingController(
    text: '123ewq',
  ); // ✅ NEW

  bool _agreePersonalData = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; // ✅ NEW

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // ✅ NEW
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreePersonalData) {
      _showSnackBar('Please accept the terms and conditions', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Hide the keyboard
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      // ✅ STEP 1: Register user (creates auth + minimal Firestore docs)
      // The backend will handle creating the Firebase Auth user and Firestore docs
      // ✅ STEP 2: Send email verification (handled by backend)
      // ✅ STEP 3: USER_COLLECTION_NAME will be set in the backend based on userType, so we don't need to specify it here
      // ✅ STEP 4: The backend will return success if registration and email sending were successful, or an error message if something went wrong

      final result = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        userType: widget.userType,
      );

      if (mounted) setState(() => _isLoading = false);

      if (result['success']) {
        if (mounted) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 80));

          AppRoutes.toEmailVerification(
            userType: widget.userType,
            userName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            fullName: _nameController.text.trim(),
          );
        }
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showErrorDialog('An error occurred. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red, size: 24),
            ),
            SizedBox(width: 12),
            Text('Error', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
            ),
            child: Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : AppColors.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.subtleHeaderGradientThemed(context),
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
                      widget.userType == 'handyman'
                          ? FontAwesomeIcons.toolbox
                          : FontAwesomeIcons.userTie,
                      color: AppColors.primaryColor,
                      size: 32,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 12),

            Text(
              widget.userType == 'client'
                  ? 'Join as Client'
                  : 'Join as Handyman',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),

            SizedBox(height: 4),

            Text(
              widget.userType == 'client'
                  ? 'Find skilled professionals'
                  : 'Connect with clients',
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
                      'Create Account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),

                    SizedBox(height: 16),

                    _buildAnimatedTextField(
                      label: 'Full Name',
                      controller: _nameController,
                      icon: Icons.person_outline,
                      delay: 100,
                      validator: Validators.validateFullName,
                    ),

                    SizedBox(height: 12),

                    _buildAnimatedTextField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      delay: 200,
                      validator: Validators.validateEmail,
                    ),

                    SizedBox(height: 12),

                    _buildAnimatedTextField(
                      label: 'Phone Number',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      delay: 300,
                      validator: Validators.validateMoroccanPhone,
                    ),

                    SizedBox(height: 12),

                    _buildAnimatedTextField(
                      label: 'Password',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      delay: 400,
                      validator: Validators.validatePassword,
                    ),

                    SizedBox(height: 12),

                    // ✅ NEW: Confirm Password Field
                    _buildAnimatedTextField(
                      label: 'Confirm Password',
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      isConfirmPassword: true, // ✅ NEW parameter
                      delay: 500,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20),

                    // Animated Button
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
                                colors: [
                                  AppColors.primaryColor,
                                  AppColors.secondaryColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignUp,
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
                                          'Create Account',
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

                    SizedBox(height: 14),

                    // Sign In Link
                    Center(
                      child: TextButton(
                        onPressed: () {
                          AppRoutes.toLogin();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: AppColors.primaryColor,
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
    bool isConfirmPassword = false, // ✅ NEW parameter
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
              obscureText:
                  obscureText &&
                  (isConfirmPassword
                      ? _obscureConfirmPassword
                      : _obscurePassword), // ✅ UPDATED
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
                          (isConfirmPassword
                                  ? _obscureConfirmPassword
                                  : _obscurePassword)
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondaryColor(context),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isConfirmPassword) {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword; // ✅ NEW
                            } else {
                              _obscurePassword = !_obscurePassword;
                            }
                          });
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
