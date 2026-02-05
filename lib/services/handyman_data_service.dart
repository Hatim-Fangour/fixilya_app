import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HandymanDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all approved handymen
  Future<List<Map<String, dynamic>>> getAllHandymen() async {
    try {
      print('📋 Fetching all handymen from Firebase...');

      final snapshot = await _firestore
          .collection('handymen')
          // .where('approved', isEqualTo: true)
          // .where('suspended', isEqualTo: false)
          .get();

      final handymen = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? 'Unknown',
          'category': _getPrimarySkill(data['skills']),
          'city': data['city'] ?? 'Unknown',
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'reviews': data['totalReviews'] ?? 0,
          'phone': data['phone'] ?? '',
          'hourlyRate': _getAverageRate(data['skillPrices']),
          'image': data['profilePicture'] ?? '',
          'verified': data['approved'] ?? false,
          'experience': data['experience'] ?? '',
          'completedJobs': data['completedJobs'] ?? 0,
          'skills': data['skills'] ?? [],
          'skillPrices': data['skillPrices'] ?? {},
          'bio': data['bio'] ?? '',
          'availability': data['availability'] ?? true,
        };
      }).toList();

      print('✅ Fetched ${handymen.length} handymen');
      return handymen;
    } catch (e) {
      print('❌ Error fetching handymen: $e');
      return [];
    }
  }

  /// Stream all approved handymen (real-time updates)
  Stream<List<Map<String, dynamic>>> streamHandymen() {
    return _firestore
        .collection('handymen')
        .where('approved', isEqualTo: true)
        .where('suspended', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['fullName'] ?? 'Unknown',
              'category': _getPrimarySkill(data['skills']),
              'city': data['city'] ?? 'Unknown',
              'rating': (data['rating'] ?? 0.0).toDouble(),
              'reviews': data['totalReviews'] ?? 0,
              'phone': data['phone'] ?? '',
              'hourlyRate': _getAverageRate(data['skillPrices']),
              'image': data['profilePicture'] ?? '',
              'verified': data['approved'] ?? false,
              'experience': data['experience'] ?? '',
              'completedJobs': data['completedJobs'] ?? 0,
              'skills': data['skills'] ?? [],
              'skillPrices': data['skillPrices'] ?? {},
              'bio': data['bio'] ?? '',
              'availability': data['availability'] ?? true,
            };
          }).toList();
        });
  }

  String _getPrimarySkill(dynamic skills) {
    if (skills == null) return 'General Maintenance';
    if (skills is List && skills.isNotEmpty) return skills[0];
    return 'General Maintenance';
  }

  int _getAverageRate(dynamic skillPrices) {
    if (skillPrices == null) return 100;

    if (skillPrices is Map) {
      final prices = skillPrices.values
          .map((price) => int.tryParse(price.toString()) ?? 0)
          .where((price) => price > 0)
          .toList();

      if (prices.isEmpty) return 100;
      return (prices.reduce((a, b) => a + b) / prices.length).round();
    }

    return 100;
  }

  /// Get current handyman's profile data
  Future<Map<String, dynamic>?> getHandymanProfile() async {
    try {
      final user = _auth.currentUser;
      print(' User  :${user}');
      if (user == null) {
        print('❌ No user logged in');
        return null;
      }

      print('🔍 Fetching profile for user: ${user.uid}');

      // Get handyman document
      final handymanDoc = await _firestore
          .collection('handymen')
          .doc(user.uid)
          .get();

      if (!handymanDoc.exists) {
        print('❌ Handyman profile not found');
        return null;
      }

      final handymanData = handymanDoc.data()!;
      print('✅ Handyman profile loaded');
      print(handymanData);

      // Also get user document for name and email
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      // final userData = userDoc.data() ?? {};

      print('handymanData: $handymanData');
      // Merge data
      return {
        ...handymanData,
        'fullName': handymanData['fullName'] ?? 'Handyman',
        'email': handymanData['email'] ?? user.email ?? '',
        'phone': handymanData['phone'] ?? '',
        'uid': user.uid,
      };
    } catch (e) {
      print('❌ Error fetching handyman profile: $e');
      return null;
    }
  }

  /// Get handyman statistics
  Future<Map<String, dynamic>> getHandymanStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultStats();

      print('📊 Fetching stats for user: ${user.uid}');

      // In a real app, you'd fetch this from Firestore
      // For now, return stats initialized to 0
      // You can implement real statistics later when you have bookings

      return {
        'todayEarnings': 0.0,
        'weeklyEarnings': 0.0,
        'monthlyEarnings': 0.0,
        'activeBookings': 0,
        'completedJobs': 0,
        'pendingRequests': 0,
        'rating': 0.0,
        'totalReviews': 0,
      };
    } catch (e) {
      print('❌ Error fetching stats: $e');
      return _getDefaultStats();
    }
  }

  Map<String, dynamic> _getDefaultStats() {
    return {
      'todayEarnings': 0.0,
      'weeklyEarnings': 0.0,
      'monthlyEarnings': 0.0,
      'activeBookings': 0,
      'completedJobs': 0,
      'pendingRequests': 0,
      'rating': 0.0,
      'totalReviews': 0,
    };
  }

  /// Update handyman profile
  Future<bool> updateHandymanProfile(Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('💾 Updating profile for user: ${user.uid}');

      // Separate handyman updates from user updates
      final handymanUpdates = <String, dynamic>{};
      final userUpdates = <String, dynamic>{};

      // Fields that go to handymen collection
      final handymanFields = [
        'city',
        'email',
        'experience',
        'hourlyRate',
        'bio',
        'skills',
        'profileImage',
        'workImages',
        'phone',
      ];

      // Fields that go to users collection
      final userFields = ['fullName', 'email'];

      updates.forEach((key, value) {
        if (handymanFields.contains(key)) {
          handymanUpdates[key] = value;
        } else if (userFields.contains(key)) {
          userUpdates[key] = value;
        }
      });

      // Update handymen collection
      if (handymanUpdates.isNotEmpty) {
        await _firestore.collection('handymen').doc(user.uid).set({
          ...handymanUpdates,
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

  // Update availability status

  Future<bool> updateAvailabilityStatus(bool isAvailable) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('handymen').doc(user.uid).update({
        'isAvailable': isAvailable,
        'lastAvailabilityUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('❌ Error updating availability: $e');
      return false;
    }
  }

  // Get availability status
  Future<bool> getAvailabilityStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return true;

      final doc = await _firestore.collection('handymen').doc(user.uid).get();
      return doc.data()?['isAvailable'] ?? true;
    } catch (e) {
      print('❌ Error getting availability: $e');
      return true;
    }
  }

  /// Stream for real-time profile updates
  Stream<Map<String, dynamic>?> streamHandymanProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore.collection('handymen').doc(user.uid).snapshots().asyncMap(
      (handymanDoc) async {
        if (!handymanDoc.exists) return null;

        final handymanData = handymanDoc.data()!;

        // Get user data too
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data() ?? {};

        return {
          ...handymanData,
          'fullName':
              userData['fullName'] ?? handymanData['fullName'] ?? 'Handyman',
          'email': userData['email'] ?? user.email ?? '',
          'phone': userData['phone'] ?? '',
          'uid': user.uid,
        };
      },
    );
  }
}
