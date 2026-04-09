import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final _api = ApiClient();

  Future<Map<String, dynamic>> completeProfileSkip({
    required String uid,
    required String userType,
  }) async {
    try {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('📝 STARTING complete Profile with Skip WITH BACKEND');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('UID: $uid');
      if (kDebugMode) debugPrint('User Type: $userType');

      final response = await _api.userDio.post(
        '/users/complete-profile-skip',
        data: {'uid': uid, 'userType': userType},
      );

      // response.data will be :
      //  response = {
      //     success: true,
      //     message:
      //       normalizedUserType === "handyman"
      //         ? "Profile created. Complete it later to get approved."
      //         : "Profile created successfully.",
      //     data: {
      //       uid,
      //       userType: normalizedUserType,
      //       profileCompleted: false,
      //       needsApproval: normalizedUserType === "handyman",
      //     },
      //   };

      final data = response.data;
      if (kDebugMode) debugPrint('📥 Backend response: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        if (kDebugMode) debugPrint('✅ Backend Complete Profile Skip successful');

        return {
          'success': true,
          'message':
              data['message'] ?? 'Profile completed with skip successfully',
          'userId': data['data']['uid'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Profile completion with skip failed',
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('❌ BACKEND API ERROR');
      if (kDebugMode) debugPrint('Status Code: ${e.response?.statusCode}');
      if (kDebugMode) debugPrint('Message: ${e.message}');
      if (kDebugMode) debugPrint('Response: ${e.response?.data}');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Complete Profile With Skip failed',
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
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('❌ FIREBASE AUTH ERROR');
      if (kDebugMode) debugPrint('Code: ${e.code}');
      if (kDebugMode) debugPrint('Message: ${e.message}');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': false,
        'message': 'Unknown error',
        'errorCode': e.code,
      };
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('❌ UNEXPECTED ERROR');
      if (kDebugMode) debugPrint('Error: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> completeProfile({
    required dynamic user,
    required String userType,
    required String fullName,
    required String phone,
    required String city,
    required String experience,
    required String bio,
    required List<dynamic> skills,
    String? profilePictureUrl,
    List<String> workImageUrls = const [],
  }) async {
    try {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('📝 STARTING complete Profile WITH BACKEND');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('UID: ${user.uid}');
      if (kDebugMode) debugPrint('User Type: $userType');

      final response = await _api.userDio.post(
        '/users/complete-profile',
        data: {
          'uid': user.uid,
          'userType': 'handyman',
          'fullName': user.displayName ?? '',
          'phone': user.phoneNumber ?? '',
          'city': city,
          'experience': experience,
          // 'hourlyRate': double.tryParse(_hourlyRateController.text) ?? 0,
          'bio': bio,
          'skills': skills,
          'profilePicture': profilePictureUrl, // ✅ Cloudinary URL
          'workImages': workImageUrls, // ✅ Cloudinary URLs
        },
      );

      /*
    response will be:
    {
        success: true,
        message: "Your profile is under review. You'll be notified once approved.",
              
        data: {
          uid,
          userType: normalizedUserType,
          profileCompleted: true,
          needsApproval: normalizedUserType === "handyman",
          isNewUser,
          profilePictureUrl: profilePicture || "", // ✅ Return the URL
          workImageUrls: workImages || [], // ✅ Return the URLs
        },
      };
    
  */

      final data = response.data;
      if (kDebugMode) debugPrint('📥 Backend response: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        if (kDebugMode) debugPrint('✅ Backend Complete Profile successful');

        return {
          'success': true,
          'message': data['message'] ?? 'Profile completed successfully',
          'userId': data['data']['uid'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Profile completion failed',
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('❌ BACKEND API ERROR');
      if (kDebugMode) debugPrint('Status Code: ${e.response?.statusCode}');
      if (kDebugMode) debugPrint('Message: ${e.message}');
      if (kDebugMode) debugPrint('Response: ${e.response?.data}');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (e.response != null) {
        final errorData = e.response!.data;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Complete Profile failed',
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
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('❌ FIREBASE AUTH ERROR');
      if (kDebugMode) debugPrint('Code: ${e.code}');
      if (kDebugMode) debugPrint('Message: ${e.message}');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': false,
        'message': 'Unknown error',
        'errorCode': e.code,
      };
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (kDebugMode) debugPrint('❌ UNEXPECTED ERROR');
      if (kDebugMode) debugPrint('Error: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');
      if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }
}
