// lib/core/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ✅ ADD THIS: Auth state stream for GetX binding
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  // Auth state stream for GetX binding
  // Stream<User?> get authStateChanges => _auth.authStateChanges();
  // Stream<User?> get userChanges => _auth.userChanges();

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1)}";
  }

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

      // ✅ Check network connectivity first
      try {
        final result = await InternetAddress.lookup('google.com').timeout(
          const Duration(seconds: 5),
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

      final cleanEmail = email.trim().toLowerCase();

      // ✅ Validate email format before calling Firebase
      if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
        return {'success': false, 'message': 'Invalid email format'};
      }

      // ✅ Validate password length
      if (password.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters',
        };
      }

      print('🔐 Creating Firebase Auth user...');

      // Create the use in Authentication section

      // ✅ Add timeout to createUser
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: cleanEmail, password: password)
          .timeout(
            const Duration(seconds: 15),
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

      // ✅ Send verification email (don’t fail signup if it fails)
      try {
        print('📧 Sending verification email...');
        await user.sendEmailVerification().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ Email verification timeout - continuing anyway');
            return;
          },
        );
        print('✅ Verification email sent');
      } catch (e) {
        print('⚠️ Failed to send verification email: $e');
      }

      // ✅ Save to Firestore with timeout
      print('💾 Saving user data to Firestore...');
      final collection = userType.toLowerCase() == 'handyman'
          ? 'handymen'
          : 'clients';
      try {
        // Create the use in Users Collection
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
              'email': cleanEmail,
              'userType': userType.toLowerCase(),
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('Firestore save timeout'),
            );

        print('✅ Users collection updated');

        // final collection = userType.toLowerCase() == 'handyman'
        //     ? 'handymen'
        //     : 'clients';

        // Create the use in handymen/client Collection
        await _firestore
            .collection(collection)
            .doc(user.uid)
            .set({
              'approved': false,
              'suspended': false,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('Firestore save timeout'),
            );

        print('✅ $collection collection initialized');
      } catch (e) {
        print('❌ Firestore save failed: $e');

        // Rollback auth user if Firestore fails
        try {
          await user.delete();
          await _firestore
              .collection(collection)
              .doc(user.uid)
              .delete()
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Firestore delete timeout'),
              );
          await _firestore
              .collection('users')
              .doc(user.uid)
              .delete()
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Firestore delete timeout'),
              );
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

      final errorMessage = switch (e.code) {
        'email-already-in-use' =>
          'This email is already registered. Please sign in instead.',
        'invalid-email' => 'Invalid email address format.',
        'operation-not-allowed' =>
          'Email/password accounts are not enabled. Please contact support.',
        'weak-password' =>
          'Password is too weak. Please use at least 6 characters.',
        'network-request-failed' =>
          'Network error. Please check your internet connection.',
        'timeout' => 'Request timed out. Please try again.',
        'UNKNOWN' || 'internal-error' =>
          'Internal error (Code: 26). Please try again in a moment.',
        _ => 'Signup failed: ${e.message ?? "Unknown error"}',
      };

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

      // Create type-specific document
      final typeCollection = userType == 'handyman' ? 'handymen' : 'clients';

      // Continuer fill in the handymen/clients document after Email verification
      await _firestore.collection(typeCollection).doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'fullName': fullName,
        'phone': phone,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!user.emailVerified) {
        return {'success': false, 'message': 'Email not verified'};
      }

      // Continuer fill in the Users document after Email verification
      // Create users document
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'userType': userType,
        'emailVerified': true,
        'isActive': false,
        'suspended': false,
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
          // await _auth.signOut();
          // ✅ Get user data to pass to verification screen
          final userDoc = await _firestore
              .collection('users')
              .doc(refreshedUser!.uid)
              .get();

          final userData = userDoc.data();
          final userType = userData?['userType'] ?? 'client';
          return {
            'success': false,
            'needsVerification': true,
            'message': 'Please verify your email before signing in.',
            'userType': userType,
            'email': refreshedUser.email,
            'userId': refreshedUser.uid,
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
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔐 STARTING GOOGLE SIGN-IN');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('User Type: $userType');

      // ✅ Step 1: Check network connectivity
      try {
        final result = await InternetAddress.lookup('google.com').timeout(
          const Duration(seconds: 5),
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

      // ✅ Step 2: Validate user type
      if (userType.toLowerCase() != 'handyman' &&
          userType.toLowerCase() != 'client') {
        return {
          'success': false,
          'message': 'Invalid user type. Please select handyman or client.',
        };
      }

      final normalizedUserType = userType.toLowerCase();

      // ✅ Step 3: Sign out from any previous Google session
      try {
        await _googleSignIn.signOut();
        print('🔄 Cleared previous Google session');
      } catch (e) {
        print('⚠️ No previous session to clear: $e');
      }

      // ✅ Step 4: Trigger Google Sign-In flow
      print('📱 Launching Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ User cancelled Google Sign-In');
        return {
          'success': false,
          'message': 'Sign in cancelled',
          'cancelled': true,
        };
      }

      print('✅ Google account selected: ${googleUser.email}');

      // ✅ Step 5: Get authentication tokens
      print('🔑 Getting Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ Failed to get Google tokens');
        return {
          'success': false,
          'message': 'Failed to authenticate with Google. Please try again.',
        };
      }

      print('✅ Google tokens obtained');

      // ✅ Step 6: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // ✅ Step 7: Sign in to Firebase with timeout
      print('🔐 Signing in to Firebase...');
      final UserCredential userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw FirebaseAuthException(
                code: 'timeout',
                message: 'Firebase sign-in timed out. Please try again.',
              );
            },
          );

      final User? user = userCredential.user;

      if (user == null) {
        print('❌ Firebase sign-in returned null user');
        await _googleSignIn.signOut();
        return {
          'success': false,
          'message': 'Failed to sign in. Please try again.',
        };
      }

      print('✅ Firebase authentication successful');
      print('User ID: ${user.uid}');
      print('Email: ${user.email}');
      print('Email Verified: ${user.emailVerified}');

      // ✅ Step 8: Check if this is a new user or existing user
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Firestore read timeout'),
          );

      final bool isNewUser = !userDoc.exists;
      String finalUserType;
      Map<String, dynamic>? userData;

      if (isNewUser) {
        // ✅ NEW USER - Create Firestore documents
        print('👤 New user detected - Creating Firestore documents...');
        finalUserType = normalizedUserType;

        // ✅ Create users collection document
        userData = {
          'uid': user.uid,
          'email': user.email,
          'fullName': user.displayName ?? 'Google User',
          'phone': user.phoneNumber ?? '',
          'userType': finalUserType,
          'emailVerified': true, // Google emails are pre-verified
          'isActive': true,
          'suspended': false,
          'authProvider': 'google',
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        };

        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userData)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Firestore write timeout'),
              );

          print('✅ Users collection document created');

          // ✅ Create type-specific collection document
          final typeCollection = finalUserType == 'handyman'
              ? 'handymen'
              : 'clients';

          final typeSpecificData = {
            'uid': user.uid,
            'email': user.email,
            'fullName': user.displayName ?? 'Google User',
            'phone': user.phoneNumber ?? '',
            'profilePicture': user.photoURL ?? '',
            'profileCompleted': false,
            'approved': finalUserType == 'handyman'
                ? false
                : true, // Handymen need approval
            'suspended': false,
            'authProvider': 'google',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          };

          // Add handyman-specific fields
          if (finalUserType == 'handyman') {
            typeSpecificData.addAll({
              'isAvailable': false,
              'skills': [],
              'rating': 0.0,
              'totalReviews': 0,
              'completedJobs': 0,
            });
          }

          await _firestore
              .collection(typeCollection)
              .doc(user.uid)
              .set(typeSpecificData)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Firestore write timeout'),
              );

          print('✅ $typeCollection collection document created');
        } catch (e) {
          print('❌ Failed to create Firestore documents: $e');

          // ✅ Rollback: Delete Firebase Auth user if Firestore fails
          try {
            await user.delete();
            await _googleSignIn.signOut();
            print('🗑️ Rolled back Firebase Auth user');
          } catch (deleteError) {
            print('⚠️ Could not rollback Firebase Auth: $deleteError');
          }

          return {
            'success': false,
            'message': 'Failed to create user profile. Please try again.',
          };
        }
      } else {
        // ✅ EXISTING USER - Verify user type matches
        print('👤 Existing user detected - Verifying user type...');
        userData = userDoc.data();
        final existingUserType = userData?['userType'] as String?;

        if (existingUserType == null) {
          print(
            '⚠️ User type not found in Firestore - Setting to: $normalizedUserType',
          );
          finalUserType = normalizedUserType;

          // Update missing userType
          await _firestore.collection('users').doc(user.uid).update({
            'userType': finalUserType,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          finalUserType = existingUserType.toLowerCase();
          print('✅ Existing user type: $finalUserType');

          // ✅ Security: Verify user type consistency
          if (finalUserType != normalizedUserType) {
            print('⚠️ User type mismatch!');
            print('Expected: $normalizedUserType');
            print('Found: $finalUserType');

            await _auth.signOut();
            await _googleSignIn.signOut();

            return {
              'success': false,
              'message':
                  'This account is registered as a ${_capitalizeFirstLetter(finalUserType)}. '
                  'Please sign in as ${_capitalizeFirstLetter(finalUserType)} instead.',
              'wrongUserType': true,
              'expectedUserType': finalUserType,
            };
          }

          // ✅ Update last login timestamp
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }

        // ✅ Check if account is suspended
        final isSuspended = userData?['suspended'] ?? false;
        if (isSuspended) {
          await _auth.signOut();
          await _googleSignIn.signOut();

          return {
            'success': false,
            'message':
                'Your account has been suspended. Please contact support.',
            'suspended': true,
          };
        }

        // ✅ For handymen, check approval status
        if (finalUserType == 'handyman') {
          final typeDoc = await _firestore
              .collection('handymen')
              .doc(user.uid)
              .get();

          final approved = typeDoc.data()?['approved'] ?? false;

          if (!approved) {
            return {
              'success': true,
              'message': 'Account pending approval',
              'userType': finalUserType,
              'isNewUser': false,
              'pendingApproval': true,
              'userData': userData,
            };
          }
        }
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ GOOGLE SIGN-IN SUCCESSFUL');
      print('User Type: $finalUserType');
      print('Is New User: $isNewUser');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': true,
        'message': isNewUser ? 'Account created successfully' : 'Welcome back!',
        'userType': finalUserType,
        'isNewUser': isNewUser,
        'userData': userData,
      };
    } on FirebaseAuthException catch (e) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ FIREBASE AUTH ERROR');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Clean up on error
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final errorMessage = switch (e.code) {
        'account-exists-with-different-credential' =>
          'An account already exists with the same email but different sign-in method.',
        'invalid-credential' => 'Invalid Google credentials. Please try again.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled. Please contact support.',
        'user-disabled' =>
          'This account has been disabled. Please contact support.',
        'user-not-found' => 'No account found. Please sign up first.',
        'wrong-password' => 'Invalid credentials. Please try again.',
        'timeout' => 'Sign-in timed out. Please try again.',
        'network-request-failed' =>
          'Network error. Please check your connection.',
        _ => 'Google sign-in failed: ${e.message ?? "Unknown error"}',
      };

      return {'success': false, 'message': errorMessage, 'errorCode': e.code};
    } catch (e, stackTrace) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ UNEXPECTED ERROR');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Clean up on error
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚪 STARTING LOGOUT PROCESS');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Step 1: Reset theme to system mode
      try {
        final themeController = Get.find<ThemeController>();
        await themeController.resetThemeToSystem();
        print('✅ Theme reset to system mode');
      } catch (e) {
        print('⚠️ ThemeController not found or reset failed: $e');
      }

      // ✅ Step 2: Clear local storage (optional - keeps some settings)
      // If you want to clear ALL local data:
      // final localStorage = LocalStorageService();
      // await localStorage.clearAll();

      // ✅ Step 3: Sign out from Firebase Auth
      await _auth.signOut();
      print('✅ Signed out from Firebase Auth');

      // ✅ Step 4: Sign out from Google
      try {
        await _googleSignIn.signOut();
        print('✅ Signed out from Google');
      } catch (e) {
        print('⚠️ Google sign out failed (may not be signed in): $e');
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ LOGOUT COMPLETED SUCCESSFULLY');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      print('❌ Error during sign out: $e');
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

extension StringCapitalizationExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
