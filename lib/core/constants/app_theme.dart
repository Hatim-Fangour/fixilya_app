/// App Colors
/// Centralized color constants for the entire app
///
/// Features:
/// - Primary & secondary colors
/// - Gradient colors
/// - Semantic colors (success, error, warning, info)
/// - Neutral colors
/// - Background & surface colors
/// - Text colors
/// - Status colors
/// - Social media brand colors
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ==================== Primary Colors ====================

  static const Color primary = Color(0xFF536EFE);
  static const Color primaryLight = Color(0xFF8C9EFF);
  static const Color primaryDark = Color(0xFF3D5AFE);
  static const Color primaryVariant = Color(0xFF6200EA);

  // ==================== Secondary Colors ====================

  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryLight = Color(0xFFB47CFF);
  static const Color secondaryDark = Color(0xFF651FFF);

  // ==================== Gradient Colors ====================

  static const List<Color> primaryGradient = [
    Color(0xFF536EFE),
    Color(0xFF7C4DFF),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF7C4DFF),
    Color(0xFFB47CFF),
  ];

  static const List<Color> purpleGradient = [
    Color(0xFF6A11CB),
    Color(0xFF2575FC),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFFE66D),
  ];

  // ==================== Semantic Colors ====================

  static const Color success = Color(0xFF43A047);
  static const Color successLight = Color(0xFF76D275);
  static const Color successDark = Color(0xFF2E7D32);

  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);

  static const Color warning = Color(0xFFFB8C00);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFE65100);

  static const Color info = Color(0xFF1E88E5);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF1565C0);

  // ==================== Neutral Colors ====================

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

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

  // ==================== Background Colors ====================

  static const Color background = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static const Color card = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2C);

  // ==================== Text Colors ====================

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBDBDBD);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF808080);

  // ==================== Border Colors ====================

  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);

  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF424242);

  // ==================== Status Colors ====================

  static const Color pending = Color(0xFFFB8C00);
  static const Color confirmed = Color(0xFF1E88E5);
  static const Color inProgress = Color(0xFF7C4DFF);
  static const Color completed = Color(0xFF43A047);
  static const Color cancelled = Color(0xFFE53935);

  // ==================== Rating Colors ====================

  static const Color star = Color(0xFFFFB300);
  static const Color starFilled = Color(0xFFFFA000);
  static const Color starEmpty = Color(0xFFE0E0E0);

  // ==================== Social Media Brand Colors ====================

  static const Color google = Color(0xFF4285F4);
  static const Color facebook = Color(0xFF1877F2);
  static const Color apple = Color(0xFF000000);
  static const Color twitter = Color(0xFF1DA1F2);
  static const Color instagram = Color(0xFFE4405F);
  static const Color whatsapp = Color(0xFF25D366);

  // ==================== Category Colors ====================

  static const Color plumbing = Color(0xFF1E88E5);
  static const Color electrical = Color(0xFFFB8C00);
  static const Color painting = Color(0xFF7C4DFF);
  static const Color carpentry = Color(0xFF6D4C41);
  static const Color cleaning = Color(0xFF43A047);
  static const Color gardening = Color(0xFF66BB6A);
  static const Color appliance = Color(0xFFE53935);
  static const Color hvac = Color(0xFF42A5F5);
  static const Color locksmith = Color(0xFF8D6E63);
  static const Color other = Color(0xFF9E9E9E);

  // ==================== Opacity Variants ====================

  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  static Color primary10 = primary.withValues(alpha: 0.1);
  static Color primary20 = primary.withValues(alpha: 0.2);
  static Color primary30 = primary.withValues(alpha: 0.3);
  static Color primary50 = primary.withValues(alpha: 0.5);
  static Color primary70 = primary.withValues(alpha: 0.7);

  // ==================== Overlay Colors ====================

  static const Color overlay = Color(0x66000000);
  static const Color overlayLight = Color(0x33000000);
  static const Color overlayDark = Color(0x99000000);

  // ==================== Shimmer Colors ====================

  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // ==================== Shadow Colors ====================

  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // ==================== Badge Colors ====================

  static const Color badgeRed = Color(0xFFE53935);
  static const Color badgeGreen = Color(0xFF43A047);
  static const Color badgeBlue = Color(0xFF1E88E5);
  static const Color badgeOrange = Color(0xFFFB8C00);
  static const Color badgePurple = Color(0xFF7C4DFF);

  // ==================== Chart Colors ====================

  static const List<Color> chartColors = [
    Color(0xFF536EFE),
    Color(0xFF7C4DFF),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFFFFB300),
    Color(0xFF66BB6A),
  ];

  // ==================== Helper Methods ====================

  /// Get color by status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return pending;
      case 'confirmed':
        return confirmed;
      case 'in_progress':
      case 'inprogress':
        return inProgress;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      default:
        return grey500;
    }
  }

  /// Get category color
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return plumbing;
      case 'electrical':
        return electrical;
      case 'painting':
        return painting;
      case 'carpentry':
        return carpentry;
      case 'cleaning':
        return cleaning;
      case 'gardening':
        return gardening;
      case 'appliance':
        return appliance;
      case 'hvac':
        return hvac;
      case 'locksmith':
        return locksmith;
      default:
        return other;
    }
  }

  /// Get linear gradient
  static LinearGradient getLinearGradient({
    List<Color>? colors,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      colors: colors ?? primaryGradient,
      begin: begin,
      end: end,
    );
  }

  /// Get radial gradient
  static RadialGradient getRadialGradient({
    List<Color>? colors,
    Alignment center = Alignment.center,
  }) {
    return RadialGradient(colors: colors ?? primaryGradient, center: center);
  }

  static Color? inputFillColor(BuildContext buildContext) {
    return null;
  }
}
