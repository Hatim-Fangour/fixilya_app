// Core Constants - App Colors
// Luxury Purple Theme Color Palette with Dark Mode Support

import 'package:flutter/material.dart';

class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ==================== Primary Colors (Same for both themes) ====================
  static const Color primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const Color primaryLight = Color.fromRGBO(110, 133, 255, 1);
  static const Color primaryDark = Color.fromRGBO(60, 85, 220, 1);
  static const Color secondaryColor = Color.fromRGBO(123, 144, 250, 1);
  static const Color accentColor = Color.fromRGBO(147, 167, 255, 1);

  // ==================== Theme-Aware Colors ====================

  // Background Colors
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F1115) // Dark background
        : const Color(0xFFFAFAFA); // Light background
  }

  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E) // Dark card
        : Colors.white; // Light card
  }

  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFFFFFFF);
  }

  // Text Colors
  static Color textPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE0E0E0) // Light text on dark
        : const Color(0xFF212121); // Dark text on light
  }

  static Color textSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF757575);
  }

  static Color textHintColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF808080)
        : const Color(0xFF9E9E9E);
  }

  // Border & Divider Colors
  static Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE0E0E0);
  }

  static Color dividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE0E0E0);
  }

  // Icon Colors
  static Color iconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF757575);
  }

  // Input Field Colors
  static Color inputFillColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF5F5F5);
  }

  // Shadow Colors (theme-aware)
  static Color shadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.1);
  }

  // ==================== Static Colors (Legacy - for backward compatibility) ====================
  static const Color greyBackgroundColor = Color(0xffebecee);
  static const Color unselectedNavBarColor = Colors.black87;
  static const Color amber = Colors.amber;
  static const Color transparent = Colors.transparent;
  static const Color purple = Colors.purple;
  static const Color orange = Colors.orange;
  static const Color green = Colors.green;
  static const Color blue = Colors.blue;

  // ==================== HandyMan Colors ====================
  static const Color cityColor = Colors.red;
  static const Color jobs = Colors.blue;
  static const Color experience = Colors.orange;

  // ==================== Gradient Colors ====================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor, accentColor],
  );

  static const LinearGradient primaryGradientHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryColor, secondaryColor],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromRGBO(83, 110, 254, 0.1),
      Color.fromRGBO(110, 133, 255, 0.05),
    ],
  );

  // Theme-aware subtle gradient
  static LinearGradient subtleGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              primaryColor.withValues(alpha: 0.15),
              secondaryColor.withValues(alpha: 0.08),
            ]
          : [
              primaryColor.withValues(alpha: 0.1),
              secondaryColor.withValues(alpha: 0.05),
            ],
    );
  }

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [
      Color.fromARGB(255, 29, 201, 192),
      Color.fromARGB(255, 125, 221, 216),
    ],
    stops: [0.5, 1.0],
  );

  // ==================== Status Colors ====================
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF6F00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ==================== Neutral Colors ====================
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);

  // ==================== Text Colors (Static) ====================
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ==================== Grey Scale ====================
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // ==================== Blue Scale ====================
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue200 = Color(0xFF90CAF9);

  // ==================== Indigo Scale ====================
  static const Color indigo50 = Color(0xFFE8EAF6);

  // ==================== Rating/Star Color ====================
  static const Color star = Color(0xFFFFB800);
  static const Color starLight = Color(0xFFFFF3E0);

  // ==================== Shadow Colors ====================
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);

  // ==================== Glassmorphic Colors ====================
  static Color glassWhite = Colors.white.withValues(alpha: 0.25);
  static Color glassWhiteBorder = Colors.white.withValues(alpha: 0.3);
  static Color glassBlack = Colors.black.withValues(alpha: 0.3);

  // ==================== Category/Feature Colors ====================
  static const Color electricity = Color(0xFFFFB800);
  static const Color carpentry = Color(0xFF8B4513);
  static const Color plumbing = Color(0xFF2196F3);
  static const Color painting = Color(0xFF9C27B0);
  static const Color cleaning = Color(0xFF4CAF50);
  static const Color acRepair = Color(0xFF00BCD4);

  // ==================== Opacity Variations ====================
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  // ==================== Stat Card Gradients ====================
  static const List<Color> ratingGradient = [
    Color(0xFFFFF3E0),
    Color(0xFFFFE0B2),
  ];

  static const List<Color> jobsGradient = [
    Color(0xFFE3F2FD),
    Color(0xFFBBDEFB),
  ];

  static const List<Color> experienceGradient = [
    Color(0xFFFFF3E0),
    Color(0xFFFFE0B2),
  ];

  static const List<Color> successGradient = [
    Color(0xFFE8F5E9),
    Color(0xFFC8E6C9),
  ];

  static const List<Color> errorGradient = [
    Color(0xFFFFEBEE),
    Color(0xFFFFCDD2),
  ];

  static const List<Color> logoutButtonGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFEE5A6F),
  ];

  // ==================== Dark Mode Specific Colors ====================

  // Dark backgrounds
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF1A1A1A);

  // Dark text
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // Dark borders
  static const Color darkBorder = Color(0xFF3A3A3A);
  static const Color darkDivider = Color(0xFF2A2A2A);
}
