import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';

class ClientDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DataPersistenceService _cache = DataPersistenceService();

  // Cache keys specific to this Firestore-based service.
  // Prefixed with 'fs_' to avoid collision with the backend-based keys.
  static const String _profileKey = 'cache_fs_client_profile';
  static const String _statsKey = 'cache_fs_client_stats';
  static const String _bookingsKey = 'cache_fs_client_bookings';

  /// Converts Firestore Timestamps to ISO strings so data can be
  /// stored in GetStorage (which does not support Timestamp objects).
  Map<String, dynamic> _sanitizeForCache(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        sanitized[key] = _sanitizeForCache(Map<String, dynamic>.from(value));
      } else if (value is List) {
        sanitized[key] = value.map((e) {
          if (e is Map) return _sanitizeForCache(Map<String, dynamic>.from(e));
          if (e is Timestamp) return e.toDate().toIso8601String();
          return e;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  /// Get current client's profile data.
  ///
  /// Serves cached data instantly if available, then refreshes from
  /// Firestore in the background. On errors, stale cache is returned.
  Future<Map<String, dynamic>?> getClientProfile({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        _profileKey,
        ttl: DataPersistenceService.profileTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientDataService] Profile served from cache');
        _refreshClientProfile();
        return cached;
      }
    }

    return _refreshClientProfile();
  }

  Future<Map<String, dynamic>?> _refreshClientProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('[ClientDataService] No user logged in');
        return null;
      }

      // Get client document
      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();

      if (!clientDoc.exists) {
        if (kDebugMode) debugPrint('[ClientDataService] Client profile not found');
        return null;
      }

      final clientData = clientDoc.data()!;
      if (kDebugMode) debugPrint('[ClientDataService] Client profile loaded from Firestore');

      // Get user document for email (stored in users collection, not clients)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Merge data
      final merged = {
        ...clientData,
        'fullName': clientData['fullName'] ?? 'Client',
        'email': userData['email'] ?? user.email ?? '',
        'phone': clientData['phone'] ?? '',
        'uid': user.uid,
      };

      // Cache the sanitized result (Timestamps converted to ISO strings)
      await _cache.cacheData(_profileKey, _sanitizeForCache(merged));

      return merged;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClientDataService] Error fetching client profile: $e');
      return _cache.getCachedDataStale<Map<String, dynamic>>(_profileKey);
    }
  }

  /// Get client statistics.
  ///
  /// Cached for fast display, refreshed from Firestore in the background.
  Future<Map<String, dynamic>> getClientStats({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedData<Map<String, dynamic>>(
        _statsKey,
        ttl: DataPersistenceService.statsTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientDataService] Stats served from cache');
        _refreshClientStats();
        return cached;
      }
    }

    return _refreshClientStats();
  }

  Future<Map<String, dynamic>> _refreshClientStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultStats();

      if (kDebugMode) debugPrint('[ClientDataService] Fetching stats from Firestore');

      // Get total bookings count
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('clientId', isEqualTo: user.uid)
          .get();

      final totalBookings = bookingsSnapshot.size;

      // Get completed bookings
      final completedBookings = bookingsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      // Get active bookings
      final activeBookings = bookingsSnapshot.docs
          .where(
            (doc) =>
                ['confirmed', 'in_progress'].contains(doc.data()['status']),
          )
          .length;

      // Get favorites count
      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();
      final favoriteIds = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      final stats = {
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'activeBookings': activeBookings,
        'favoritesCount': favoriteIds.length,
        'pendingBookings': bookingsSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length,
      };

      await _cache.cacheData(_statsKey, stats);
      return stats;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClientDataService] Error fetching stats: $e');
      return _cache.getCachedDataStale<Map<String, dynamic>>(_statsKey) ??
          _getDefaultStats();
    }
  }

  Map<String, dynamic> _getDefaultStats() {
    return {
      'totalBookings': 0,
      'completedBookings': 0,
      'activeBookings': 0,
      'favoritesCount': 0,
      'pendingBookings': 0,
    };
  }

  /// Update client profile.
  ///
  /// Invalidates profile caches after a successful write so the next
  /// read fetches fresh data from Firestore.
  Future<bool> updateClientProfile(Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      if (kDebugMode) debugPrint('[ClientDataService] Updating profile');

      // Separate client updates from user updates
      final clientUpdates = <String, dynamic>{};
      final userUpdates = <String, dynamic>{};

      // Fields that go to clients collection
      final clientFields = [
        'city',
        'fullName',
        'phone',
        'address',
        'profilePicture',
        'favoriteHandymen',
        'favoriteServices',
      ];

      // Fields that go to users collection
      final userFields = ['fullName', 'email'];

      updates.forEach((key, value) {
        if (clientFields.contains(key)) {
          clientUpdates[key] = value;
        } else if (userFields.contains(key)) {
          userUpdates[key] = value;
        }
      });

      // Update clients collection
      if (clientUpdates.isNotEmpty) {
        await _firestore.collection('clients').doc(user.uid).set({
          ...clientUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update users collection
      if (userUpdates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).set({
          ...userUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Invalidate profile caches so next read is fresh
      await _cache.invalidate(_profileKey);
      await _cache.invalidate(_statsKey);
      await _cache.invalidateProfileCaches();

      if (kDebugMode) debugPrint('[ClientDataService] Profile updated, caches invalidated');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClientDataService] Error updating profile: $e');
      return false;
    }
  }

  /// Get client's booking history.
  ///
  /// Cached for offline access; refreshed from Firestore in the background.
  Future<List<Map<String, dynamic>>> getClientBookings({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedData<List<Map<String, dynamic>>>(
        _bookingsKey,
        ttl: DataPersistenceService.listTTL,
      );
      if (cached != null) {
        if (kDebugMode) debugPrint('[ClientDataService] Bookings served from cache (${cached.length} items)');
        _refreshClientBookings();
        return cached;
      }
    }

    return _refreshClientBookings();
  }

  Future<List<Map<String, dynamic>>> _refreshClientBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      if (kDebugMode) debugPrint('[ClientDataService] Fetching bookings from Firestore');

      final snapshot = await _firestore
          .collection('bookings')
          .where('clientId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final bookings = snapshot.docs.map((doc) {
        return _sanitizeForCache({'id': doc.id, ...doc.data()});
      }).toList();

      await _cache.cacheList(_bookingsKey, bookings);

      if (kDebugMode) debugPrint('[ClientDataService] Found ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClientDataService] Error fetching bookings: $e');
      return _cache.getCachedDataStale<List<Map<String, dynamic>>>(_bookingsKey) ?? [];
    }
  }

  /// Get client's favorite handymen
  Future<List<Map<String, dynamic>>> getFavoriteHandymen() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      if (kDebugMode) debugPrint('🔍 Fetching favorites for client: ${user.uid}');

      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();

      if (!clientDoc.exists) return [];

      final favoriteIds = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      if (favoriteIds.isEmpty) {
        if (kDebugMode) debugPrint('ℹ️ No favorites found');
        return [];
      }

      // Fetch handyman details
      final favorites = <Map<String, dynamic>>[];

      for (final handymanId in favoriteIds) {
        final handymanDoc = await _firestore
            .collection('handymen')
            .doc(handymanId)
            .get();

        if (handymanDoc.exists) {
          favorites.add({'id': handymanDoc.id, ...handymanDoc.data()!});
        }
      }

      if (kDebugMode) debugPrint('✅ Found ${favorites.length} favorite handymen');
      return favorites;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching favorites: $e');
      return [];
    }
  }

  /// Add handyman to favorites
  Future<bool> addToFavorites(String handymanId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('clients').doc(user.uid).update({
        'favoriteHandymen': FieldValue.arrayUnion([handymanId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _cache.invalidateFavoritesCaches();
      await _cache.invalidate(_statsKey);
      if (kDebugMode) debugPrint('[ClientDataService] Added to favorites: $handymanId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClientDataService] Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove handyman from favorites
  Future<bool> removeFromFavorites(String handymanId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('clients').doc(user.uid).update({
        'favoriteHandymen': FieldValue.arrayRemove([handymanId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _cache.invalidateFavoritesCaches();
      await _cache.invalidate(_statsKey);
      if (kDebugMode) debugPrint('[ClientDataService] Removed from favorites: $handymanId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ClientDataService] Error removing from favorites: $e');
      return false;
    }
  }

  /// Stream for real-time profile updates
  Stream<Map<String, dynamic>?> streamClientProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore.collection('clients').doc(user.uid).snapshots().asyncMap((
      clientDoc,
    ) async {
      if (!clientDoc.exists) return null;

      final clientData = clientDoc.data()!;

      // Get user data too
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      final userData = userDoc.data() ?? {};

      return {
        ...clientData,
        'fullName': userData['fullName'] ?? clientData['fullName'] ?? 'Client',
        'email': userData['email'] ?? user.email ?? '',
        'phone': userData['phone'] ?? '',
        'uid': user.uid,
      };
    });
  }

  /// Stream for real-time bookings updates
  Stream<List<Map<String, dynamic>>> streamClientBookings() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('bookings')
        .where('clientId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// Stream for favorites count
  Stream<int> streamFavoritesCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore.collection('clients').doc(user.uid).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return 0;
      final favoriteIds = List<String>.from(
        doc.data()?['favoriteHandymen'] ?? [],
      );
      return favoriteIds.length;
    });
  }

  /// Calculate profile completion percentage
  Future<int> calculateProfileCompletion() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final doc = await _firestore.collection('clients').doc(user.uid).get();
      if (!doc.exists) return 0;

      final data = doc.data()!;
      int completed = 0;
      int total = 6;

      // Full Name (20%)
      if (data['fullName']?.toString().isNotEmpty ?? false) completed++;

      // Phone (15%)
      if (data['phone']?.toString().isNotEmpty ?? false) completed++;

      // City (15%)
      if (data['city']?.toString().isNotEmpty ?? false) completed++;

      // Address (15%)
      if (data['address']?.toString().isNotEmpty ?? false) completed++;

      // Profile picture (25%)
      if (data['profilePicture']?.toString().isNotEmpty ?? false) {
        completed++;
        completed++; // Extra weight for profile picture
      }

      return ((completed / total) * 100).round();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error calculating profile completion: $e');
      return 0;
    }
  }

  /// Get profile completion details
  Future<Map<String, dynamic>> getProfileCompletionDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'percentage': 0, 'missingFields': []};
      }

      final doc = await _firestore.collection('clients').doc(user.uid).get();

      if (!doc.exists) {
        return {'percentage': 0, 'missingFields': []};
      }

      final data = doc.data()!;
      List<String> missingFields = [];

      // Check required fields
      if (data['fullName']?.toString().isEmpty ?? true) {
        missingFields.add('Full Name');
      }
      if (data['phone']?.toString().isEmpty ?? true) {
        missingFields.add('Phone Number');
      }
      if (data['city']?.toString().isEmpty ?? true) {
        missingFields.add('City');
      }
      if (data['address']?.toString().isEmpty ?? true) {
        missingFields.add('Address');
      }
      if (data['profilePicture']?.toString().isEmpty ?? true) {
        missingFields.add('Profile Picture');
      }

      final percentage = await calculateProfileCompletion();

      return {'percentage': percentage, 'missingFields': missingFields};
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting completion details: $e');
      return {'percentage': 0, 'missingFields': []};
    }
  }

  /// Stream for real-time profile completion updates
  Stream<int> streamProfileCompletion() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore.collection('clients').doc(user.uid).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) return 0;
      return await calculateProfileCompletion();
    });
  }
}
