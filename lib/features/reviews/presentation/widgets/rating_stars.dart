import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// A row of star icons representing a rating.
///
/// Supports both display-only and interactive modes.
/// In interactive mode, tapping a star sets the rating to that value.
class RatingStars extends StatelessWidget {
  /// The current rating value (0.0 - 5.0).
  final double rating;

  /// The size of each star icon.
  final double size;

  /// Whether the stars are interactive (tappable).
  final bool interactive;

  /// Callback when a star is tapped (only used when [interactive] is true).
  final ValueChanged<double>? onRatingChanged;

  /// Color of the filled stars.
  final Color activeColor;

  /// Color of the empty star outlines.
  final Color inactiveColor;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.interactive = false,
    this.onRatingChanged,
    this.activeColor = AppColors.star,
    this.inactiveColor = AppColors.grey300,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final isFull = rating >= starValue;
        final isHalf = rating >= starValue - 0.5 && rating < starValue;

        IconData icon;
        Color color;

        if (isFull) {
          icon = Icons.star_rounded;
          color = activeColor;
        } else if (isHalf) {
          icon = Icons.star_half_rounded;
          color = activeColor;
        } else {
          icon = Icons.star_border_rounded;
          color = inactiveColor;
        }

        final star = Icon(icon, size: size, color: color);

        if (interactive) {
          return GestureDetector(
            onTap: () => onRatingChanged?.call(starValue.toDouble()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: star,
            ),
          );
        }

        return star;
      }),
    );
  }
}
