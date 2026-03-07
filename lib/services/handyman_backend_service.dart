import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';

/// Backend service for handyman-specific API calls.
///
/// GET methods follow cache-then-network: cached data is returned
/// instantly when available, and a background refresh updates the cache.
class HandymanBackendService {
  final ApiClient _apiClient = ApiClient();
  final DataPersistenceService _cache = DataPersistenceService();

  /// Get handyman profile
  Future<Map<String, dynamic>?> getHandymanProfile({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyHandymanProfile;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        cacheKey,
        ttl: DataPersistenceService.profileTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[HandymanBackend] Profile served from cache');
        _refreshProfile();
        return cached;
      }
    }

    return _refreshProfile();
  }

  Future<Map<String, dynamic>?> _refreshProfile() async {
    const cacheKey = DataPersistenceService.keyHandymanProfile;
    try {
      final response = await _apiClient.userDio.get('/users/handyman/profile');

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheUserProfile(cacheKey, data);
        if (kDebugMode) debugPrint('[HandymanBackend] Profile loaded from network');
        return data;
      }

      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[HandymanBackend] Profile network error: ${e.type}');
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    }
  }

  /// Get rating stats
  Future<Map<String, dynamic>> getRatingStats({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyRatingStats;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        cacheKey,
        ttl: DataPersistenceService.statsTTL,
      );
      if (cached != null) {
        _refreshRatingStats();
        return cached;
      }
    }

    return _refreshRatingStats();
  }

  Future<Map<String, dynamic>> _refreshRatingStats() async {
    const cacheKey = DataPersistenceService.keyRatingStats;
    try {
      final response = await _apiClient.userDio.get(
        '/users/handyman/rating-stats',
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        return data;
      }

      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'rating': 0.0, 'reviewCount': 0};
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[HandymanBackend] Rating stats error: ${e.type}');
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'rating': 0.0, 'reviewCount': 0};
    }
  }

  /// Get handyman stats
  Future<Map<String, dynamic>?> getHandymanStats({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyHandymanStats;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        cacheKey,
        ttl: DataPersistenceService.statsTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[HandymanBackend] Stats served from cache');
        _refreshStats();
        return cached;
      }
    }

    return _refreshStats();
  }

  Future<Map<String, dynamic>?> _refreshStats() async {
    const cacheKey = DataPersistenceService.keyHandymanStats;
    try {
      final response = await _apiClient.userDio.get('/users/handyman/stats');

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        if (kDebugMode) debugPrint('[HandymanBackend] Stats loaded from network');
        return data;
      }

      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[HandymanBackend] Stats network error: ${e.type}');
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    }
  }

  /// Update handyman profile
  Future<bool> updateHandymanProfile(Map<String, dynamic> updates) async {
    try {
      if (kDebugMode) debugPrint('[HandymanBackend] Updating profile...');

      final response = await _apiClient.userDio.put(
        '/users/handyman/profile',
        data: updates,
      );

      if (response.data['success'] == true) {
        // Invalidate cached profile so next read fetches fresh data
        await _cache.invalidateProfileCaches();
        if (kDebugMode) debugPrint('[HandymanBackend] Profile updated, cache invalidated');
        return true;
      }

      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[HandymanBackend] Update error: ${e.response?.data}');
      return false;
    }
  }

  /// Update availability status
  Future<bool> updateAvailabilityStatus(bool isAvailable) async {
    try {
      if (kDebugMode) debugPrint('[HandymanBackend] Updating availability: $isAvailable');

      final response = await _apiClient.userDio.put(
        '/users/handyman/availability',
        data: {'isAvailable': isAvailable},
      );

      if (response.data['success'] == true) {
        // Update cached availability immediately
        await _cache.cacheData(
          DataPersistenceService.keyAvailability,
          {'isAvailable': isAvailable},
        );
        if (kDebugMode) debugPrint('[HandymanBackend] Availability updated');
        return true;
      }

      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[HandymanBackend] Availability error: ${e.response?.data}');
      return false;
    }
  }

  /// Get availability status
  Future<Map<String, dynamic>> getAvailabilityStatus({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyAvailability;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        cacheKey,
        ttl: DataPersistenceService.statsTTL,
      );
      if (cached != null) {
        _refreshAvailability();
        return cached;
      }
    }

    return _refreshAvailability();
  }

  Future<Map<String, dynamic>> _refreshAvailability() async {
    const cacheKey = DataPersistenceService.keyAvailability;
    try {
      final response = await _apiClient.userDio.get(
        '/users/handyman/availability',
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        return data;
      }

      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'isAvailable': false};
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[HandymanBackend] Availability fetch error: ${e.type}');
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'isAvailable': false};
    }
  }
}
