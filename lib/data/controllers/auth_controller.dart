// Add this method to your existing AuthController class
// Location: lib/data/controllers/auth_controller.dart

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  // Observable to track auth state
  final Rx<User?> firebaseUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to auth state changes
    firebaseUser.bindStream(_authService.authStateChanges);
  }

  // ✅ ADD THIS METHOD - Check if user is authenticated and verified
  Future<bool> checkAuthStatus() async {
    try {
      final currentUser = _authService.getCurrentUser();

      if (currentUser == null) {
        return false;
      }

      // Refresh user to get latest email verification status
      await currentUser.reload();
      final refreshedUser = _authService.getCurrentUser();

      if (refreshedUser == null || !refreshedUser.emailVerified) {
        // User not verified, sign out
        await _authService.signOut();
        return false;
      }

      // Check if user data exists in Firestore
      final userData = await _authService.getUserData();

      if (userData == null || userData.isEmpty) {
        // No user data found, sign out
        await _authService.signOut();
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking auth status: $e');
      return false;
    }
  }

  // ✅ ADD THIS METHOD - Sign out user
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await _authService.signOut();
      firebaseUser.value = null;
      // Navigate to welcome screen
      Get.offAllNamed('/welcome');
    } catch (e) {
      print('Error signing out: $e');
      Get.snackbar(
        'Error',
        'Failed to sign out. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ ADD THIS METHOD - Login with email
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;

      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        // Get user type and navigate to appropriate home
        final userData = await _authService.getUserData();
        final userType = userData?['userType'] ?? 'client';

        if (userType == 'handyman') {
          Get.offAllNamed('/handyman-home');
        } else {
          Get.offAllNamed('/client-home');
        }

        return true;
      } else {
        Get.snackbar(
          'Login Failed',
          result['message'] ?? 'Please try again',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      Get.snackbar(
        'Error',
        'An error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ ADD THIS METHOD - Login with Google
  Future<bool> loginWithGoogle(String userType) async {
    try {
      isLoading.value = true;

      final result = await _authService.signInWithGoogle(userType);

      if (result['success'] == true) {
        final resultUserType = result['userType'] ?? 'client';

        if (resultUserType == 'handyman') {
          Get.offAllNamed('/handyman-home');
        } else {
          Get.offAllNamed('/client-home');
        }

        return true;
      } else {
        if (result['message'] != 'Sign in cancelled') {
          Get.snackbar(
            'Login Failed',
            result['message'] ?? 'Please try again',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return false;
      }
    } catch (e) {
      print('Google login error: $e');
      Get.snackbar(
        'Error',
        'An error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
