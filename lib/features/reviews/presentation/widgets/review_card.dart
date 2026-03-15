import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/models/review_model.dart';
import 'package:fixilya_app/features/reviews/presentation/widgets/rating_stars.dart';
import 'package:flutter/material.dart';

/// A card that displays a single review with rating, comment, and timestamp.
class ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: rating + date
          Row(
            children: [
              RatingStars(rating: review.rating, size: 16),
              const SizedBox(width: 8),
              Text(
                review.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const Spacer(),
              if (review.isVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              Text(
                _formatDate(review.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
            ],
          ),

          // Comment
          if (review.hasComment) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimaryColor(context),
                height: 1.4,
              ),
            ),
          ],

          // Handyman response
          if (review.hasResponse) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.inputFillColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply,
                      size: 16, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Handyman Response',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.handymanResponse!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimaryColor(context),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Helpful count
          if (review.helpfulCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.thumb_up_outlined,
                    size: 14, color: AppColors.textSecondaryColor(context)),
                const SizedBox(width: 4),
                Text(
                  '${review.helpfulCount} found this helpful',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
