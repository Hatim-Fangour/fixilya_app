import 'package:dio/dio.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ApiErrorHandler {
  static bool _isLoggingOut = false;

  static Future<void> handleError(DioException error) async {
    if (error.response?.statusCode == 401) {
      final errorMessage =
          (error.response?.data is Map ? error.response?.data['message'] : '') ?? '';

      if (kDebugMode) debugPrint('401 Unauthorized: $errorMessage');

      if (errorMessage.toLowerCase().contains('token') ||
          errorMessage.toLowerCase().contains('expired') ||
          errorMessage.toLowerCase().contains('unauthorized')) {
        if (!_isLoggingOut) {
          _isLoggingOut = true;
          try {
            await _handleTokenExpiration();
          } finally {
            _isLoggingOut = false;
          }
        }
      }
      return;
    }

    if (error.response?.statusCode == 403) {
      final errorMessage =
          (error.response?.data is Map ? error.response?.data['message'] : '') ?? '';

      if (errorMessage.toLowerCase().contains('suspended')) {
        await _handleAccountSuspended();
      }
      return;
    }

    if (error.response?.statusCode == 500) {
      Get.snackbar(
        'Server Error',
        'Something went wrong. Please try again later.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
      );
      return;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      Get.snackbar(
        'Connection Error',
        'Please check your internet connection',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
      );
      return;
    }
  }

  static Future<void> _handleTokenExpiration() async {
    if (kDebugMode) debugPrint('Session expired — signing out');

    try {
      final authService = AuthService();
      await authService.signOut();

      AppRoutes.offAll(AppRoutes.welcome);

      Get.snackbar(
        'Session Expired',
        'Your session has expired. Please login again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        icon: const Icon(Icons.access_time_rounded, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error during auto-logout: $e');
    }
  }

  static Future<void> _handleAccountSuspended() async {
    if (kDebugMode) debugPrint('Account suspended');

    try {
      final authService = AuthService();
      await authService.signOut();

      AppRoutes.offAll(AppRoutes.welcome);

      Get.snackbar(
        'Account Suspended',
        'Your account has been suspended. Please contact support.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        icon: const Icon(Icons.block, color: Colors.white),
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error during suspended logout: $e');
    }
  }
}
