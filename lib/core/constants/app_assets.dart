/// App Assets
/// Centralized asset paths and resource management
///
/// Features:
/// - Image paths
/// - Icon paths
/// - SVG assets
/// - Lottie animations
/// - Font definitions
/// - Helper methods for dynamic assets

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

class AppAssets {
  AppAssets._(); // Private constructor

  // ==================== Images ====================

  // Logo & Branding
  static const String logoLight = 'assets/images/logo.png';
  static const String logoDark = 'assets/images/logo_dark.png';
  static const String logoIcon = 'assets/images/logo_icon.png';
  static const String appIcon = 'assets/images/app_icon.png';

  // Onboarding
  static const String onboarding1 = 'assets/images/onboarding_1.png';
  static const String onboarding2 = 'assets/images/onboarding_2.png';
  static const String onboarding3 = 'assets/images/onboarding_3.png';

  // Placeholders
  static const String userPlaceholder = 'assets/images/user_placeholder.png';
  static const String imagePlaceholder = 'assets/images/image_placeholder.png';
  static const String servicePlaceholder =
      'assets/images/service_placeholder.png';

  // Empty States
  static const String emptyBookings = 'assets/images/empty_bookings.png';
  static const String emptyMessages = 'assets/images/empty_messages.png';
  static const String emptySearch = 'assets/images/empty_search.png';
  static const String emptyFavorites = 'assets/images/empty_favorites.png';

  // Success/Error States
  static const String successImage = 'assets/images/success.png';
  static const String errorImage = 'assets/images/error.png';

  // Categories
  static const String categoryPlumbing =
      'assets/images/categories/plumbing.png';
  static const String categoryElectrical =
      'assets/images/categories/electrical.png';
  static const String categoryPainting =
      'assets/images/categories/painting.png';
  static const String categoryCarpentry =
      'assets/images/categories/carpentry.png';
  static const String categoryCleaning =
      'assets/images/categories/cleaning.png';
  static const String categoryGardening =
      'assets/images/categories/gardening.png';
  static const String categoryOther = 'assets/images/categories/other.png';

  // ==================== SVG Assets ====================

  static const String logoSvg = 'assets/svg/logo.svg';
  static const String plumbingSvg = 'assets/svg/plumbing.svg';
  static const String electricalSvg = 'assets/svg/electrical.svg';

  // ==================== Lottie Animations ====================

  static const String loadingAnimation = 'assets/lottie/loading.json';
  static const String successAnimation = 'assets/lottie/success.json';
  static const String errorAnimation = 'assets/lottie/error.json';

  // ==================== Font Awesome Icons ====================

  // Social Media
  static const googleIcon = FontAwesomeIcons.google;
  static const appleIcon = FontAwesomeIcons.apple;
  static const facebookIcon = FontAwesomeIcons.facebookF;

  // Payment
  static const visaIcon = FontAwesomeIcons.ccVisa;
  static const mastercardIcon = FontAwesomeIcons.ccMastercard;
  static const creditCardIcon = FontAwesomeIcons.creditCard;

  // Navigation
  static const homeIcon = FontAwesomeIcons.house;
  static const searchIcon = FontAwesomeIcons.magnifyingGlass;
  static const bookingIcon = FontAwesomeIcons.calendar;
  static const messageIcon = FontAwesomeIcons.message;
  static const profileIcon = FontAwesomeIcons.user;

  // Service
  static const toolboxIcon = FontAwesomeIcons.toolbox;
  static const hammerIcon = FontAwesomeIcons.hammer;
  static const wrenchIcon = FontAwesomeIcons.wrench;
  static const boltIcon = FontAwesomeIcons.bolt;
  static const dropletIcon = FontAwesomeIcons.droplet;

  // User Types
  static const clientIcon = FontAwesomeIcons.userTie;
  static const handymanIcon = FontAwesomeIcons.hardHat;

  // Actions
  static const heartIcon = FontAwesomeIcons.heart;
  static const heartSolidIcon = FontAwesomeIcons.solidHeart;
  static const starIcon = FontAwesomeIcons.star;
  static const starSolidIcon = FontAwesomeIcons.solidStar;

  // ==================== Helper Methods ====================

  /// Get category image by name
  static String getCategoryImage(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return categoryPlumbing;
      case 'electrical':
        return categoryElectrical;
      case 'painting':
        return categoryPainting;
      case 'carpentry':
        return categoryCarpentry;
      case 'cleaning':
        return categoryCleaning;
      case 'gardening':
        return categoryGardening;
      default:
        return categoryOther;
    }
  }

  /// Get category icon by name
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return dropletIcon;
      case 'electrical':
        return boltIcon;
      case 'painting':
        return FontAwesomeIcons.paintbrush;
      case 'carpentry':
        return hammerIcon;
      case 'cleaning':
        return FontAwesomeIcons.broom;
      case 'gardening':
        return FontAwesomeIcons.seedling;
      default:
        return toolboxIcon;
    }
  }

  /// Get payment icon by method
  static IconData getPaymentIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'visa':
        return visaIcon;
      case 'mastercard':
        return mastercardIcon;
      default:
        return creditCardIcon;
    }
  }

  /// Get social icon by platform
  static IconData getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'google':
        return googleIcon;
      case 'apple':
        return appleIcon;
      case 'facebook':
        return facebookIcon;
      default:
        return FontAwesomeIcons.share;
    }
  }
}
