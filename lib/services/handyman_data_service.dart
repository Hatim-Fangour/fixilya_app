import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HandymanDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, double>> getEarningsData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'today': 0.0, 'week': 0.0, 'month': 0.0};
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: 7));
      final monthStart = now.subtract(Duration(days: 30));

      // Fetch completed bookings
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('handymanId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      double todayEarnings = 0.0;
      double weekEarnings = 0.0;
      double monthEarnings = 0.0;

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();

        // Get completion date
        DateTime? completedDate;
        if (data['completedAt'] != null) {
          completedDate = (data['completedAt'] as Timestamp).toDate();
        }

        if (completedDate != null) {
          // Today's earnings
          if (completedDate.isAfter(todayStart)) {
            todayEarnings += amount;
          }

          // Weekly earnings
          if (completedDate.isAfter(weekStart)) {
            weekEarnings += amount;
          }

          // Monthly earnings
          if (completedDate.isAfter(monthStart)) {
            monthEarnings += amount;
          }
        }
      }

      print(
        '✅ Earnings: Today=$todayEarnings, Week=$weekEarnings, Month=$monthEarnings',
      );

      return {
        'today': todayEarnings,
        'week': weekEarnings,
        'month': monthEarnings,
      };
    } catch (e) {
      print('❌ Error getting earnings: $e');
      return {'today': 0.0, 'week': 0.0, 'month': 0.0};
    }
  }

  /// ✅ STREAM EARNINGS DATA (Real-time updates)
  Stream<Map<String, double>> streamEarningsData() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value({'today': 0.0, 'week': 0.0, 'month': 0.0});
    }

    return _firestore
        .collection('bookings')
        .where('handymanId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekAgo = today.subtract(Duration(days: 7));
          final monthAgo = DateTime(now.year, now.month - 1, now.day);

          double todayEarnings = 0.0;
          double weekEarnings = 0.0;
          double monthEarnings = 0.0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final amount = (data['amount'] ?? 0.0).toDouble();
            final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

            if (completedAt != null) {
              if (completedAt.isAfter(today)) {
                todayEarnings += amount;
              }
              if (completedAt.isAfter(weekAgo)) {
                weekEarnings += amount;
              }
              if (completedAt.isAfter(monthAgo)) {
                monthEarnings += amount;
              }
            }
          }

          return {
            'today': todayEarnings,
            'week': weekEarnings,
            'month': monthEarnings,
          };
        });
  }

  Future<Map<String, dynamic>> getRatingStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'rating': 0.0, 'reviewCount': 0};

      // Get all reviews for this handyman
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('handymanId', isEqualTo: user.uid)
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        return {'rating': 0.0, 'reviewCount': 0};
      }

      // Calculate average rating
      double totalRating = 0;
      int reviewCount = reviewsSnapshot.docs.length;

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final rating = (data['rating'] ?? 0).toDouble();
        totalRating += rating;
      }

      final averageRating = totalRating / reviewCount;

      return {
        'rating': double.parse(averageRating.toStringAsFixed(1)), // 1 decimal
        'reviewCount': reviewCount,
      };
    } catch (e) {
      print('❌ Error getting rating stats: $e');
      return {'rating': 0.0, 'reviewCount': 0};
    }
  }

  /// Get all approved handymen
  Future<List<Map<String, dynamic>>> getAllHandymen() async {
    try {
      print('📋 Fetching all handymen from Firebase...');

      final snapshot = await _firestore
          .collection('handymen')
          .where('approved', isEqualTo: true)
          .where('suspended', isEqualTo: false)
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
          'profilePicture': data['profilePicture'] ?? '',
          'verified': data['approved'] ?? false,
          'experience': data['experience'] ?? '',
          'completedJobs': data['completedJobs'] ?? 0,
          'skills': data['skills'] ?? [],
          // 'skillPrices': data['skillPrices'] ?? {},
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
              // 'hourlyRate': _getAverageRate(data['skillPrices']),
              'image': data['profilePicture'] ?? '',
              'verified': data['approved'] ?? false,
              'experience': data['experience'] ?? '',
              'completedJobs': data['completedJobs'] ?? 0,
              'skills': data['skills'] ?? [],
              // 'skillPrices': data['skillPrices'] ?? {},
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
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      print('🔍 Fetching profile for user: $userId');

      final doc = await _firestore.collection('handymen').doc(userId).get();

      if (doc.exists) {
        final data = doc.data();
        print('✅ Handyman profile loaded');
        print('✅ Handyman profile data: $data');
        return data;
      } else {
        print('⚠️ No handyman profile found');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching handyman profile: $e');
      return null;
    }
  }

  /// Get handyman statistics
  Future<Map<String, dynamic>?> getHandymanStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      print('📊 Fetching stats for handyman: $userId');

      // Get handyman data
      final handymanDoc = await _firestore
          .collection('handymen')
          .doc(userId)
          .get();

      if (!handymanDoc.exists) {
        print('⚠️ Handyman not found');
        return null;
      }

      final handymanData = handymanDoc.data()!;

      // Get bookings count
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('handymanId', isEqualTo: userId)
          .get();

      final activeBookings = bookingsSnapshot.docs
          .where(
            (doc) =>
                doc.data()['status'] == 'confirmed' ||
                doc.data()['status'] == 'in_progress',
          )
          .length;

      final pendingRequests = bookingsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      final stats = {
        'activeBookings': activeBookings,
        'pendingRequests': pendingRequests,
        'rating': handymanData['rating'] ?? 0.0,
        'totalReviews': handymanData['reviews'] ?? 0,
        'completedJobs': handymanData['completedJobs'] ?? 0,
      };

      print('✅ Stats calculated: $stats');
      return stats;
    } catch (e) {
      print('❌ Error fetching stats: $e');
      return null;
    }
  }

  // ✅ HELPER METHOD: Parse amount from various formats
  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  // ✅ HELPER METHOD: Parse Timestamp
  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    return null;
  }

  // ✅ HELPER METHOD: Default stats (fallback)
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

  Stream<Map<String, dynamic>> streamHandymanStats() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(_getDefaultStats());
    }

    final handymanId = user.uid;

    return _firestore
        .collection('bookings')
        .where('handymanId', isEqualTo: handymanId)
        .snapshots()
        .asyncMap((bookingsSnapshot) async {
          print('🔄 Stats updated - ${bookingsSnapshot.docs.length} bookings');

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekAgo = today.subtract(Duration(days: 7));
          final monthAgo = today.subtract(Duration(days: 30));

          double todayEarnings = 0.0;
          double weeklyEarnings = 0.0;
          double monthlyEarnings = 0.0;
          int activeBookings = 0;
          int completedJobs = 0;
          int pendingRequests = 0;

          for (var doc in bookingsSnapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? '';
            final amount = _parseAmount(
              data['amount'] ?? data['estimatedPrice'],
            );

            switch (status) {
              case 'pending':
                pendingRequests++;
                activeBookings++;
                break;
              case 'confirmed':
              case 'in_progress':
                activeBookings++;
                break;
              case 'completed':
                completedJobs++;

                final completedAt = _parseTimestamp(data['completedAt']);

                if (completedAt != null && amount > 0) {
                  final completedDate = DateTime(
                    completedAt.year,
                    completedAt.month,
                    completedAt.day,
                  );

                  if (completedDate.isAtSameMomentAs(today) ||
                      completedDate.isAfter(today)) {
                    todayEarnings += amount;
                  }

                  if (completedDate.isAfter(weekAgo) ||
                      completedDate.isAtSameMomentAs(weekAgo)) {
                    weeklyEarnings += amount;
                  }

                  if (completedDate.isAfter(monthAgo) ||
                      completedDate.isAtSameMomentAs(monthAgo)) {
                    monthlyEarnings += amount;
                  }
                }
                break;
            }
          }

          // Fetch reviews
          final reviewsSnapshot = await _firestore
              .collection('reviews')
              .where('handymanId', isEqualTo: handymanId)
              .get();

          double averageRating = 0.0;
          int totalReviews = reviewsSnapshot.docs.length;

          if (totalReviews > 0) {
            double totalRating = 0;
            for (var doc in reviewsSnapshot.docs) {
              totalRating += (doc.data()['rating'] ?? 0).toDouble();
            }
            averageRating = double.parse(
              (totalRating / totalReviews).toStringAsFixed(1),
            );
          }

          return {
            'todayEarnings': todayEarnings,
            'weeklyEarnings': weeklyEarnings,
            'monthlyEarnings': monthlyEarnings,
            'activeBookings': activeBookings,
            'completedJobs': completedJobs,
            'pendingRequests': pendingRequests,
            'rating': averageRating,
            'totalReviews': totalReviews,
          };
        });
  }

  /// Update handyman profile
  Future<bool> updateHandymanProfile(Map<String, dynamic> updates) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No user logged in');
        return false;
      }

      print('📝 Updating handyman profile: $updates');

      await _firestore.collection('handymen').doc(userId).update(updates);

      print('✅ Handyman profile updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating handyman profile: $e');
      return false;
    }
  }

  // Update availability status

  Future<bool> updateAvailabilityStatus(bool isAvailable) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No user logged in');
        return false;
      }

      print('📝 Updating availability to: $isAvailable');

      await _firestore.collection('handymen').doc(userId).update({
        'isAvailable': isAvailable,
        'lastAvailabilityUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ Availability updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating availability: $e');
      return false;
    }
  }

  // Get availability status
  Future<Map<String, dynamic>> getAvailabilityStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {'isAvailable': false};

      final doc = await _firestore.collection('handymen').doc(userId).get();

      if (doc.exists) {
        final data = doc.data();
        return {
          'isAvailable': data?['isAvailable'] ?? false,
          'lastUpdate': data?['lastAvailabilityUpdate'],
        };
      }

      return {'isAvailable': false};
    } catch (e) {
      print('❌ Error getting availability: $e');
      return {'isAvailable': false};
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
