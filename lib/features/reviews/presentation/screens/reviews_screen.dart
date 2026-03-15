import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/models/review_model.dart';
import 'package:fixilya_app/features/reviews/presentation/widgets/review_card.dart';
import 'package:flutter/material.dart';

/// Reviews screen.
///
/// Displays reviews for a handyman (when viewed by a client) or
/// reviews received (when viewed by the handyman themselves).
class ReviewsScreen extends StatelessWidget {
  /// The handyman whose reviews are displayed.
  final String handymanId;
  final String handymanName;

  const ReviewsScreen({
    super.key,
    required this.handymanId,
    required this.handymanName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimaryColor(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reviews for $handymanName',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('handymanId', isEqualTo: handymanId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load reviews',
                    style: TextStyle(
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          // Calculate summary stats
          final reviews = docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ReviewModel.fromJson(data);
          }).toList();

          final avgRating =
              reviews.fold(0.0, (sum, r) => sum + r.rating) / reviews.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary header
              _buildSummaryCard(context, avgRating, reviews.length),
              const SizedBox(height: 16),

              // Reviews list
              ...reviews.map((review) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ReviewCard(review: review),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    double avgRating,
    int totalReviews,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradientThemed(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          // Average rating
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avgRating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.star,
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalReviews reviews',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Rating distribution
          Expanded(
            child: FutureBuilder<Map<int, int>>(
              future: _getRatingDistribution(),
              builder: (context, snap) {
                final dist = snap.data ?? {};
                return Column(
                  children: List.generate(5, (i) {
                    final stars = 5 - i;
                    final count = dist[stars] ?? 0;
                    final pct = totalReviews > 0 ? count / totalReviews : 0.0;
                    return _ratingBar(context, stars, pct, count);
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(
    BuildContext context,
    int stars,
    double percentage,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star_rounded, size: 12, color: AppColors.star),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.grey200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.star),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<int, int>> _getRatingDistribution() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('handymanId', isEqualTo: handymanId)
          .get();

      final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final doc in snapshot.docs) {
        final rating = ((doc.data()['rating'] ?? 0) as num).round();
        final clamped = rating.clamp(1, 5);
        dist[clamped] = (dist[clamped] ?? 0) + 1;
      }
      return dist;
    } catch (_) {
      return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined,
              size: 64, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to leave a review!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
