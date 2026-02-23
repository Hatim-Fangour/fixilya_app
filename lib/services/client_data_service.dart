import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current client's profile data
  Future<Map<String, dynamic>?> getClientProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return null;
      }

      print('🔍 Fetching profile for user: ${user.uid}');

      // Get client document
      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();

      if (!clientDoc.exists) {
        print('❌ Client profile not found');
        return null;
      }

      final clientData = clientDoc.data()!;
      print('✅ Client profile loaded');
      print(clientData);

      // Get user document for email (stored in users collection, not clients)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Merge data
      return {
        ...clientData,
        'fullName': clientData['fullName'] ?? 'Client',
        'email': userData['email'] ?? user.email ?? '',
        'phone': clientData['phone'] ?? '',
        'uid': user.uid,
      };
    } catch (e) {
      print('❌ Error fetching client profile: $e');
      return null;
    }
  }

  /// Get client statistics
  Future<Map<String, dynamic>> getClientStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultStats();

      print('📊 Fetching stats for user: ${user.uid}');

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

      return {
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'activeBookings': activeBookings,
        'favoritesCount': favoriteIds.length,
        'pendingBookings': bookingsSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length,
      };
    } catch (e) {
      print('❌ Error fetching stats: $e');
      return _getDefaultStats();
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

  /// Update client profile
  Future<bool> updateClientProfile(Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('💾 Updating profile for user: ${user.uid}');

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

      print('✅ Profile updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  /// Get client's booking history
  Future<List<Map<String, dynamic>>> getClientBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🔍 Fetching bookings for client: ${user.uid}');

      final snapshot = await _firestore
          .collection('bookings')
          .where('clientId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final bookings = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      print('✅ Found ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      print('❌ Error fetching bookings: $e');
      return [];
    }
  }

  /// Get client's favorite handymen
  Future<List<Map<String, dynamic>>> getFavoriteHandymen() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🔍 Fetching favorites for client: ${user.uid}');

      final clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();

      if (!clientDoc.exists) return [];

      final favoriteIds = List<String>.from(
        clientDoc.data()?['favoriteHandymen'] ?? [],
      );

      if (favoriteIds.isEmpty) {
        print('ℹ️ No favorites found');
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

      print('✅ Found ${favorites.length} favorite handymen');
      return favorites;
    } catch (e) {
      print('❌ Error fetching favorites: $e');
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

      print('✅ Added to favorites: $handymanId');
      return true;
    } catch (e) {
      print('❌ Error adding to favorites: $e');
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

      print('✅ Removed from favorites: $handymanId');
      return true;
    } catch (e) {
      print('❌ Error removing from favorites: $e');
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
      print('❌ Error calculating profile completion: $e');
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
      print('❌ Error getting completion details: $e');
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
