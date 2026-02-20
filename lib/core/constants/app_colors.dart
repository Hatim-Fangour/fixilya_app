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
  static const Color accentOrange = Color.fromRGBO(255, 149, 0, 1);
  static const Color hardOrange = Color(0xFFFF6F00);

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
        : const Color(0xFFFFFFFF); // Light card
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

  static Color textDisabledColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6B6B6B)
        : const Color(0xFFBDBDBD);
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

  static Color iconActiveColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF212121);
  }

  // Input Field Colors
  static Color inputFillColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF5F5F5);
  }

  static Color inputBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE0E0E0);
  }

  // Shadow Colors (theme-aware)
  static Color shadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.1);
  }

  static Color shadowLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.05);
  }

  static Color shadowMediumColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.1);
  }

  static Color shadowDarkColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.2);
  }

  // ==================== Glassmorphic Colors (Theme-Aware) ====================
  static Color glassWhiteColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.25);
  }

  static Color glassWhiteBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.3);
  }

  static Color glassBlackColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.3);
  }

  // ==================== Status Colors (Theme-Aware) ====================
  static Color successColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF66BB6A) // Lighter green for dark mode
        : const Color(0xFF4CAF50);
  }

  static Color successLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
        : const Color(0xFFE8F5E9);
  }

  static Color warningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFB74D) // Lighter orange for dark mode
        : const Color(0xFFFF6F00);
  }

  static Color warningLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE65100).withValues(alpha: 0.3)
        : const Color(0xFFFFF3E0);
  }

  static Color errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEF5350).withValues(
            alpha: 0.6,
          ) // Lighter red for dark mode
        : const Color(0xFFF44336);
  }

  static Color errorLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB71C1C).withValues(alpha: 0.3)
        : const Color(0xFFFFEBEE);
  }

  static Color infoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF42A5F5) // Lighter blue for dark mode
        : const Color(0xFF2196F3);
  }

  static Color mainButtonColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryColor.withValues(alpha: 0.3)
        : primaryColor;
  }

  static Color infoLightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0D47A1).withValues(alpha: 0.3)
        : const Color(0xFFE3F2FD);
  }

  // ==================== Grey Scale (Theme-Aware) ====================
  static Color grey50Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFFAFAFA);
  }

  static Color grey100Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFF5F5F5);
  }

  static Color grey200Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFEEEEEE);
  }

  static Color grey300Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF4A4A4A)
        : const Color(0xFFE0E0E0);
  }

  static Color grey400Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6B6B6B)
        : const Color(0xFFBDBDBD);
  }

  static Color grey500Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8B8B8B)
        : const Color(0xFF9E9E9E);
  }

  static Color grey600Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF757575);
  }

  static Color grey700Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFC0C0C0)
        : const Color(0xFF616161);
  }

  static Color grey800Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD0D0D0)
        : const Color(0xFF424242);
  }

  static Color grey900Color(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF212121);
  }

  static Color pagesAppBar(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceColor(context)
        : primaryColor;
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
  static const Color red = Colors.red;

  // ==================== HandyMan Colors ====================
  static const Color cityColor = Colors.red;
  static const Color reviews = Color(0xFFFFB800);
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

  static LinearGradient subtleHeaderGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color.fromARGB(255, 6, 9, 25),
              const Color.fromARGB(255, 14, 24, 73),
              const Color.fromARGB(255, 17, 34, 108),
            ]
          : [primaryColor, secondaryColor, accentColor],
    );
  }

  static LinearGradient appHeaderGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
      colors: isDark
          ? [
              const Color.fromARGB(255, 6, 9, 25),
              const Color.fromARGB(255, 17, 34, 108),
            ]
          : [primaryColor, secondaryColor],
    );
  }

  // Theme-aware card gradient
  static LinearGradient cardGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF1E1E1E), const Color(0xFF252525)]
          : [const Color(0xFFFFFFFF), const Color(0xFFFAFAFA)],
    );
  }

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [
      Color.fromARGB(255, 29, 201, 192),
      Color.fromARGB(255, 125, 221, 216),
    ],
    stops: [0.5, 1.0],
  );

  // ==================== Status Colors (Static - Legacy) ====================
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

  // ==================== Grey Scale (Static - Legacy) ====================
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

  // ==================== Shadow Colors (Static - Legacy) ====================
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);

  // ==================== Glassmorphic Colors (Static - Legacy) ====================
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

  // ==================== Stat Card Gradients (Theme-Aware) ====================
  static List<Color> ratingGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color(0xFFFFB800).withValues(alpha: 0.2),
            const Color(0xFFFFB800).withValues(alpha: 0.1),
          ]
        : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)];
  }

  static List<Color> jobsGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color(0xFF2196F3).withValues(alpha: 0.2),
            const Color(0xFF2196F3).withValues(alpha: 0.1),
          ]
        : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)];
  }

  static List<Color> experienceGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color(0xFFFF6F00).withValues(alpha: 0.2),
            const Color(0xFFFF6F00).withValues(alpha: 0.1),
          ]
        : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)];
  }

  static List<Color> successGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color(0xFF4CAF50).withValues(alpha: 0.2),
            const Color(0xFF4CAF50).withValues(alpha: 0.1),
          ]
        : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];
  }

  static List<Color> errorGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color(0xFFF44336).withValues(alpha: 0.2),
            const Color(0xFFF44336).withValues(alpha: 0.1),
          ]
        : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)];
  }

  static List<Color> blueStateCardGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color.fromARGB(255, 1, 0, 74),
            const Color.fromARGB(255, 6, 0, 96).withValues(alpha: 0.6),
          ]
        : [Color(0xFFE3F2FD), Color(0xFFBBDEFB)];
  }

  static List<Color> reviewsCardGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color.fromARGB(98, 175, 101, 5),
            grey900.withValues(alpha: 0.5),
          ]
        : [Color(0xFFFFF3E0), Color(0xFFFFE0B2)];
  }

  static List<Color> jobsDoneCardGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color.fromARGB(110, 3, 134, 160),
            grey900.withValues(alpha: 0.5),
          ]
        : [Color(0xFFE3F2FD), Color(0xFFBBDEFB)];
  }

  static List<Color> experiencesCardGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color.fromARGB(141, 255, 145, 0),
            grey900.withValues(alpha: 0.5),
          ]
        : [Color(0xFFFFF3E0), Color(0xFFFFE0B2)];
  }

  static List<Color> handymanLocationCardThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [Color.fromARGB(153, 46, 0, 0), Color.fromARGB(255, 40, 0, 0)]
        : [Color(0xFFFFEBEE), Color(0xFFFFCDD2)];
  }

  static List<Color> handymanPhoneCardThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [Color.fromARGB(153, 0, 46, 4), Color.fromARGB(255, 0, 40, 2)]
        : [Color(0xFFE8F5E9), Color(0xFFC8E6C9)];
  }

  static List<Color> orangeStateCardGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [grey900, grey900.withValues(alpha: 0.6)]
        : [Color(0xFFFFF3E0), Color(0xFFFFE0B2)];
  }

  static List<Color> roseStateCardGradientThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [grey900, grey900.withValues(alpha: 0.6)]
        : [Color(0xFFFCE4EC), Color(0xFFF8BBD0)];
  }

  static List<Color> backgroundCardThemed(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            const Color.fromARGB(255, 6, 9, 25),
            const Color.fromARGB(255, 14, 24, 73),
            const Color.fromARGB(255, 17, 34, 108),
          ]
        : [
            AppColors.primaryColor,
            AppColors.secondaryColor,
            AppColors.accentColor,
          ];
  }

  // ==================== Static Gradients (Legacy) ====================
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

  //  static const List<Color> reviewsCard = [
  //     Color(0xFFFF6B6B),
  //     Color(0xFFEE5A6F),
  //   ];

  //  static const List<Color> jobsDoneCard = [
  //     Color(0xFFFF6B6B),
  //     Color(0xFFEE5A6F),
  //   ];

  //  static const List<Color> experiencesCard = [
  //     Color(0xFFFF6B6B),
  //     Color(0xFFEE5A6F),
  //   ];

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

  // ==================== Helper Methods ====================

  // Check if dark mode
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Get opposite theme color (useful for contrast)
  static Color oppositeThemeColor(BuildContext context) {
    return isDarkMode(context) ? white : black;
  }

  // Adaptive color based on theme
  static Color adaptiveColor(
    BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return isDarkMode(context) ? darkColor : lightColor;
  }
}
