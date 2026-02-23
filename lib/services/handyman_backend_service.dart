import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';

class HandymanBackendService {
  final ApiClient _apiClient = ApiClient();

  /// Get handyman profile
  Future<Map<String, dynamic>?> getHandymanProfile() async {
    try {
      print('🔍 Fetching handyman profile from backend...');

      final response = await _apiClient.userDio.get('/users/handyman/profile');
      print('📋 Response data: ${response.data}');
      print('📋 Response: ${response}');

      if (response.data['success'] == true) {
        print('✅ Handyman profile loaded from backend');
        return response.data['data'];
      }

      return null;
    } on DioException catch (e) {
      print('❌ Error fetching profile: ${e.response?.data}');
      return null;
    }
  }

  /// Get rating stats
  Future<Map<String, dynamic>> getRatingStats() async {
    try {
      print('📊 Fetching rating stats from backend...');

      final response = await _apiClient.userDio.get(
        '/users/handyman/rating-stats',
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }

      return {'rating': 0.0, 'reviewCount': 0};
    } on DioException catch (e) {
      print('❌ Error fetching rating stats: ${e.response?.data}');
      return {'rating': 0.0, 'reviewCount': 0};
    }
  }

  /// Get handyman stats
  Future<Map<String, dynamic>?> getHandymanStats() async {
    try {
      print('📊 Fetching handyman stats from backend...');

      final response = await _apiClient.userDio.get('/users/handyman/stats');

      if (response.data['success'] == true) {
        print('✅ Stats loaded from backend');
        return response.data['data'];
      }

      return null;
    } on DioException catch (e) {
      print('❌ Error fetching stats: ${e.response?.data}');
      return null;
    }
  }

  /// Update handyman profile
  Future<bool> updateHandymanProfile(Map<String, dynamic> updates) async {
    try {
      print('📝 Updating handyman profile via backend...');
      print('   Updates: $updates');

      final response = await _apiClient.userDio.put(
        '/users/handyman/profile',
        data: updates,
      );

      if (response.data['success'] == true) {
        print('✅ Handyman profile updated successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Error updating profile: ${e.response?.data}');
      return false;
    }
  }

  /// Update availability status
  Future<bool> updateAvailabilityStatus(bool isAvailable) async {
    try {
      print('📝 Updating availability via backend: $isAvailable');

      final response = await _apiClient.userDio.put(
        '/users/handyman/availability',
        data: {'isAvailable': isAvailable},
      );

      if (response.data['success'] == true) {
        print('✅ Availability updated successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Error updating availability: ${e.response?.data}');
      return false;
    }
  }

  /// Get availability status
  Future<Map<String, dynamic>> getAvailabilityStatus() async {
    try {
      final response = await _apiClient.userDio.get(
        '/users/handyman/availability',
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }

      return {'isAvailable': false};
    } on DioException catch (e) {
      print('❌ Error getting availability: ${e.response?.data}');
      return {'isAvailable': false};
    }
  }
}
