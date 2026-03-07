import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';

/// Handles all backend calls for [HandymanSettingsPage].
///
/// Every method maps 1-to-1 to an existing endpoint in handyman.routes.js.
/// No direct Firestore writes — all mutations go through the API.
class SettingsBackendService {
  final _api = ApiClient();

  // ─────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────

  /// GET /users/handyman/settings
  ///
  /// Returns: { fullName, email, phone, city, profilePicture,
  ///            pushNotifications, emailNotifications, smsNotifications }
  Future<Map<String, dynamic>?> getHandymanSettings() async {
    try {
      final response = await _api.userDio.get('/users/handyman/settings');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }

      return null;
    } on DioException catch (e) {
      _logError('getHandymanSettings', e);
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────

  /// PUT /users/handyman/settings
  ///
  /// Accepted keys: pushNotifications, emailNotifications, smsNotifications.
  /// Any other keys are stripped by the backend (whitelist-based).
  ///
  /// Returns true on success.
  Future<bool> updateHandymanSettings(Map<String, dynamic> updates) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/settings',
        data: updates,
      );

      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      _logError('updateHandymanSettings', e);
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // PROFILE INFO
  // ─────────────────────────────────────────────

  /// PUT /users/handyman/profile
  ///
  /// Accepted keys: fullName, phone, city, experience, bio, skills, workImages.
  /// Protected fields (uid, email, approved, etc.) are stripped by the backend.
  ///
  /// Returns true on success.
  Future<bool> updateProfileInfo(Map<String, dynamic> updates) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/profile',
        data: updates,
      );

      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      _logError('updateProfileInfo', e);
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // PROFILE PICTURE
  // ─────────────────────────────────────────────

  /// PUT /users/handyman/profile-picture
  ///
  /// [url] must be a valid Cloudinary URL (already uploaded before calling this).
  ///
  /// Returns the saved URL on success, null on failure.
  Future<String?> updateProfilePicture(String url) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/profile-picture',
        data: {'profilePicture': url},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Backend echoes the URL back in data.profilePicture
        return response.data['data']?['profilePicture'] as String? ?? url;
      }

      return null;
    } on DioException catch (e) {
      _logError('updateProfilePicture', e);
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────

  void _logError(String method, DioException e) {
    if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (kDebugMode) debugPrint('❌ SettingsBackendService.$method');
    if (kDebugMode) debugPrint('   Status : ${e.response?.statusCode}');
    if (kDebugMode) debugPrint('   Message: ${e.message}');
    if (kDebugMode) debugPrint('   Body   : ${e.response?.data}');
    if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
