import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/core/utils/validators.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// Which legal document the user tapped on the consent row.
/// Routed through [_SignUpScreenState._openLegalDoc].
enum _LegalDoc { terms, privacy }

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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreePersonalData = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; // ✅ NEW

  // Long-lived gesture recognizers for the Terms / Privacy tap targets.
  // Created once in initState, disposed in dispose — avoids the per-frame
  // recognizer leak that TweenAnimationBuilder rebuilds would otherwise cause.
  late final TapGestureRecognizer _termsTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;

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

    // Bind tap recognizers to the legal-doc opener.
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegalDoc(_LegalDoc.terms);
    _privacyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegalDoc(_LegalDoc.privacy);

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
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
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

          // `emailSent` comes from AuthService — it's the backend's honest
          // signal about whether SendGrid actually accepted the message.
          // Default to true if absent so we don't false-alarm on missing fields.
          final bool emailWasSent = (result['emailSent'] as bool?) ?? true;

          AppRoutes.toEmailVerification(
            userType: widget.userType,
            userName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            fullName: _nameController.text.trim(),
            emailWasSent: emailWasSent,
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

                    SizedBox(height: 14),

                    // Terms & Privacy consent — required by Moroccan Law 09-08
                    // and GDPR. Defaults to false; validated in _handleSignUp.
                    _buildTermsCheckbox(),

                    SizedBox(height: 16),

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

  /// Consent row: Material Checkbox + RichText with tappable
  /// "Terms of Service" and "Privacy Policy" spans.
  ///
  /// The whole row (label area) toggles the checkbox on tap, so users
  /// don't need to hit the small Checkbox target precisely. Tapping the
  /// highlighted link spans short-circuits the toggle and opens the
  /// corresponding legal document via [_openLegalDoc].
  Widget _buildTermsCheckbox() {
    final linkStyle = TextStyle(
      color: AppColors.primaryColor,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primaryColor,
    );

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreePersonalData,
                  onChanged: (val) => setState(
                    () => _agreePersonalData = val ?? false,
                  ),
                  activeColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(
                    () => _agreePersonalData = !_agreePersonalData,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryColor(context),
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: linkStyle,
                            recognizer: _termsTapRecognizer,
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: linkStyle,
                            recognizer: _privacyTapRecognizer,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TODO(hatim): Implement legal-doc opener.
  //
  // Codebase context (already verified):
  //   • AppRoutes.terms ('/terms') and AppRoutes.privacy ('/privacy')
  //     are DECLARED but NOT registered in the GetX page list.
  //   • No /terms or /privacy screen files exist anywhere in lib/.
  //   • Settings page tile taps are no-ops (`() {}`).
  //   • `url_launcher: ^6.2.5` IS available in pubspec.yaml.
  //
  // Pick ONE strategy and replace the placeholder below (5–10 lines):
  //
  //   (A) url_launcher → real hosted URLs.  Simplest, ship-today.
  //       Example:
  //         final url = doc == _LegalDoc.terms
  //             ? Uri.parse('https://fixilya.ma/legal/terms')
  //             : Uri.parse('https://fixilya.ma/legal/privacy');
  //         await launchUrl(url, mode: LaunchMode.externalApplication);
  //
  //   (B) Placeholder SnackBar — buys time until real docs are written.
  //       Less professional, but won't break audits because the consent
  //       checkbox itself is still recorded against the user account.
  //
  //   (C) Build stub screens + register the existing AppRoutes constants
  //       in main.dart's GetX page list. Highest effort, cleanest result.
  //
  // Whatever you pick: keep it idempotent, don't throw, and surface a
  // friendly error if launch fails (closed browser, no network, etc).
  // ─────────────────────────────────────────────────────────────
  Future<void> _openLegalDoc(_LegalDoc doc) async {
    // TODO(hatim): replace this stub. See guidance above.
    _showSnackBar(
      doc == _LegalDoc.terms
          ? 'Terms of Service — screen coming soon'
          : 'Privacy Policy — screen coming soon',
      isError: false,
    );
  }
}
