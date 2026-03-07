import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

/// Central data persistence layer for offline-first caching.
///
/// Uses [GetStorage] (already initialised in main.dart) to persist
/// API responses and domain data across app restarts.
///
/// Every cached entry is stored as a JSON-serialisable map with a
/// `_cachedAt` timestamp so callers can apply TTL-based invalidation.
///
/// Usage:
/// ```dart
/// final cache = DataPersistenceService();
/// await cache.init();
/// await cache.cacheData('user_profile', profileMap);
/// final cached = cache.getCachedData<Map<String, dynamic>>('user_profile');
/// ```
class DataPersistenceService {
  // Singleton
  static final DataPersistenceService _instance =
      DataPersistenceService._internal();
  factory DataPersistenceService() => _instance;
  DataPersistenceService._internal();

  late final GetStorage _box;
  bool _isInitialized = false;

  // ─────────────────────────────────────────────
  // Cache key constants
  // ─────────────────────────────────────────────

  // User / Auth
  static const String keyUserType = 'cache_user_type';
  static const String keyUserProfile = 'cache_user_profile';
  static const String keyClientProfile = 'cache_client_profile';
  static const String keyHandymanProfile = 'cache_handyman_profile';

  // Stats
  static const String keyClientStats = 'cache_client_stats';
  static const String keyHandymanStats = 'cache_handyman_stats';
  static const String keyRatingStats = 'cache_rating_stats';

  // Lists
  static const String keyHandymenList = 'cache_handymen_list';
  static const String keyClientBookings = 'cache_client_bookings';
  static const String keyHandymanBookings = 'cache_handyman_bookings';
  static const String keyFavoriteIds = 'cache_favorite_ids';
  static const String keyFavoriteHandymen = 'cache_favorite_handymen';
  // Mapped format (name/category/etc.) used by FavoritesService — kept separate
  // from keyFavoriteHandymen which stores raw backend format (fullName/etc.)
  static const String keyFavoriteHandymenMapped = 'cache_favorite_handymen_mapped';

  // Settings / Preferences
  static const String keyUserPreferences = 'cache_user_preferences';
  static const String keyAvailability = 'cache_availability';

  // Metadata
  static const String _timestampSuffix = '_cached_at';

  // Default TTLs
  static const Duration defaultTTL = Duration(minutes: 30);
  static const Duration profileTTL = Duration(hours: 2);
  static const Duration listTTL = Duration(minutes: 15);
  static const Duration statsTTL = Duration(minutes: 10);

  // ─────────────────────────────────────────────
  // Initialisation
  // ─────────────────────────────────────────────

