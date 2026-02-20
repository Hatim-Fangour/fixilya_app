import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ GET CURRENT USER ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// ✅ TOGGLE FAVORITE (Add/Remove)
  Future<bool> toggleFavorite(String handymanId) async {
    try {
      if (_currentUserId == null) {
        print('❌ No user logged in');
        return false;
      }

      final clientRef = _firestore.collection('clients').doc(_currentUserId);
      final clientDoc = await clientRef.get();

      if (!clientDoc.exists) {
        print('❌ Client document not found');
        return false;
      }

      List<String> favorites = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      if (favorites.contains(handymanId)) {
        // Remove from favorites
        favorites.remove(handymanId);
        print('💔 Removed from favorites: $handymanId');
      } else {
        // Add to favorites
        favorites.add(handymanId);
        print('❤️ Added to favorites: $handymanId');
      }

      await clientRef.update({
        'favoriteHandymen': favorites,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Favorites updated successfully');
      return true;
    } catch (e) {
      print('❌ Error toggling favorite: $e');
      return false;
    }
  }

  /// ✅ CHECK IF HANDYMAN IS FAVORITE
  Future<bool> isFavorite(String handymanId) async {
    try {
      if (_currentUserId == null) return false;

      final clientDoc = await _firestore
          .collection('clients')
          .doc(_currentUserId)
          .get();

      if (!clientDoc.exists) return false;

      List<String> favorites = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      return favorites.contains(handymanId);
    } catch (e) {
      print('❌ Error checking favorite: $e');
      return false;
    }
  }

  /// ✅ GET ALL FAVORITE HANDYMEN WITH DETAILS
  Future<List<Map<String, dynamic>>> getFavoriteHandymen() async {
    try {
      if (_currentUserId == null) {
        print('❌ No user logged in');
        return [];
      }

      // Get client's favorite handyman IDs
      final clientDoc = await _firestore
          .collection('clients')
          .doc(_currentUserId)
          .get();

      if (!clientDoc.exists) {
        print('❌ Client document not found');
        return [];
      }

      List<String> favoriteIds = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      if (favoriteIds.isEmpty) {
        print('ℹ️ No favorites found');
        return [];
      }

      print('📋 Found ${favoriteIds.length} favorite handymen');

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
              'name': data['fullName'] ?? 'Unknown',
              'category': data['category'] ?? 'General',
              'city': data['city'] ?? '',
              'phone': data['phone'] ?? '',
              'rating': data['rating']?.toDouble() ?? 0.0,
              'reviews': data['totalReviews'] ?? 0,
              'hourlyRate': data['hourlyRate'] ?? 0,
              'completedJobs': data['completedJobs'] ?? 0,
              'experience': data['experience'] ?? '0 years',
              'verified': data['approved'] ?? false,
              'profilePicture': data['profilePicture'] ?? '',
              'skills': data['skills'] ?? '',
              'bio': data['bio'] ?? '',
              'availability': data['availability'] ?? false,

              'addedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print('⚠️ Error fetching handyman $handymanId: $e');
        }
      }

      print('✅ Loaded ${favorites.length} favorite handymen with details');
      return favorites;
    } catch (e) {
      print('❌ Error getting favorite handymen: $e');
      return [];
    }
  }

  /// ✅ GET FAVORITES COUNT
  Future<int> getFavoritesCount() async {
    try {
      if (_currentUserId == null) return 0;

      final clientDoc = await _firestore
          .collection('clients')
          .doc(_currentUserId)
          .get();

      if (!clientDoc.exists) return 0;

      List<String> favorites = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      return favorites.length;
    } catch (e) {
      print('❌ Error getting favorites count: $e');
      return 0;
    }
  }

  /// ✅ REMOVE FAVORITE
  Future<bool> removeFavorite(String handymanId) async {
    return await toggleFavorite(handymanId);
  }

  /// ✅ STREAM FAVORITES (Real-time updates)
  Stream<List<String>> streamFavoriteIds() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore.collection('clients').doc(_currentUserId).snapshots().map(
      (doc) {
        if (!doc.exists) return [];
        return List<String>.from(doc.data()?['favoriteHandymen'] ?? []);
      },
    );
  }
}
