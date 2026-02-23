import 'package:dio/dio.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ApiErrorHandler {
  static bool _isLoggingOut = false;

  static Future<void> handleError(DioException error) async {
    // ✅ Handle 401 - Unauthorized / Token Expired
    if (error.response?.statusCode == 401) {
      final errorMessage = error.response?.data['message'] ?? '';

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔐 401 Unauthorized Detected');
      print('Message: $errorMessage');

      if (errorMessage.toLowerCase().contains('token') ||
          errorMessage.toLowerCase().contains('expired') ||
          errorMessage.toLowerCase().contains('unauthorized')) {
        if (!_isLoggingOut) {
          _isLoggingOut = true;
          // await _handleTokenExpiration();
          _isLoggingOut = false;
        }
      }
      return;
    }

    // ✅ Handle 403 - Forbidden / Account Suspended
    if (error.response?.statusCode == 403) {
      final errorMessage = error.response?.data['message'] ?? '';

      if (errorMessage.toLowerCase().contains('suspended')) {
        await _handleAccountSuspended();
      }
      return;
    }

    // ✅ Handle 500 - Server Error
    if (error.response?.statusCode == 500) {
      Get.snackbar(
        'Server Error',
        'Something went wrong. Please try again later.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 16,
      );
      return;
    }

    // ✅ Handle Network Errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      Get.snackbar(
        'Connection Error',
        'Please check your internet connection',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 16,
      );
      return;
    }
  }

  // ✅ Token Expiration Handler
  static Future<void> _handleTokenExpiration() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔐 SESSION EXPIRED - Auto Logout');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final authService = AuthService();
      await authService.signOut();

      AppRoutes.toWelcome();

      Get.snackbar(
        'Session Expired',
        'Your session has expired. Please login again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 16,
        icon: Icon(Icons.access_time_rounded, color: Colors.white),
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print('❌ Error during auto-logout: $e');
    }
  }

  // ✅ Account Suspended Handler
  static Future<void> _handleAccountSuspended() async {
    print('⚠️ Account suspended');

    final authService = AuthService();
    await authService.signOut();

    AppRoutes.toWelcome();

    Get.snackbar(
      'Account Suspended',
      'Your account has been suspended. Please contact support.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      margin: EdgeInsets.all(16),
      borderRadius: 16,
      icon: Icon(Icons.block, color: Colors.white),
      duration: Duration(seconds: 5),
    );
  }
}
