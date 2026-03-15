import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// Guest profile page shown to unauthenticated users.
///
/// Encourages the guest to sign up or log in to access full features.
class GuestProfilePage extends StatelessWidget {
  const GuestProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Guest avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withValues(alpha: 0.2),
                      AppColors.secondaryColor.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.userLarge,
                    size: 40,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Welcome, Guest',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Sign in or create an account to access all features, book services, and manage your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondaryColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Sign in button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Create account button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Get.toNamed('/signup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    side: const BorderSide(color: AppColors.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Feature list
              _featureItem(
                context,
                icon: FontAwesomeIcons.calendarCheck,
                text: 'Book handyman services',
              ),
              const SizedBox(height: 12),
              _featureItem(
                context,
                icon: FontAwesomeIcons.comment,
                text: 'Chat directly with handymen',
              ),
              const SizedBox(height: 12),
              _featureItem(
                context,
                icon: FontAwesomeIcons.star,
                text: 'Leave reviews and ratings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: FaIcon(icon, size: 14, color: AppColors.primaryColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}
