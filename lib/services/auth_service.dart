// lib/core/services/auth_service.dart
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint('[AuthService] $msg');
}

class AuthService {
  // ✅ ADD: Base URL for your backend
  // static const String _baseUrl = 'http://localhost:3001/api/auth';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final _api = ApiClient(); // ✅ USE ApiClient

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
  // ✅ UPDATED: Sign up with backend API using ApiClient
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    try {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('📝 STARTING SIGNUP WITH BACKEND');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('Email: $email');
      _log('Full Name: $fullName');
      _log('Phone: $phone');
      _log('User Type: $userType');

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
        _log('✅ Network connection verified');
      } catch (e) {
        _log('❌ Network check failed: $e');
        return {
          'success': false,
          'message': 'No internet connection. Please try again.',
        };
      }

      // ✅ Call backend registration API using ApiClient
      _log('🌐 Calling backend API...');
      final response = await _api.dio.post(
        '/auth/register',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'userType': userType,
        },
      );

      final data = response.data;
      _log('📥 Backend response: $data');

      if (response.statusCode == 201 && data['success'] == true) {
        _log('✅ Backend registration successful');

        // ✅ Sign in to Firebase (to get the user object)
        _log('🔐 Signing in to Firebase...');
        final userCredential = await _auth
            .signInWithEmailAndPassword(
              email: email.trim().toLowerCase(),
              password: password,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                // logger.warning('Firebase sign-in timed out after 15 seconds');
                throw FirebaseAuthException(
                  code: 'timeout',
                  message: 'Firebase sign-in timed out. Please try again.',
                );
              },
            );

        final user = userCredential.user;
        _log('✅ Firebase sign-in successful: ${user?.uid}');

        // ✅ CRITICAL: Force token refresh and wait for it to be ready
        if (user != null) {
          _log('🔄 Forcing token refresh...');
          try {
            await user.reload();
            final token = await user.getIdToken(true); // Force refresh
            if (token == null) {
              _log('⚠️ Warning: Token is null after refresh');
            }
          } catch (e) {
            _log('⚠️ Token refresh warning: $e');
          }
        }

        // ✅ Send verification email
        // try {
        //   _log('📧 Sending verification email...');
        //   await user?.sendEmailVerification().timeout(
        //     const Duration(seconds: 10),
        //     onTimeout: () {
        //       _log('⏱️ Email verification timeout - continuing anyway');
        //       return;
        //     },
        //   );
        //   _log('✅ Verification email sent');
        // } catch (e) {
        //   _log('⚠️ Failed to send verification email: $e');
        // }

        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _log('✅ SIGNUP SUCCESSFUL');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return {
          'success': true,
          'message': data['message'] ?? 'Account created successfully',
          'userId': data['data']['uid'],
          'verificationLink': data['data']['verificationLink'],
          'emailSent': data['data']['emailSent'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } on DioException catch (e) {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('❌ BACKEND API ERROR');
      _log('Status Code: ${e.response?.statusCode}');
      _log('Message: ${e.message}');
      _log('Response: ${e.response?.data}');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Registration failed',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'message': 'Connection timeout. Please try again.',
        };
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message': 'Server timeout. Please try again.',
        };
      } else {
        return {
          'success': false,
          'message': 'Network error. Please check your connection.',
        };
      }
    } on FirebaseAuthException catch (e) {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('❌ FIREBASE AUTH ERROR');
      _log('Code: ${e.code}');
      _log('Message: ${e.message}');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
        _ => 'Signup failed: ${e.message ?? "Unknown error"}',
      };

      return {'success': false, 'message': errorMessage, 'errorCode': e.code};
    } catch (e, stackTrace) {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('❌ UNEXPECTED ERROR');
      _log('Error: $e');
      _log('Stack trace: $stackTrace');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // ✅ NEW: Complete registration after email verification
  Future<Map<String, dynamic>> completeRegistration({
    required String uid,
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    try {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('📝 COMPLETING REGISTRATION');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await _api.dio.post(
        '/auth/complete-registration',
        data: {
          'uid': uid,
          'fullName': fullName,
          'phone': phone,
          'userType': userType,
        },
      );

      final data = response.data;

      if (response.statusCode == 200 && data['success'] == true) {
        _log('✅ Registration completed successfully');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return {
          'success': true,
          'message': data['message'],
          'userData': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to complete registration',
        };
      }
    } on DioException catch (e) {
      _log('❌ Backend Error: ${e.message}');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to complete registration',
        };
      } else {
        return {
          'success': false,
          'message': 'Network error. Please try again.',
        };
      }
    } catch (e) {
      _log('❌ Error: $e');
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  // ✅ NEW: Check email verification status (backend)
  Future<Map<String, dynamic>> checkEmailVerificationBackend(String uid) async {
    try {
      final response = await _api.dio.get('/auth/check-verification/$uid');
      //NOTE - The backend will return { success: true, data: { verified: true/false } } if the user is found, or { success: false, message: 'User not found' } if the UID is invalid.
      // success: true,
      // message: "Email verification status retrieved",
      // data: result,
      
      final data = response.data;
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('data : $data');

      // data is the result now = success: true, message: "Email verification status retrieved",data: result,

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'verified': data['data']['verified']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to check verification',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  // ✅ UPDATED: Resend verification email (backend)
  Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      if (user.emailVerified) {
        return {'success': false, 'message': 'Email already verified'};
      }

      // ✅ Call backend API
      final response = await _api.dio.post(
        '/auth/resend-verification',
        data: {'uid': user.uid},
      );

      final data = response.data;

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Verification email sent',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send verification email',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ Keep existing: Get user type from Firestore
  Future<String?> getUserType() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      _log('🔍 Getting user type for: ${user.uid}');

      // Check users collection FIRST
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userType = userDoc.data()?['userType'] as String?;
        if (userType != null && userType.isNotEmpty) {
          _log('✅ User type: $userType');
          return userType.toLowerCase();
        }
      }

      // Check handymen collection
      final handymanDoc = await _firestore
          .collection('handymen')
          .doc(user.uid)
          .get();

      if (handymanDoc.exists) {
        _log('✅ User is handyman');
        return 'handyman';
      }

      // Check clients collection
      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();

      if (clientDoc.exists) {
        _log('✅ User is client');
        return 'client';
      }

      // Default to CLIENT
      _log('⚠️ User type not found, defaulting to client');
      return 'client';
    } catch (e) {
      _log('❌ Error: $e');
      return 'client';
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

  // ✅ UPDATED: Sign in with email using backend
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('🔐 STARTING LOGIN WITH BACKEND');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Call backend login API
      final response = await _api.dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final data = response.data;

      if (response.statusCode == 200 && data['success'] == true) {
        _log('Backend login successful');

        // Sign in to Firebase with custom token
        final customToken = data['data']['accessToken'];
        await _auth.signInWithCustomToken(customToken);

        // Cache user type for instant routing on next app start
        final loginUserType = data['data']['userType'] ?? 'client';
        try {
          await DataPersistenceService().cacheString(
            DataPersistenceService.keyUserType,
            loginUserType.toString().toLowerCase(),
          );
        } catch (_) {}

        _log('Firebase sign-in successful');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return {
          'success': true,
          'message': data['message'],
          'userType': loginUserType,
          'userData': data['data'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } on DioException catch (e) {
      _log('❌ Backend Login Error: ${e.message}');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Login failed',
        };
      } else {
        return {
          'success': false,
          'message': 'Network error. Please check your connection.',
        };
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ Keep existing: Sign in with Google (no backend needed for now)
  Future<Map<String, dynamic>> signInWithGoogle(String userType) async {
    try {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('🔐 STARTING GOOGLE SIGN-IN');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('User Type: $userType');

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
        _log('✅ Network connection verified');
      } catch (e) {
        _log('❌ Network check failed: $e');
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
        _log('🔄 Cleared previous Google session');
      } catch (e) {
        _log('⚠️ No previous session to clear: $e');
      }

      // ✅ Step 4: Trigger Google Sign-In flow
      _log('📱 Launching Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _log('⚠️ User cancelled Google Sign-In');
        return {
          'success': false,
          'message': 'Sign in cancelled',
          'cancelled': true,
        };
      }

      _log('✅ Google account selected: ${googleUser.email}');

      // ✅ Step 5: Get authentication tokens
      _log('🔑 Getting Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        _log('❌ Failed to get Google tokens');
        return {
          'success': false,
          'message': 'Failed to authenticate with Google. Please try again.',
        };
      }

      _log('✅ Google tokens obtained');

      // ✅ Step 6: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // ✅ Step 7: Sign in to Firebase with timeout
      _log('🔐 Signing in to Firebase...');
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
        _log('❌ Firebase sign-in returned null user');
        await _googleSignIn.signOut();
        return {
          'success': false,
          'message': 'Failed to sign in. Please try again.',
        };
      }

      _log('✅ Firebase authentication successful');
      _log('User ID: ${user.uid}');
      _log('Email: ${user.email}');
      _log('Email Verified: ${user.emailVerified}');

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
        _log('👤 New user detected - Creating Firestore documents...');
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

          _log('✅ Users collection document created');

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

          _log('✅ $typeCollection collection document created');
        } catch (e) {
          _log('❌ Failed to create Firestore documents: $e');

          // ✅ Rollback: Delete Firebase Auth user if Firestore fails
          try {
            await user.delete();
            await _googleSignIn.signOut();
            _log('🗑️ Rolled back Firebase Auth user');
          } catch (deleteError) {
            _log('⚠️ Could not rollback Firebase Auth: $deleteError');
          }

          return {
            'success': false,
            'message': 'Failed to create user profile. Please try again.',
          };
        }
      } else {
        // ✅ EXISTING USER - Verify user type matches
        _log('👤 Existing user detected - Verifying user type...');
        userData = userDoc.data();
        final existingUserType = userData?['userType'] as String?;

        if (existingUserType == null) {
          _log(
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
          _log('✅ Existing user type: $finalUserType');

          // ✅ Security: Verify user type consistency
          if (finalUserType != normalizedUserType) {
            _log('⚠️ User type mismatch!');
            _log('Expected: $normalizedUserType');
            _log('Found: $finalUserType');

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

      // Cache user type for instant routing on next app start
      try {
        await DataPersistenceService().cacheString(
          DataPersistenceService.keyUserType,
          finalUserType,
        );
      } catch (_) {}

      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('GOOGLE SIGN-IN SUCCESSFUL');
      _log('User Type: $finalUserType');
      _log('Is New User: $isNewUser');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': true,
        'message': isNewUser ? 'Account created successfully' : 'Welcome back!',
        'userType': finalUserType,
        'isNewUser': isNewUser,
        'userData': userData,
      };
    } on FirebaseAuthException catch (e) {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('❌ FIREBASE AUTH ERROR');
      _log('Code: ${e.code}');
      _log('Message: ${e.message}');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('❌ UNEXPECTED ERROR');
      _log('Error: $e');
      _log('Stack trace: $stackTrace');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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

  // ✅ Keep existing: Sign out
  Future<void> signOut() async {
    try {
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('STARTING LOGOUT PROCESS');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Clear all persisted data caches on logout
      try {
        await DataPersistenceService().clearAll();
        _log('Data caches cleared');
      } catch (e) {
        _log('Cache clear failed (non-critical): $e');
      }

      // Reset theme to system mode
      try {
        final themeController = Get.find<ThemeController>();
        await themeController.resetThemeToSystem();
        _log('Theme reset to system mode');
      } catch (e) {
        _log('ThemeController not found or reset failed: $e');
      }

      // Sign out from Firebase Auth
      await _auth.signOut();
      _log('Signed out from Firebase Auth');

      // Sign out from Google
      try {
        await _googleSignIn.signOut();
        _log('Signed out from Google');
      } catch (e) {
        _log('Google sign out failed (may not be signed in): $e');
      }

      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('LOGOUT COMPLETED SUCCESSFULLY');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      _log('Error during sign out: $e');
      rethrow;
    }
  }

  // ✅ Keep existing: Reset password (can use backend later)
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

  // ✅ Keep existing: Check if email is verified
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshedUser = _auth.currentUser;
    return refreshedUser?.emailVerified ?? false;
  }

  // ✅ Keep existing: Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ✅ Keep existing: Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data();
    } catch (e) {
      _log('❌ Error getting user data: $e');
      return null;
    }
  }

  // ✅ Keep existing: Get user data stream
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
      _log('❌ Error updating profile: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Change user password (via backend)
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      _log('🔐 Changing password via backend...');

      final response = await _api.dio.put(
        '/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _log('✅ Password changed successfully');
        return {
          'success': true,
          'message':
              response.data['message'] ?? 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to change password',
        };
      }
    } on DioException catch (e) {
      _log('❌ Backend error: ${e.response?.data}');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to change password',
        };
      } else {
        return {
          'success': false,
          'message': 'Network error. Please check your connection.',
        };
      }
    } catch (e) {
      _log('❌ Error: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Delete user account (via backend)
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      _log('🗑️ Deleting account via backend...');

      final response = await _api.dio.delete('/auth/delete-account');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _log('✅ Account deleted successfully');

        // Sign out locally
        await signOut();

        return {
          'success': true,
          'message': response.data['message'] ?? 'Account deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to delete account',
        };
      }
    } on DioException catch (e) {
      _log('❌ Backend error: ${e.response?.data}');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to delete account',
        };
      } else {
        return {
          'success': false,
          'message': 'Network error. Please check your connection.',
        };
      }
    } catch (e) {
      _log('❌ Error: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }
}

extension StringCapitalizationExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
