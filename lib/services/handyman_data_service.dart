import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';

/// Handles all **REST API calls** for handyman data.
///
/// Rule: every write (mutation) must go through here so it passes
/// through backend authentication, validation, and business logic.
/// One-time reads that don't need real-time updates also live here.
///
/// For real-time data use [HandymanRealtimeService] instead.
///
/// GET methods follow cache-then-network: cached data is returned
/// instantly when available, and a background refresh updates the cache.
class HandymanApiService {
  final _api = ApiClient();
  final _cache = DataPersistenceService();

  // ─────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────

  /// Fetches the full handyman profile from the backend.
  /// Prefer [HandymanRealtimeService.streamHandymanProfile] for screens
  /// that need live updates.
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
        if (kDebugMode) debugPrint('[HandymanApi] Profile served from cache');
        _refreshHandymanProfile();
        return cached;
      }
    }

    return _refreshHandymanProfile();
  }

  Future<Map<String, dynamic>?> _refreshHandymanProfile() async {
    const cacheKey = DataPersistenceService.keyHandymanProfile;
    try {
      final response = await _api.userDio.get('/users/handyman/profile');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheUserProfile(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    } on DioException catch (e) {
      _logDioError('getHandymanProfile', e);
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    }
  }

  /// Updates the handyman profile.
  /// [updates] can contain any subset of: fullName, phone, city,
  /// experience, bio, skills, workImages.
  Future<Map<String, dynamic>> updateHandymanProfile(
      Map<String, dynamic> updates) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/profile',
        data: updates,
      );

      if (response.statusCode == 200) {
        // Invalidate profile cache so the next read fetches fresh data
        await _cache.invalidateProfileCaches();
        return {'success': true, 'message': response.data['message']};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Profile update failed',
      };
    } on DioException catch (e) {
      return _dioErrorResult('updateHandymanProfile', e);
    }
  }

  /// Updates the profile picture URL (Cloudinary URL expected).
  Future<Map<String, dynamic>> updateProfilePicture(String url) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/profile-picture',
        data: {'profilePicture': url},
      );

      if (response.statusCode == 200) {
        await _cache.invalidate(DataPersistenceService.keyHandymanProfile);
        return {'success': true, 'message': response.data['message']};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Profile picture update failed',
      };
    } on DioException catch (e) {
      return _dioErrorResult('updateProfilePicture', e);
    }
  }

  /// Fetches all approved, non-suspended handymen.
  /// Prefer [HandymanRealtimeService.streamHandymen] for screens that
  /// need live updates (e.g. the client browse / search screen).
  Future<List<Map<String, dynamic>>> getAllHandymen({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyHandymenList;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<List<Map<String, dynamic>>>(
        cacheKey,
        ttl: DataPersistenceService.listTTL,
      );
      if (cached != null && cached.isNotEmpty) {
        if (kDebugMode) debugPrint('[HandymanApi] Handymen list served from cache (${cached.length} items)');
        _refreshAllHandymen();
        return cached;
      }
    }

    return _refreshAllHandymen();
  }

  Future<List<Map<String, dynamic>>> _refreshAllHandymen() async {
    const cacheKey = DataPersistenceService.keyHandymenList;
    try {
      // Force a fresh network request -- bypass the Dio cache entirely.
      // The cache interceptor stores ETag-bearing responses and can serve a
      // cached 304 (empty body) on subsequent navigations, causing the list
      // to appear empty. CachePolicy.noCache prevents both caching and
      // conditional-GET requests for this endpoint.
      final response = await _api.userDio.get(
        '/users/handyman/all',
        options: Options(
          extra: CacheOptions(
            store: MemCacheStore(),
            policy: CachePolicy.noCache,
          ).toExtra(),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['data'] as List<dynamic>;
        final data = list.cast<Map<String, dynamic>>();
        await _cache.cacheList(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    } on DioException catch (e) {
      _logDioError('getAllHandymen', e);
      // Return stale cached data on network failure
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }
  }

  // ─────────────────────────────────────────────
  // NEARBY HANDYMEN (map view)
  // ─────────────────────────────────────────────

  /// Fetches approved handymen near the given coordinates from the backend.
  /// The backend handles privacy rules (exact / city_only / on_booking_accept)
  /// and distance filtering server-side.
  ///
  /// Returns a list of handyman maps with: id, uid, fullName, profilePicture,
  /// category, skills, city, rating, reviews, completedJobs, isAvailable,
  /// hourlyRate, bio, phoneNumber, latitude, longitude, distance, isCityLevel.
  Future<List<Map<String, dynamic>>> getNearbyHandymen({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'cache_nearby_handymen_${radiusKm.toInt()}';

    if (!forceRefresh) {
      final cached = _cache.getCachedData<List<Map<String, dynamic>>>(
        cacheKey,
        ttl: const Duration(minutes: 5),
      );
      if (cached != null && cached.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[HandymanApi] Nearby handymen served from cache (${cached.length} items)');
        }
        // Fire-and-forget background refresh
        _refreshNearbyHandymen(lat, lon, radiusKm, cacheKey);
        return cached;
      }
    }

    return _refreshNearbyHandymen(lat, lon, radiusKm, cacheKey);
  }

  Future<List<Map<String, dynamic>>> _refreshNearbyHandymen(
    double lat,
    double lon,
    double radiusKm,
    String cacheKey,
  ) async {
    try {
      final response = await _api.userDio.get(
        '/users/handyman/nearby',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'radius': radiusKm,
        },
        options: Options(
          extra: CacheOptions(
            store: MemCacheStore(),
            policy: CachePolicy.noCache,
          ).toExtra(),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['data'] as List<dynamic>;
        final data = list.cast<Map<String, dynamic>>();
        await _cache.cacheList(cacheKey, data);
        return data;
      }

      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    } on DioException catch (e) {
      _logDioError('getNearbyHandymen', e);
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }
  }

  // ─────────────────────────────────────────────
  // AVAILABILITY
  // ─────────────────────────────────────────────

  /// Fetches current availability status.
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
        _refreshAvailabilityStatus();
        return cached;
      }
    }

    return _refreshAvailabilityStatus();
  }

  Future<Map<String, dynamic>> _refreshAvailabilityStatus() async {
    const cacheKey = DataPersistenceService.keyAvailability;
    try {
      final response =
          await _api.userDio.get('/users/handyman/availability');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        return data;
      }

      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'isAvailable': false};
    } on DioException catch (e) {
      _logDioError('getAvailabilityStatus', e);
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'isAvailable': false};
    }
  }

  /// Toggles availability on / off.
  Future<Map<String, dynamic>> updateAvailabilityStatus(
      bool isAvailable) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/availability',
        data: {'isAvailable': isAvailable},
      );

      if (response.statusCode == 200) {
        // Update the cached availability immediately
        await _cache.cacheData(
          DataPersistenceService.keyAvailability,
          {'isAvailable': isAvailable},
        );
        return {
          'success': true,
          'isAvailable': isAvailable,
          'message': response.data['message'],
        };
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Availability update failed',
      };
    } on DioException catch (e) {
      return _dioErrorResult('updateAvailabilityStatus', e);
    }
  }

  // ─────────────────────────────────────────────
  // STATS & RATINGS
  // ─────────────────────────────────────────────

  /// One-time fetch of full dashboard stats.
  /// Prefer [HandymanRealtimeService.streamHandymanStats] for the dashboard.
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
        if (kDebugMode) debugPrint('[HandymanApi] Stats served from cache');
        _refreshHandymanStats();
        return cached;
      }
    }

    return _refreshHandymanStats();
  }

  Future<Map<String, dynamic>?> _refreshHandymanStats() async {
    const cacheKey = DataPersistenceService.keyHandymanStats;
    try {
      final response = await _api.userDio.get('/users/handyman/stats');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    } on DioException catch (e) {
      _logDioError('getHandymanStats', e);
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    }
  }

  /// One-time fetch of rating + review count.
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
      final response =
          await _api.userDio.get('/users/handyman/rating-stats');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'rating': 0.0, 'reviewCount': 0};
    } on DioException catch (e) {
      _logDioError('getRatingStats', e);
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey) ??
          {'rating': 0.0, 'reviewCount': 0};
    }
  }

  // ─────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────

  /// Fetches notification preferences and account info.
  Future<Map<String, dynamic>?> getHandymanSettings() async {
    try {
      final response =
          await _api.userDio.get('/users/handyman/settings');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      _logDioError('getHandymanSettings', e);
      return null;
    }
  }

  /// Updates notification preferences.
  /// [updates] can contain: pushNotifications, emailNotifications, smsNotifications.
  Future<Map<String, dynamic>> updateHandymanSettings(
      Map<String, dynamic> updates) async {
    try {
      final response = await _api.userDio.put(
        '/users/handyman/settings',
        data: updates,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message']};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Settings update failed',
      };
    } on DioException catch (e) {
      return _dioErrorResult('updateHandymanSettings', e);
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────

  void _logDioError(String method, DioException e) {
    if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (kDebugMode) debugPrint('[HandymanApi] $method');
    if (kDebugMode) debugPrint('   Status : ${e.response?.statusCode}');
    if (kDebugMode) debugPrint('   Message: ${e.message}');
    if (kDebugMode) debugPrint('   Body   : ${e.response?.data}');
    if (kDebugMode) debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  Map<String, dynamic> _dioErrorResult(String method, DioException e) {
    _logDioError(method, e);

    if (e.response != null) {
      return {
        'success': false,
        'message': e.response!.data?['message'] ?? 'Request failed',
      };
    }

    return {
      'success': false,
      'message': switch (e.type) {
        DioExceptionType.connectionTimeout =>
          'Connection timeout. Please try again.',
        DioExceptionType.receiveTimeout => 'Server timeout. Please try again.',
        _ => 'Network error. Please check your connection.',
      },
    };
  }
}
