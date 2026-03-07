import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';

/// Backend service for client-specific API calls.
/// Mirrors [HandymanBackendService] -- all data comes from the Node microservice,
/// never directly from Firestore on the client.
///
/// Every GET method follows cache-then-network:
///   1. Return cached data immediately (if fresh enough).
///   2. Fetch from the network in parallel / on cache miss.
///   3. Update the local cache on success.
///   4. On network failure, return stale cached data as a fallback.
class ClientBackendService {
  final ApiClient _apiClient = ApiClient();
  final DataPersistenceService _cache = DataPersistenceService();

  // ─────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────

  /// GET /users/client/profile
  ///
  /// Returns the client profile, served from cache when fresh
  /// and always refreshed from the network in the background.
  /// If the network call fails, stale cached data is returned.
  Future<Map<String, dynamic>?> getClientProfile({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyClientProfile;

    // 1. Serve from cache if fresh (unless caller forces refresh)
    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        cacheKey,
        ttl: DataPersistenceService.profileTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientBackendService] Profile served from cache');
        // Fire-and-forget background refresh
        _refreshClientProfile();
        return cached;
      }
    }

    // 2. Network fetch
    return _refreshClientProfile();
  }

  /// Internal: fetch profile from network and update cache.
  Future<Map<String, dynamic>?> _refreshClientProfile() async {
    const cacheKey = DataPersistenceService.keyClientProfile;
    try {
      final response = await _apiClient.userDio.get('/users/client/profile');
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheUserProfile(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] getClientProfile network error: ${e.type}');
      // Fallback to stale cache
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    }
  }

  /// PUT /users/client/profile
  Future<bool> updateClientProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _apiClient.userDio.put(
        '/users/client/profile',
        data: updates,
      );
      if (response.data['success'] == true) {
        // Invalidate so next read fetches fresh data
        await _cache.invalidate(DataPersistenceService.keyClientProfile);
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] updateClientProfile error: ${e.response?.data}');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────

  /// GET /users/client/stats
  /// Returns { totalBookings, favoritesCount }
  Future<Map<String, dynamic>?> getClientStats({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyClientStats;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        cacheKey,
        ttl: DataPersistenceService.statsTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientBackendService] Stats served from cache');
        _refreshClientStats();
        return cached;
      }
    }

    return _refreshClientStats();
  }

  Future<Map<String, dynamic>?> _refreshClientStats() async {
    const cacheKey = DataPersistenceService.keyClientStats;
    try {
      final response = await _apiClient.userDio.get('/users/client/stats');
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        await _cache.cacheData(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] getClientStats network error: ${e.type}');
      return _cache.getCachedDataStale<Map<String, dynamic>>(cacheKey);
    }
  }

  // ─────────────────────────────────────────────
  // BOOKINGS
  // ─────────────────────────────────────────────

  /// GET /users/client/bookings?limit=5&status=all
  Future<List<Map<String, dynamic>>> getClientBookings({
    int limit = 5,
    String? status,
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyClientBookings;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<List<Map<String, dynamic>>>(
        cacheKey,
        ttl: DataPersistenceService.listTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientBackendService] Bookings served from cache (${cached.length} items)');
        _refreshClientBookings(limit: limit, status: status);
        return cached;
      }
    }

    return _refreshClientBookings(limit: limit, status: status);
  }

  Future<List<Map<String, dynamic>>> _refreshClientBookings({
    int limit = 5,
    String? status,
  }) async {
    const cacheKey = DataPersistenceService.keyClientBookings;
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (status != null) queryParams['status'] = status;

      final response = await _apiClient.userDio.get(
        '/users/client/bookings',
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        final data = raw.cast<Map<String, dynamic>>();
        await _cache.cacheList(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] getClientBookings network error: ${e.type}');
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }
  }

  // ─────────────────────────────────────────────
  // FAVORITES
  // ─────────────────────────────────────────────

  /// GET /users/client/favorites
  Future<List<Map<String, dynamic>>> getClientFavorites({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyFavoriteHandymen;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<List<Map<String, dynamic>>>(
        cacheKey,
        ttl: DataPersistenceService.listTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientBackendService] Favorites served from cache (${cached.length} items)');
        _refreshClientFavorites();
        return cached;
      }
    }

    return _refreshClientFavorites();
  }

  Future<List<Map<String, dynamic>>> _refreshClientFavorites() async {
    const cacheKey = DataPersistenceService.keyFavoriteHandymen;
    try {
      final response =
          await _apiClient.userDio.get('/users/client/favorites');
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        final data = raw.cast<Map<String, dynamic>>();
        await _cache.cacheList(cacheKey, data);
        return data;
      }
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] getClientFavorites network error: ${e.type}');
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }
  }

  /// POST /users/client/favorites/:handymanId
  Future<bool> addFavorite(String handymanId) async {
    try {
      final response = await _apiClient.userDio.post(
        '/users/client/favorites/$handymanId',
      );
      if (response.data['success'] == true) {
        await _cache.invalidateFavoritesCaches();
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] addFavorite error: ${e.response?.data}');
      return false;
    }
  }

  /// DELETE /users/client/favorites/:handymanId
  Future<bool> removeFavorite(String handymanId) async {
    try {
      final response = await _apiClient.userDio.delete(
        '/users/client/favorites/$handymanId',
      );
      if (response.data['success'] == true) {
        await _cache.invalidateFavoritesCaches();
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ClientBackendService] removeFavorite error: ${e.response?.data}');
      return false;
    }
  }
}
