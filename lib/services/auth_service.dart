// lib/core/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // ✅ ADD: Base URL for your backend
  static const String _baseUrl = 'http://localhost:3001/api/auth';

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
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📝 STARTING SIGNUP WITH BACKEND');
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

      // ✅ Call backend registration API using ApiClient
      print('🌐 Calling backend API...');
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
      print('📥 Backend response: $data');

      if (response.statusCode == 201 && data['success'] == true) {
        print('✅ Backend registration successful');

        // ✅ Sign in to Firebase (to get the user object)
        print('🔐 Signing in to Firebase...');
        final userCredential = await _auth
            .signInWithEmailAndPassword(
              email: email.trim().toLowerCase(),
              password: password,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw FirebaseAuthException(
                  code: 'timeout',
                  message: 'Firebase sign-in timed out. Please try again.',
                );
              },
            );

        final user = userCredential.user;
        print('✅ Firebase sign-in successful: ${user?.uid}');

        // ✅ CRITICAL: Force token refresh and wait for it to be ready
        if (user != null) {
          print('🔄 Forcing token refresh...');
          try {
            await user.reload();
            final token = await user.getIdToken(true); // Force refresh
            if (token != null) {
              print(
                '✅ Token refreshed and ready: ${token.substring(0, 20)}...',
              );
            } else {
              print('⚠️ Warning: Token is null after refresh');
            }
          } catch (e) {
            print('⚠️ Token refresh warning: $e');
          }
        }

        // ✅ Send verification email
        // try {
        //   print('📧 Sending verification email...');
        //   await user?.sendEmailVerification().timeout(
        //     const Duration(seconds: 10),
        //     onTimeout: () {
        //       print('⏱️ Email verification timeout - continuing anyway');
        //       return;
        //     },
        //   );
        //   print('✅ Verification email sent');
        // } catch (e) {
        //   print('⚠️ Failed to send verification email: $e');
        // }

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ SIGNUP SUCCESSFUL');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ BACKEND API ERROR');
      print('Status Code: ${e.response?.statusCode}');
      print('Message: ${e.message}');
      print('Response: ${e.response?.data}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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

  // ✅ NEW: Complete registration after email verification
  Future<Map<String, dynamic>> completeRegistration({
    required String uid,
    required String fullName,
    required String phone,
    required String userType,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📝 COMPLETING REGISTRATION');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
        print('✅ Registration completed successfully');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
      print('❌ Backend Error: ${e.message}');

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
      print('❌ Error: $e');
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

      final data = response.data;

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

      print('🔍 Getting user type for: ${user.uid}');

      // Check users collection FIRST
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

      // Default to CLIENT
      print('⚠️ User type not found, defaulting to client');
      return 'client';
    } catch (e) {
      print('❌ Error: $e');
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
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔐 STARTING LOGIN WITH BACKEND');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Call backend login API
      final response = await _api.dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final data = response.data;

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Backend login successful');

        // ✅ Sign in to Firebase with custom token
        final customToken = data['data']['accessToken'];
        await _auth.signInWithCustomToken(customToken);

        print('✅ Firebase sign-in successful');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return {
          'success': true,
          'message': data['message'],
          'userType': data['data']['userType'],
          'userData': data['data'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } on DioException catch (e) {
      print('❌ Backend Login Error: ${e.message}');

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

  // ✅ Keep existing: Sign out
  Future<void> signOut() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚪 STARTING LOGOUT PROCESS');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Reset theme to system mode
      try {
        final themeController = Get.find<ThemeController>();
        await themeController.resetThemeToSystem();
        print('✅ Theme reset to system mode');
      } catch (e) {
        print('⚠️ ThemeController not found or reset failed: $e');
      }

      // Sign out from Firebase Auth
      await _auth.signOut();
      print('✅ Signed out from Firebase Auth');

      // Sign out from Google
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
      print('❌ Error getting user data: $e');
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
      print('❌ Error updating profile: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Change user password (via backend)
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      print('🔐 Changing password via backend...');

      final response = await _api.dio.put(
        '/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Password changed successfully');
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
      print('❌ Backend error: ${e.response?.data}');

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
      print('❌ Error: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Delete user account (via backend)
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      print('🗑️ Deleting account via backend...');

      final response = await _api.dio.delete('/auth/delete-account');

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Account deleted successfully');

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
      print('❌ Backend error: ${e.response?.data}');

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
      print('❌ Error: $e');
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
