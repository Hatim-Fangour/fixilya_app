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

  // ─── Microservice URLs ─────────────────────────────────────────────────
  // Pass via --dart-define for each environment:
  //   flutter run --dart-define=AUTH_SERVICE_URL=https://auth.fixilya.ma/api
  // Defaults target the Android emulator loopback for local dev.
  static const String authServiceUrl = String.fromEnvironment(
    'AUTH_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:3001/api',
  );
  static const String userServiceUrl = String.fromEnvironment(
    'USER_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:3002/api',
  );
  static const String bookingServiceUrl = String.fromEnvironment(
    'BOOKING_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:3003',
  );
  static const String notificationServiceUrl = String.fromEnvironment(
    'NOTIFICATION_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:3005',
  );
  static const String callServiceUrl = String.fromEnvironment(
    'CALL_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:3007/api',
  );
  // ─────────────────────────────────────────────────────────────────────────

  // ─── Agora RTC ───────────────────────────────────────────────────────────
  /// Agora App ID — get from console.agora.io
  /// In production, load from --dart-define=AGORA_APP_ID=xxx
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '100dfbc4a86d4affbe7eaabe0808a6d8', // dev fallback only
  );

  /// Backend endpoint to obtain per-call Agora RTC tokens securely.
  /// The backend uses the Agora RTC Token Builder library.
  static const String agoraTokenEndpoint = '/agora/token';
  // ─────────────────────────────────────────────────────────────────────────

  // ─── Cloudinary ──────────────────────────────────────────────────────
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dbz3wtlbj',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'fixilya_app',
  );
  // ─────────────────────────────────────────────────────────────────────────

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
  static const String officialEmail = 'fixilya.sarl@gmail.com';
  static const String supportEmail = 'fixilya.sarl@gmail.com';
  static const String supportPhone = '+212619955898';

  // Social Media
  static const String facebookUrl = 'https://facebook.com/fixilya';
  static const String twitterUrl = 'https://twitter.com/fixilya';
  static const String instagramUrl = 'https://instagram.com/fixilya';

  static const String showCaseWebSite = 'https://fixilya-sarl.vercel.app/';
}
