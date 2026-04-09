import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ GET REVIEWS FOR A HANDYMAN
  Future<List<Map<String, dynamic>>> getHandymanReviews(
    String handymanId, {
    int? limit,
  }) async {
    try {
      if (kDebugMode) debugPrint('📋 Fetching reviews for handyman: $handymanId');

      Query query = _firestore
          .collection('reviews')
          .where('handymanId', isEqualTo: handymanId)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      List<Map<String, dynamic>> reviews = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Fetch client details
        String clientName = 'Anonymous';
        try {
          final clientDoc = await _firestore
              .collection('clients')
              .doc(data['clientId'])
              .get();

          if (clientDoc.exists) {
            clientName = clientDoc.data()?['fullName'] ?? 'Anonymous';
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error fetching client name: $e');
        }

        reviews.add({
          'id': doc.id,
          'clientId': data['clientId'] ?? '',
          'clientName': clientName,
          'rating': data['rating'] ?? 0,
          'comment': data['comment'] ?? '',
          'createdAt': data['createdAt'],
          'bookingId': data['bookingId'] ?? '',
        });
      }

      if (kDebugMode) debugPrint('✅ Loaded ${reviews.length} reviews');
      return reviews;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting reviews: $e');
      return [];
    }
  }

  /// ✅ GET REVIEW STATS
  Future<Map<String, dynamic>> getReviewStats(String handymanId) async {
    try {
      final reviews = await getHandymanReviews(handymanId);

      if (reviews.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
        };
      }

      // Calculate average rating
      double totalRating = 0;
      Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (var review in reviews) {
        int rating = review['rating'];
        totalRating += rating;
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }

      double averageRating = totalRating / reviews.length;

      return {
        'totalReviews': reviews.length,
        'averageRating': averageRating,
        'ratingDistribution': distribution,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting review stats: $e');
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      };
    }
  }

  /// ✅ FORMAT TIME AGO
  String formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Recently';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recently';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        int years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        int months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }
}
