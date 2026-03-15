import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ProfileCompletionIndicator extends StatelessWidget {
  final int completionPercentage;
  final bool showPercentage;

  const ProfileCompletionIndicator({
    super.key,
    required this.completionPercentage,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (completionPercentage < 30) return Colors.red;
      if (completionPercentage < 70) return Colors.orange;
      return Color(0xFF00C853);
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(context),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              if (showPercentage)
                Text(
                  '$completionPercentage%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: getColor(),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completionPercentage / 100,
              minHeight: 8,
              backgroundColor: AppColors.grey200Color(context),
              valueColor: AlwaysStoppedAnimation<Color>(getColor()),
            ),
          ),
          if (completionPercentage < 100) ...[
            SizedBox(height: 12),
            Text(
              _getCompletionMessage(completionPercentage),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getCompletionMessage(int percentage) {
    if (percentage < 30) {
      return 'Complete your profile to get more visibility!';
    } else if (percentage < 70) {
      return 'You\'re almost there! Add more details.';
    } else if (percentage < 100) {
      return 'Just a few more details to complete!';
    }
    return 'Profile completed! Great job!';
  }
}
