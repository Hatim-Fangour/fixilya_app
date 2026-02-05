class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'Fixilya';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // API Configuration
  static const String apiBaseUrl = 'https://api.fixilya.ma';
  static const String apiVersion = 'v1';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Firebase Configuration
  static const String firebaseProjectId = 'fixilya-app';

  // Storage Configuration
  static const String storageUrl = 'https://storage.fixilya.ma';
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB

  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enablePerformanceMonitoring = true;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache
  static const Duration cacheExpiration = Duration(hours: 24);

  // Location
  static const double defaultLatitude = 33.5731;
  static const double defaultLongitude = -7.5898; // Casablanca
  static const double searchRadius = 50.0; // km

  // Booking
  static const int maxAdvanceBookingDays = 90;
  static const int minAdvanceBookingHours = 2;
  static const Duration bookingCancellationWindow = Duration(hours: 24);

  // Rating
  static const double minRating = 1.0;
  static const double maxRating = 5.0;
  static const int minReviewLength = 10;
  static const int maxReviewLength = 500;

  // Contact
  static const String supportEmail = 'support@fixilya.ma';
  static const String supportPhone = '+212 5 22 XX XX XX';

  // Social Media
  static const String facebookUrl = 'https://facebook.com/fixilya';
  static const String twitterUrl = 'https://twitter.com/fixilya';
  static const String instagramUrl = 'https://instagram.com/fixilya';
}
