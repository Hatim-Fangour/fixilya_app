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
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthController extends GetxController {
  // Firebase instances
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ==================== Observable State ====================

  // Loading states
  final _isLoading = false.obs;
  final _isGoogleLoading = false.obs;
  final _isAppleLoading = false.obs;

  // User state
  final _currentUser = Rxn<User>();
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
  User? get currentUser => _currentUser.value;
  bool get isLoggedIn => _currentUser.value != null;
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
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      _currentUser.value = userCredential.user;

      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
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
      final userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      _currentUser.value = userCredential.user;

      // Update display name if provided
      if (fullNameController.text.trim().isNotEmpty) {
        await userCredential.user
            ?.updateDisplayName(fullNameController.text.trim());
      }

      Get.offAllNamed('/email-verification');
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
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
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        _isGoogleLoading.value = false;
        return;
      }

      // Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      _currentUser.value = userCredential.user;

      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
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
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final userCredential =
          await _firebaseAuth.signInWithProvider(appleProvider);

      _currentUser.value = userCredential.user;

      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
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
      await _firebaseAuth.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      Get.snackbar(
        'Email Sent',
        'Password reset link has been sent to your email',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      Get.back();
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
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
      await _firebaseAuth.currentUser?.sendEmailVerification();

      Get.snackbar(
        'Verification Sent',
        'Please check your email for verification link',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  /// Check email verification status
  Future<void> checkEmailVerification() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      _currentUser.value = _firebaseAuth.currentUser;

      final isVerified = _firebaseAuth.currentUser?.emailVerified ?? false;

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
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      _setError(_getErrorMessage(e));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();

      // Also sign out from Google if applicable
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Google sign-out may fail if not signed in via Google
      }

      _currentUser.value = null;
      _clearFormFields();
      Get.offAllNamed('/login');
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
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
      // User type will be persisted via the backend/Firestore
      // when the profile setup is complete
      Get.offAllNamed('/home');
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _isLoading.value = false;
    }
  }

  // ==================== Helper Methods ====================

  /// Check authentication state and listen for changes
  void _checkAuthState() {
    _firebaseAuth.authStateChanges().listen((User? user) {
      _currentUser.value = user;
    });
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

  /// Get user-friendly error message from FirebaseAuthException code
  String _getFirebaseErrorMessage(String code) {
    return switch (code) {
      'network-request-failed' =>
        'Network error. Please check your connection.',
      'invalid-email' => 'Invalid email address.',
      'wrong-password' => 'Incorrect password.',
      'user-not-found' => 'No account found with this email.',
      'email-already-in-use' => 'An account already exists with this email.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'user-disabled' =>
        'This account has been disabled. Please contact support.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled. Please contact support.',
      'invalid-credential' =>
        'Invalid credentials. Please check your email and password.',
      'account-exists-with-different-credential' =>
        'An account already exists with the same email but different sign-in method.',
      _ => 'An authentication error occurred. Please try again.',
    };
  }

  /// Get user-friendly error message from generic errors
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
