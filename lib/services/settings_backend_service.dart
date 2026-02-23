import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';

class SettingsBackendService {
  final ApiClient _apiClient = ApiClient();

  /// Get handyman settings
  Future<Map<String, dynamic>?> getHandymanSettings() async {
    try {
      print('🔍 Fetching handyman settings from backend...');

      final response = await _apiClient.userDio.get('/users/handyman/settings');

      if (response.data['success'] == true) {
        print('✅ Settings loaded from backend');
        return response.data['data'];
      }

      return null;
    } on DioException catch (e) {
      print('❌ Error fetching settings: ${e.response?.data}');
      return null;
    }
  }

  /// Update handyman settings
  Future<bool> updateHandymanSettings(Map<String, dynamic> updates) async {
    try {
      print('📝 Updating handyman settings via backend...');
      print('   Updates: $updates');

      final response = await _apiClient.userDio.put(
        '/users/handyman/settings',
        data: updates,
      );

      if (response.data['success'] == true) {
        print('✅ Settings updated successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Error updating settings: ${e.response?.data}');
      return false;
    }
  }

  /// Update profile picture
  Future<String?> updateProfilePicture(String profilePictureUrl) async {
    try {
      print('📝 Updating profile picture via backend...');
      print('   URL: $profilePictureUrl');

      final response = await _apiClient.userDio.put(
        '/users/handyman/profile-picture',
        data: {'profilePicture': profilePictureUrl},
      );

      if (response.data['success'] == true) {
        print('✅ Profile picture updated successfully');
        return response.data['data']['profilePicture'];
      }

      return null;
    } on DioException catch (e) {
      print('❌ Error updating profile picture: ${e.response?.data}');
      return null;
    }
  }

  /// Update profile info (fullName, phone, city)
  Future<bool> updateProfileInfo(Map<String, dynamic> updates) async {
    try {
      print('📝 Updating profile info via backend...');
      print('   Updates: $updates');

      final response = await _apiClient.userDio.put(
        '/users/handyman/profile',
        data: updates,
      );

      if (response.data['success'] == true) {
        print('✅ Profile info updated successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Error updating profile info: ${e.response?.data}');
      return false;
    }
  }
}