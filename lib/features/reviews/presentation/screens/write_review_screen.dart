import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/reviews/presentation/widgets/rating_stars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Write review screen.
///
/// Allows a client to rate a handyman and leave a written review
/// for a completed booking.
class WriteReviewScreen extends StatefulWidget {
  final String bookingId;
  final String handymanId;
  final String handymanName;

  const WriteReviewScreen({
    super.key,
    required this.bookingId,
    required this.handymanId,
    required this.handymanName,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.snackbar(
        'Error',
        'You must be logged in to leave a review.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    if (_rating < 1) {
      Get.snackbar(
        'Error',
        'Please select a rating.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('reviews').add({
        'bookingId': widget.bookingId,
        'clientId': uid,
        'handymanId': widget.handymanId,
        'rating': _rating,
        'comment': _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
        'images': <String>[],
        'isVerified': true,
        'helpfulCount': 0,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      Get.snackbar(
        'Thank you!',
        'Your review has been submitted.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (kDebugMode) debugPrint('WriteReview: submit error: $e');
      Get.snackbar(
        'Error',
        'Failed to submit review. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
          'Write Review',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Handyman info
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      AppColors.primaryColor.withValues(alpha: 0.2),
                  child: Text(
                    widget.handymanName.isNotEmpty
                        ? widget.handymanName[0].toUpperCase()
                        : 'H',
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.handymanName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How was your experience?',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Rating stars
          Center(
            child: RatingStars(
              rating: _rating,
              size: 44,
              interactive: true,
              onRatingChanged: (r) => setState(() => _rating = r),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _ratingLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Comment field
          Text(
            'Your Review (optional)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentController,
            maxLines: 5,
            maxLength: 500,
            style: TextStyle(
              color: AppColors.textPrimaryColor(context),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText:
                  'Share details of your experience with this handyman...',
              hintStyle: TextStyle(color: AppColors.textHintColor(context)),
              filled: true,
              fillColor: AppColors.inputFillColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.inputBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.inputBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 28),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String get _ratingLabel {
    if (_rating >= 5) return 'Excellent!';
    if (_rating >= 4) return 'Great';
    if (_rating >= 3) return 'Good';
    if (_rating >= 2) return 'Fair';
    return 'Poor';
  }
}