  /// Initialise the persistence container.
  /// Safe to call multiple times -- only runs once.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Use a dedicated container so we don't collide with
      // LocalStorageService's default GetStorage container.
      await GetStorage.init('data_cache');
      _box = GetStorage('data_cache');
      _isInitialized = true;
      if (kDebugMode) debugPrint('[DataPersistence] Initialised');
    } catch (e) {
      if (kDebugMode) debugPrint('[DataPersistence] Init error: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────
  // Core read / write
  // ─────────────────────────────────────────────

  /// Cache a JSON-serialisable value under [key].
  Future<void> cacheData(String key, dynamic data) async {
    if (!_isInitialized) return;
    try {
      // GetStorage handles JSON encoding internally for Maps and Lists.
      // Store the raw data and a parallel timestamp key.
      await _box.write(key, data);
      await _box.write(
        '$key$_timestampSuffix',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[DataPersistence] Write error ($key): $e');
    }
  }

  /// Retrieve cached data for [key].
  /// Returns null if not found or if the cache has expired past [ttl].
  T? getCachedData<T>(String key, {Duration? ttl}) {
    if (!_isInitialized) return null;
    try {
      final effectiveTTL = ttl ?? defaultTTL;

      // Check expiry
      final cachedAt = _box.read<int>('$key$_timestampSuffix');
      if (cachedAt != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
        if (age > effectiveTTL.inMilliseconds) {
          // Expired -- return null so the caller knows to refresh.
          return null;
        }
      } else {
        // No timestamp means data was never cached properly.
        return null;
      }

      final raw = _box.read(key);
      if (raw == null) return null;

      // GetStorage stores Maps as Map<String, dynamic> and Lists as
      // List<dynamic>. Attempt a safe cast.
      if (raw is T) return raw;

      // If raw is a List<dynamic> whose elements are Maps, try to
      // cast element-by-element for List<Map<String, dynamic>> callers.
      if (raw is List) {
        try {
          final casted = raw
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
          if (casted is T) return casted as T;
        } catch (_) {
          // Elements were not Maps -- fall through.
        }
      }

      // Fallback: try JSON round-trip for complex nested types.
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is T) return decoded;
      }

      return raw as T;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataPersistence] Read error ($key): $e');
      return null;
    }
  }

  /// Returns cached data even if expired (stale). Useful for showing
  /// old data while a network request is in flight.
  T? getCachedDataStale<T>(String key) {
    if (!_isInitialized) return null;
    try {
      final raw = _box.read(key);
      if (raw == null) return null;

      if (raw is T) return raw;

      // If raw is a List<dynamic> whose elements are Maps, try to
      // cast element-by-element for List<Map<String, dynamic>> callers.
      if (raw is List) {
        try {
          final casted = raw
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
          if (casted is T) return casted as T;
        } catch (_) {
          // Elements were not Maps -- fall through.
        }
      }

      return raw as T;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataPersistence] Stale read error ($key): $e');
      return null;
    }
  }

  /// Check if [key] has valid (non-expired) cached data.
  bool hasFreshCache(String key, {Duration? ttl}) {
    if (!_isInitialized) return false;
    final effectiveTTL = ttl ?? defaultTTL;
    final cachedAt = _box.read<int>('$key$_timestampSuffix');
    if (cachedAt == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    return age <= effectiveTTL.inMilliseconds;
  }

  /// Returns the age of the cached entry, or null if not cached.
  Duration? getCacheAge(String key) {
    if (!_isInitialized) return null;
    final cachedAt = _box.read<int>('$key$_timestampSuffix');
    if (cachedAt == null) return null;
    return Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - cachedAt,
    );
  }

  // ─────────────────────────────────────────────
  // Typed convenience helpers
  // ─────────────────────────────────────────────

  /// Cache user profile (client or handyman).
  Future<void> cacheUserProfile(
    String key,
    Map<String, dynamic> profile,
  ) async {
    await cacheData(key, profile);
  }

  /// Cache a list of items (bookings, handymen, favorites, etc.).
  Future<void> cacheList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    await cacheData(key, items);
  }

  /// Cache a simple string value (e.g. user type).
  Future<void> cacheString(String key, String value) async {
    await cacheData(key, value);
  }

  /// Read a cached string.
  String? getCachedString(String key, {Duration? ttl}) {
    return getCachedData<String>(key, ttl: ttl);
  }

  // ─────────────────────────────────────────────
  // Invalidation
  // ─────────────────────────────────────────────

  /// Remove a single cached entry.
  Future<void> invalidate(String key) async {
    if (!_isInitialized) return;
    try {
      await _box.remove(key);
      await _box.remove('$key$_timestampSuffix');
    } catch (e) {
      if (kDebugMode) debugPrint('[DataPersistence] Invalidate error ($key): $e');
    }
  }

  /// Invalidate multiple keys at once.
  Future<void> invalidateAll(List<String> keys) async {
    for (final key in keys) {
      await invalidate(key);
    }
  }

  /// Invalidate all profile-related caches (useful after profile update).
  Future<void> invalidateProfileCaches() async {
    await invalidateAll([
      keyUserProfile,
      keyClientProfile,
      keyHandymanProfile,
      keyClientStats,
      keyHandymanStats,
      keyRatingStats,
    ]);
    if (kDebugMode) debugPrint('[DataPersistence] Profile caches invalidated');
  }

  /// Invalidate booking caches (useful after creating/cancelling a booking).
  Future<void> invalidateBookingCaches() async {
    await invalidateAll([
      keyClientBookings,
      keyHandymanBookings,
      keyClientStats,
      keyHandymanStats,
    ]);
    if (kDebugMode) debugPrint('[DataPersistence] Booking caches invalidated');
  }

  /// Invalidate favorites caches.
  Future<void> invalidateFavoritesCaches() async {
    await invalidateAll([
      keyFavoriteIds,
      keyFavoriteHandymen,
      keyFavoriteHandymenMapped,
      keyClientStats,
    ]);
    if (kDebugMode) debugPrint('[DataPersistence] Favorites caches invalidated');
  }

  /// Clear ALL cached data. Called on logout.
  Future<void> clearAll() async {
    if (!_isInitialized) return;
    try {
      await _box.erase();
      if (kDebugMode) debugPrint('[DataPersistence] All caches cleared');
    } catch (e) {
      if (kDebugMode) debugPrint('[DataPersistence] Clear error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Debug helpers
  // ─────────────────────────────────────────────

  /// Print all cached keys and their ages (debug only).
  void debugPrintCacheStatus() {
    if (!kDebugMode || !_isInitialized) return;
    final keys = _box.getKeys<Iterable<String>>();
    debugPrint('[DataPersistence] === Cache Status ===');
    for (final key in keys) {
      if (key.endsWith(_timestampSuffix)) continue;
      final age = getCacheAge(key);
      final ageStr = age != null ? '${age.inSeconds}s ago' : 'no timestamp';
      debugPrint('  $key ($ageStr)');
    }
    debugPrint('[DataPersistence] ===================');
  }
}
