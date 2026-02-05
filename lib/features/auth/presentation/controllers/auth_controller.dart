/// Auth Controller
/// Complete authentication state management
///
/// Features:
/// - Sign in/sign up flow
/// - Email verification
/// - Password reset
/// - User type selection
/// - Loading states
/// - Error handling
/// - Form validation

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  // Services (inject via dependency injection)
  // final AuthService _authService = Get.find();
  // final FirestoreService _firestoreService = Get.find();
  // final AnalyticsService _analyticsService = Get.find();

  // ==================== Observable State ====================

  // Loading states
  final _isLoading = false.obs;
  final _isGoogleLoading = false.obs;
  final _isAppleLoading = false.obs;

  // User state
  final _currentUser = Rxn<dynamic>();
  final _selectedUserType = Rxn<String>();

  // Error state
  final _errorMessage = Rxn<String>();

  // Form state
  final _obscurePassword = true.obs;
  final _obscureConfirmPassword = true.obs;
  final _agreeToTerms = false.obs;

  // ==================== Getters ====================

  bool get isLoading => _isLoading.value;
  bool get isGoogleLoading => _isGoogleLoading.value;
  bool get isAppleLoading => _isAppleLoading.value;
  dynamic get currentUser => _currentUser.value;
  String? get selectedUserType => _selectedUserType.value;
  String? get errorMessage => _errorMessage.value;
  bool get obscurePassword => _obscurePassword.value;
  bool get obscureConfirmPassword => _obscureConfirmPassword.value;
  bool get agreeToTerms => _agreeToTerms.value;

  // ==================== Form Controllers ====================

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  // Form keys
  final loginFormKey = GlobalKey<FormState>();
  final signupFormKey = GlobalKey<FormState>();
  final forgotPasswordFormKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    _checkAuthState();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  // ==================== Authentication Methods ====================

  /// Sign in with email and password
  Future<void> signInWithEmail() async {
    if (!loginFormKey.currentState!.validate()) return;

    _clearError();
    _isLoading.value = true;

    try {
      // await _authService.signInWithEmailAndPassword(
      //   email: emailController.text.trim(),
      //   password: passwordController.text,
      // );

      // await _analyticsService.logLogin('email');

      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      Get.offAllNamed('/home');
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail() async {
    if (!signupFormKey.currentState!.validate()) return;

    if (!_agreeToTerms.value) {
      _setError('Please agree to the Terms of Service and Privacy Policy');
      return;
    }

    _clearError();
    _isLoading.value = true;

    try {
      // await _authService.signUpWithEmailAndPassword(
      //   email: emailController.text.trim(),
      //   password: passwordController.text,
      // );

      // await _createUserDocument();
      // await _analyticsService.logSignUp('email');

      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      Get.offAllNamed('/email-verification');
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    _clearError();
    _isGoogleLoading.value = true;

    try {
      // await _authService.signInWithGoogle();
      // await _analyticsService.logLogin('google');

      await Future.delayed(Duration(seconds: 2));

      // Check if user document exists, if not create it
      // final hasUserType = await _checkUserDocument();
      // if (hasUserType) {
      //   Get.offAllNamed('/home');
      // } else {
      //   Get.toNamed('/user-type-selection');
      // }

      Get.offAllNamed('/home');
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isGoogleLoading.value = false;
    }
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    _clearError();
    _isAppleLoading.value = true;

    try {
      // await _authService.signInWithApple();
      // await _analyticsService.logLogin('apple');

      await Future.delayed(Duration(seconds: 2));

      Get.offAllNamed('/home');
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isAppleLoading.value = false;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail() async {
    if (!forgotPasswordFormKey.currentState!.validate()) return;

    _clearError();
    _isLoading.value = true;

    try {
      // await _authService.sendPasswordResetEmail(
      //   emailController.text.trim(),
      // );

      await Future.delayed(Duration(seconds: 1));

      Get.snackbar(
        'Email Sent',
        'Password reset link has been sent to your email',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      Get.back();
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    _isLoading.value = true;

    try {
      // await _authService.sendEmailVerification();

      await Future.delayed(Duration(seconds: 1));

      Get.snackbar(
        'Verification Sent',
        'Please check your email for verification link',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  /// Check email verification status
  Future<void> checkEmailVerification() async {
    try {
      // await _authService.reloadUser();
      // final isVerified = _authService.isEmailVerified;

      // Simulate check
      await Future.delayed(Duration(seconds: 1));
      final isVerified = true;

      if (isVerified) {
        Get.snackbar(
          'Email Verified',
          'Your email has been successfully verified',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        Get.offAllNamed('/user-type-selection');
      } else {
        Get.snackbar(
          'Not Verified',
          'Please verify your email before continuing',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // await _authService.signOut();
      // await _analyticsService.logLogout();

      _clearFormFields();
      Get.offAllNamed('/login');
    } catch (e) {
      _setError(_getErrorMessage(e));
    }
  }

  // ==================== User Type Selection ====================

  /// Select user type (client or handyman)
  void selectUserType(String userType) {
    _selectedUserType.value = userType;
  }

  /// Complete user type selection
  Future<void> completeUserTypeSelection() async {
    if (_selectedUserType.value == null) {
      _setError('Please select a user type');
      return;
    }

    _isLoading.value = true;

    try {
      // await _firestoreService.update(
      //   collection: 'users',
      //   documentId: _authService.currentUserId!,
      //   data: {'userType': _selectedUserType.value},
      // );

      // await _analyticsService.setUserType(_selectedUserType.value!);

      await Future.delayed(Duration(seconds: 1));

      Get.offAllNamed('/home');
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  // ==================== Helper Methods ====================

  /// Check authentication state
  void _checkAuthState() {
    // Listen to auth state changes
    // _authService.authStateChanges.listen((user) {
    //   _currentUser.value = user;
    //   if (user != null) {
    //     Get.offAllNamed('/home');
    //   }
    // });
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument() async {
    // final userId = _authService.currentUserId;
    // if (userId == null) return;

    // await _firestoreService.set(
    //   collection: 'users',
    //   documentId: userId,
    //   data: {
    //     'email': emailController.text.trim(),
    //     'fullName': fullNameController.text.trim(),
    //     'phone': phoneController.text.trim(),
    //     'emailVerified': false,
    //     'phoneVerified': false,
    //   },
    // );
  }

  /// Check if user document exists
  Future<bool> _checkUserDocument() async {
    // final userId = _authService.currentUserId;
    // if (userId == null) return false;

    // final doc = await _firestoreService.get(
    //   collection: 'users',
    //   documentId: userId,
    // );

    // return doc != null && doc['userType'] != null;
    return false;
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    _obscurePassword.value = !_obscurePassword.value;
  }

  /// Toggle confirm password visibility
  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword.value = !_obscureConfirmPassword.value;
  }

  /// Toggle terms agreement
  void toggleTermsAgreement(bool? value) {
    _agreeToTerms.value = value ?? false;
  }

  /// Clear all form fields
  void _clearFormFields() {
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    fullNameController.clear();
    phoneController.clear();
    _agreeToTerms.value = false;
    _obscurePassword.value = true;
    _obscureConfirmPassword.value = true;
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage.value = message;
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }

  /// Clear error message
  void _clearError() {
    _errorMessage.value = null;
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('network')) {
      return 'Network error. Please check your connection.';
    } else if (errorString.contains('email')) {
      return 'Invalid email address.';
    } else if (errorString.contains('password')) {
      return 'Invalid password.';
    } else if (errorString.contains('user-not-found')) {
      return 'No account found with this email.';
    } else if (errorString.contains('wrong-password')) {
      return 'Incorrect password.';
    } else if (errorString.contains('email-already-in-use')) {
      return 'An account already exists with this email.';
    } else if (errorString.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    } else if (errorString.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }

    return 'An error occurred. Please try again.';
  }

  // ==================== Validation Methods ====================

  /// Validate email
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  /// Validate password
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  /// Validate confirm password
  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validate full name
  String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }

    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }

    return null;
  }

  /// Validate phone
  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Please enter a valid phone number';
    }

    return null;
  }
}
