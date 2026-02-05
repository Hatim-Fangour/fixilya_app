// lib/core/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ✅ ADD THIS: Auth state stream for GetX binding
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ✅ ADD THIS: Current user stream (alternative)
  Stream<User?> get userChanges => _auth.userChanges();

  // ✅ UPDATED: Don't create Firestore docs on signup
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📝 STARTING SIGNUP');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Email: $email');
      print('Full Name: $fullName');
      print('Phone: $phone');
      print('User Type: $userType');

      // ✅ FIX 1: Check network connectivity first
      try {
        final result = await InternetAddress.lookup('google.com').timeout(
          Duration(seconds: 5),
          onTimeout: () => throw Exception('Network timeout'),
        );

        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          return {
            'success': false,
            'message': 'No internet connection. Please check your network.',
          };
        }
        print('✅ Network connection verified');
      } catch (e) {
        print('❌ Network check failed: $e');
        return {
          'success': false,
          'message': 'No internet connection. Please try again.',
        };
      }

      // ✅ FIX 2: Validate email format before calling Firebase
      if (!email.contains('@') || !email.contains('.')) {
        return {'success': false, 'message': 'Invalid email format'};
      }

      // ✅ FIX 3: Validate password length
      if (password.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters',
        };
      }

      print('🔐 Creating Firebase Auth user...');

      // ✅ FIX 4: Add timeout to createUser
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw FirebaseAuthException(
                code: 'timeout',
                message: 'Request timed out. Please try again.',
              );
            },
          );

      final User? user = userCredential.user;

      if (user == null) {
        print('❌ User creation returned null');
        return {
          'success': false,
          'message': 'Failed to create account. Please try again.',
        };
      }

      print('✅ Firebase Auth user created: ${user.uid}');

      // ✅ FIX 5: Send verification email with better error handling
      try {
        print('📧 Sending verification email...');
        await user.sendEmailVerification().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ Email verification timeout - continuing anyway');
            return;
          },
        );
        print('✅ Verification email sent');
      } catch (e) {
        print('⚠️ Failed to send verification email: $e');
        // Don't fail signup if email sending fails
      }

      // ✅ FIX 6: Save to Firestore with timeout
      print('💾 Saving user data to Firestore...');

      try {
        // Save to users collection
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
              // 'fullName': fullName.trim(),
              'email': email.trim().toLowerCase(),
              // 'phone': phone.trim(),
              'userType': userType.toLowerCase(),
              // 'profileCompleted': false,
              'createdAt': FieldValue.serverTimestamp(),
              // 'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Firestore save timeout');
              },
            );

        print('✅ Users collection updated');

        // Create empty document in handymen/clients collection
        final collection = userType.toLowerCase() == 'handyman'
            ? 'handymen'
            : 'clients';

        await _firestore
            .collection(collection)
            .doc(user.uid)
            .set({
              'approved': false, // For handymen
              'suspended': false,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Firestore save timeout');
              },
            );

        print('✅ $collection collection initialized');
      } catch (e) {
        print('❌ Firestore save failed: $e');

        // If Firestore fails, delete the auth user to maintain consistency
        try {
          await user.delete();
          print('🗑️ Auth user deleted due to Firestore failure');
        } catch (deleteError) {
          print('⚠️ Could not delete auth user: $deleteError');
        }

        return {
          'success': false,
          'message': 'Failed to save user data. Please try again.',
        };
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ SIGNUP SUCCESSFUL');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': true,
        'message': 'Account created successfully',
        'userId': user.uid,
      };
    } on FirebaseAuthException catch (e) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ FIREBASE AUTH ERROR');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'This email is already registered. Please sign in instead.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'operation-not-allowed':
          errorMessage =
              'Email/password accounts are not enabled. Please contact support.';
          break;
        case 'weak-password':
          errorMessage =
              'Password is too weak. Please use at least 6 characters.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your internet connection.';
          break;
        case 'timeout':
          errorMessage = 'Request timed out. Please try again.';
          break;
        case 'UNKNOWN':
        case 'internal-error':
          errorMessage =
              'Internal error (Code: 26). Please try again in a moment.\n\nTroubleshooting:\n• Check your internet connection\n• Make sure you\'re using a valid email\n• Try again in a few minutes';
          break;
        default:
          errorMessage = 'Signup failed: ${e.message ?? "Unknown error"}';
      }

      return {'success': false, 'message': errorMessage, 'errorCode': e.code};
    } catch (e, stackTrace) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ UNEXPECTED ERROR');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Get user type from custom claims
  Future<String?> getUserType() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      print('🔍 Getting user type for: ${user.uid}');

      // ✅ Check users collection FIRST
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userType = userDoc.data()?['userType'] as String?;
        if (userType != null && userType.isNotEmpty) {
          print('✅ User type: $userType');
          return userType.toLowerCase();
        }
      }

      // Check handymen collection
      final handymanDoc = await _firestore
          .collection('handymen')
          .doc(user.uid)
          .get();

      if (handymanDoc.exists) {
        print('✅ User is handyman');
        return 'handyman';
      }

      // Check clients collection
      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();

      if (clientDoc.exists) {
        print('✅ User is client');
        return 'client';
      }

      // ✅ Default to CLIENT (not handyman!)
      print('⚠️ User type not found, defaulting to client');
      return 'client';
    } catch (e) {
      print('❌ Error: $e');
      return 'client'; // ✅ Safer default
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      default:
        return 'Authentication error. Please try again.';
    }
  }

  // ✅ NEW: Create Firestore documents after email verification
  Future<Map<String, dynamic>> createUserDocuments({
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'No user found'};
      }

      if (!user.emailVerified) {
        return {'success': false, 'message': 'Email not verified'};
      }

      // Create users document
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        // 'email': user.email,
        // 'fullName': fullName,
        // 'phone': phone,
        'userType': userType,
        'emailVerified': true,
        'isActive': false,
        'suspended': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create type-specific document
      final typeCollection = userType == 'handyman' ? 'handymen' : 'clients';

      await _firestore.collection(typeCollection).doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'fullName': fullName,
        'phone': phone,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'User documents created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating documents: ${e.toString()}',
      };
    }
  }

  // Sign in with email
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user != null) {
        // ✅ Reload user to get latest verification status
        await user.reload();
        final refreshedUser = _auth.currentUser;

        // ✅ Check if email is verified
        if (refreshedUser == null || !refreshedUser.emailVerified) {
          await _auth.signOut();
          return {
            'success': false,
            'message': 'Please verify your email before signing in.',
            'needsVerification': true,
          };
        }

        // Get user type from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(refreshedUser.uid)
            .get();

        if (!userDoc.exists) {
          await _auth.signOut();
          return {
            'success': false,
            'message': 'User data not found. Please contact support.',
          };
        }

        return {
          'success': true,
          'message': 'Login successful',
          'userType': userDoc.data()?['userType'] ?? 'client',
          'userData': userDoc.data(),
        };
      }

      return {'success': false, 'message': 'Login failed'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle(String userType) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'message': 'Sign in cancelled'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Check if user document exists
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        String finalUserType; // ✅ Declare variable to store user type
        Map<String, dynamic>? userData;

        if (!userDoc.exists) {
          // ✅ New user - create documents
          finalUserType = userType; // Use the selected userType

          userData = {
            'uid': user.uid,
            'email': user.email,
            'fullName': user.displayName ?? '',
            'phone': '',
            'userType': finalUserType,
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': true, // Google emails are pre-verified
            'isActive': true,
          };

          await _firestore.collection('users').doc(user.uid).set(userData);

          final typeCollection = finalUserType == 'handyman'
              ? 'handymen'
              : 'clients';
          await _firestore.collection(typeCollection).doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'fullName': user.displayName ?? '',
            'phone': '',
            'createdAt': FieldValue.serverTimestamp(),
            'profileCompleted': false,
          });
        } else {
          // ✅ Existing user - get userType from Firestore
          userData = userDoc.data();
          finalUserType = userData?['userType'] ?? 'client';
        }

        return {
          'success': true,
          'message': 'Google sign in successful',
          'userType': finalUserType, // ✅ Return the correct userType
          'isNewUser': !userDoc.exists, // ✅ Optional: indicate if new user
          'userData': userData,
        };
      }

      return {'success': false, 'message': 'Google sign in failed'};
    } catch (e) {
      print('❌ Google sign in error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('❌ Error signing out: $e');
      // Still throw to let caller handle
      rethrow;
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent to $email',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ IMPROVED: Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      if (user.emailVerified) {
        return {'success': false, 'message': 'Email already verified'};
      }

      await user.sendEmailVerification();
      return {
        'success': true,
        'message': 'Verification email sent to ${user.email}',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ NEW: Check if email is verified (with reload)
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshedUser = _auth.currentUser;
    return refreshedUser?.emailVerified ?? false;
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data();
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // ✅ NEW: Get user data stream (real-time updates)
  Stream<Map<String, dynamic>?> getUserDataStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      // ✅ Add updatedAt timestamp
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(uid).update(data);

      // ✅ Also update type-specific collection if userType exists
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userType = userDoc.data()?['userType'];

      if (userType != null) {
        final typeCollection = userType == 'handyman' ? 'handymen' : 'clients';
        // Only update fields that exist in both collections
        final typeSpecificData = Map<String, dynamic>.from(data);
        typeSpecificData.removeWhere(
          (key, value) =>
              key == 'userType' || key == 'emailVerified' || key == 'isActive',
        );

        await _firestore
            .collection(typeCollection)
            .doc(uid)
            .update(typeSpecificData);
      }

      return {'success': true, 'message': 'Profile updated successfully'};
    } catch (e) {
      print('❌ Error updating profile: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ NEW: Delete user account
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      final uid = user.uid;

      // Get user type before deleting
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userType = userDoc.data()?['userType'];

      // Delete Firestore documents
      await _firestore.collection('users').doc(uid).delete();

      if (userType != null) {
        final typeCollection = userType == 'handyman' ? 'handymen' : 'clients';
        await _firestore.collection(typeCollection).doc(uid).delete();
      }

      // Delete Firebase Auth user
      await user.delete();

      return {'success': true, 'message': 'Account deleted successfully'};
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return {
          'success': false,
          'message': 'Please login again to delete your account',
          'requiresReauth': true,
        };
      }
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      print('❌ Error deleting account: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Change user password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final email = user.email;
      if (email == null) {
        throw Exception('User email not found');
      }

      // Re-authenticate with current password (required by Firebase)
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(newPassword);

      print('✅ Password changed successfully');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw Exception('Current password is incorrect');
        case 'weak-password':
          throw Exception('New password is too weak (minimum 6 characters)');
        case 'requires-recent-login':
          throw Exception(
            'Please logout and login again before changing password',
          );
        default:
          throw Exception('Failed to change password: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }
}
