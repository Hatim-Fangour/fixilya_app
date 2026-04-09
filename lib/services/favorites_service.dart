import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DataPersistenceService _cache = DataPersistenceService();

  /// GET CURRENT USER ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// TOGGLE FAVORITE (Add/Remove)
  Future<bool> toggleFavorite(String handymanId) async {
    try {
      if (_currentUserId == null) {
        if (kDebugMode) debugPrint('[FavoritesService] No user logged in');
        return false;
      }

      final clientRef = _firestore.collection('clients').doc(_currentUserId);
      final clientDoc = await clientRef.get();

      if (!clientDoc.exists) {
        if (kDebugMode) debugPrint('[FavoritesService] Client document not found');
        return false;
      }

      List<String> favorites = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      if (favorites.contains(handymanId)) {
        favorites.remove(handymanId);
        if (kDebugMode) debugPrint('[FavoritesService] Removed from favorites: $handymanId');
      } else {
        favorites.add(handymanId);
        if (kDebugMode) debugPrint('[FavoritesService] Added to favorites: $handymanId');
      }

      await clientRef.update({
        'favoriteHandymen': favorites,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Invalidate favorites caches so the next read fetches fresh data
      await _cache.invalidateFavoritesCaches();

      if (kDebugMode) debugPrint('[FavoritesService] Favorites updated successfully');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesService] Error toggling favorite: $e');
      return false;
    }
  }

  /// CHECK IF HANDYMAN IS FAVORITE
  ///
  /// Checks the local favorite IDs cache first, then falls back to Firestore.
  Future<bool> isFavorite(String handymanId) async {
    try {
      if (_currentUserId == null) return false;

      // Check local cache first
      final cachedIds = _cache.getCachedData<List<dynamic>>(
        DataPersistenceService.keyFavoriteIds,
        ttl: DataPersistenceService.listTTL,
      );
      if (cachedIds != null) {
        return cachedIds.contains(handymanId);
      }

      final clientDoc = await _firestore
          .collection('clients')
          .doc(_currentUserId)
          .get();

      if (!clientDoc.exists) return false;

      List<String> favorites = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      // Cache the IDs for fast subsequent lookups
      await _cache.cacheData(DataPersistenceService.keyFavoriteIds, favorites);

      return favorites.contains(handymanId);
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesService] Error checking favorite: $e');
      return false;
    }
  }

  /// GET ALL FAVORITE HANDYMEN WITH DETAILS
  ///
  /// Returns cached data instantly if available, then refreshes
  /// from Firestore in the background. On Firestore errors, stale
  /// cached data is returned as a fallback.
  Future<List<Map<String, dynamic>>> getFavoriteHandymen({
    bool forceRefresh = false,
  }) async {
    const cacheKey = DataPersistenceService.keyFavoriteHandymenMapped;

    if (!forceRefresh) {
      final cached = _cache.getCachedData<List<Map<String, dynamic>>>(
        cacheKey,
        ttl: DataPersistenceService.listTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[FavoritesService] Favorites served from cache (${cached.length} items)');
        // Fire-and-forget background refresh
        _refreshFavoriteHandymen();
        return cached;
      }
    }

    return _refreshFavoriteHandymen();
  }

  /// Internal: fetch favorites from Firestore and update cache.
  Future<List<Map<String, dynamic>>> _refreshFavoriteHandymen() async {
    const cacheKey = DataPersistenceService.keyFavoriteHandymenMapped;
    try {
      if (_currentUserId == null) {
        if (kDebugMode) debugPrint('[FavoritesService] No user logged in');
        return [];
      }

      // Get client's favorite handyman IDs
      final clientDoc = await _firestore
          .collection('clients')
          .doc(_currentUserId)
          .get();

      if (!clientDoc.exists) {
        if (kDebugMode) debugPrint('[FavoritesService] Client document not found');
        return [];
      }

      List<String> favoriteIds = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      // Cache the IDs for fast isFavorite() lookups
      await _cache.cacheData(DataPersistenceService.keyFavoriteIds, favoriteIds);

      if (favoriteIds.isEmpty) {
        if (kDebugMode) debugPrint('[FavoritesService] No favorites found');
        await _cache.cacheList(cacheKey, []);
        return [];
      }

      if (kDebugMode) debugPrint('[FavoritesService] Found ${favoriteIds.length} favorite handymen');

      // Fetch details for each favorite handyman
      List<Map<String, dynamic>> favorites = [];

      for (String handymanId in favoriteIds) {
        try {
          final handymanDoc = await _firestore
              .collection('handymen')
              .doc(handymanId)
              .get();

          if (handymanDoc.exists) {
            final data = handymanDoc.data()!;
            favorites.add({
              'id': handymanId,
              'uid': handymanId,
              // Both keys so details page (fullName) and favorites card (name) both work
              'fullName': data['fullName'] ?? 'Unknown',
              'name': data['fullName'] ?? 'Unknown',
              'category': data['category'] ?? 'General',
              'city': data['city'] ?? '',
              'phone': data['phone'] ?? '',
              'rating': data['rating']?.toDouble() ?? 0.0,
              'reviews': data['totalReviews'] ?? 0,
              'hourlyRate': data['hourlyRate'] ?? 0,
              'completedJobs': data['completedJobs'] ?? 0,
              'experience': data['experience'] ?? '0 years',
              // Both keys so details page (approved) and favorites card (verified) both work
              'approved': data['approved'] ?? false,
              'verified': data['approved'] ?? false,
              'profilePicture': data['profilePicture'] ?? '',
              'skills': data['skills'] ?? [],
              'bio': data['bio'] ?? '',
              'availability': data['availability'] ?? false,
              'showPhoneNumber': data['showPhoneNumber'] ?? false,
              'workImages': (data['workImages'] as List?)?.cast<String>() ?? [],
            });
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[FavoritesService] Error fetching handyman $handymanId: $e');
        }
      }

      // Cache the full list for offline access
      await _cache.cacheList(cacheKey, favorites);

      if (kDebugMode) debugPrint('[FavoritesService] Loaded ${favorites.length} favorite handymen');
      return favorites;
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesService] Error getting favorites: $e');
      // Return stale cached data as fallback
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }
  }

  /// GET FAVORITES COUNT
  Future<int> getFavoritesCount() async {
    try {
      // Try cache first
      final cachedIds = _cache.getCachedData<List<dynamic>>(
        DataPersistenceService.keyFavoriteIds,
        ttl: DataPersistenceService.listTTL,
      );
      if (cachedIds != null) {
        return cachedIds.length;
      }

      if (_currentUserId == null) return 0;

      final clientDoc = await _firestore
          .collection('clients')
          .doc(_currentUserId)
          .get();

      if (!clientDoc.exists) return 0;

      List<String> favorites = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      // Cache the IDs
      await _cache.cacheData(DataPersistenceService.keyFavoriteIds, favorites);

      return favorites.length;
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesService] Error getting favorites count: $e');
      // Try stale cache as fallback
      final stale = _cache.getCachedDataStale<List<dynamic>>(
        DataPersistenceService.keyFavoriteIds,
      );
      return stale?.length ?? 0;
    }
  }

  /// REMOVE FAVORITE
  Future<bool> removeFavorite(String handymanId) async {
    return await toggleFavorite(handymanId);
  }

  /// STREAM FAVORITES (Real-time updates)
  Stream<List<String>> streamFavoriteIds() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore.collection('clients').doc(_currentUserId).snapshots().map(
      (doc) {
        if (!doc.exists) return <String>[];
        final ids = List<String>.from(doc.data()?['favoriteHandymen'] ?? []);
        // Update local cache whenever the stream emits
        _cache.cacheData(DataPersistenceService.keyFavoriteIds, ids);
        return ids;
      },
    );
  }
}
