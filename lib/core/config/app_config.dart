import 'dart:io';

class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'Fixilya';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // API Configuration
  static const String apiBaseUrl = 'https://api.fixilya.pro';
  static const String apiVersion = 'v1';
  static const Duration apiTimeout = Duration(seconds: 30);

  // ─── Local Dev Base IP ─────────────────────────────────────────────────
  // 10.0.2.2  = Android emulator loopback to PC
  // YOUR_IP   = Physical device on same WiFi (change this to your PC's IP)
  static const String _emulatorHost = '10.0.2.2';
  static const String _physicalDeviceHost = '192.168.1.10'; // ← YOUR PC IP HERE

  /// Returns the correct host depending on whether we're on emulator or real device.
  /// Can always be overridden via --dart-define.
  static String get _localHost {
    return _isEmulator ? _emulatorHost : _physicalDeviceHost;
  }

  /// Detects Android emulator. Pass --dart-define=IS_EMULATOR=true when running
  /// on an emulator that needs to reach a local backend via 10.0.2.2.
  static bool get _isEmulator {
    try {
      return const bool.fromEnvironment('IS_EMULATOR', defaultValue: false);
    } catch (_) {
      return false;
    }
  }

  // ─── Microservice URLs ─────────────────────────────────────────────────
  // Production (VPS + nginx gateway) — single base URL for all services:
  //   flutter run --dart-define=API_GATEWAY_URL=https://api.fixilya.pro/api
  //
  // Local dev (emulator hitting PC):
  //   flutter run --dart-define=IS_EMULATOR=true
  //
  // Or override a single service:
  //   flutter run --dart-define=AUTH_SERVICE_URL=https://api.fixilya.pro/api

  static const String _gateway = String.fromEnvironment(
    'API_GATEWAY_URL',
    defaultValue: '',
  );
  static bool get _useGateway => _gateway.isNotEmpty;

  static String get authServiceUrl =>
      const String.fromEnvironment('AUTH_SERVICE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('AUTH_SERVICE_URL')
          : _useGateway ? _gateway : 'http://$_localHost:3001/api';

  static String get userServiceUrl =>
      const String.fromEnvironment('USER_SERVICE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('USER_SERVICE_URL')
          : _useGateway ? _gateway : 'http://$_localHost:3002/api';

  static String get bookingServiceUrl =>
      const String.fromEnvironment('BOOKING_SERVICE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('BOOKING_SERVICE_URL')
          : _useGateway ? _gateway : 'http://$_localHost:3003';

  static String get notificationServiceUrl =>
      const String.fromEnvironment('NOTIFICATION_SERVICE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('NOTIFICATION_SERVICE_URL')
          : _useGateway ? _gateway : 'http://$_localHost:3005';

  static String get callServiceUrl =>
      const String.fromEnvironment('CALL_SERVICE_URL', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('CALL_SERVICE_URL')
          : _useGateway ? _gateway : 'http://$_localHost:3007/api';
  // ─────────────────────────────────────────────────────────────────────────

  // ─── Agora RTC ───────────────────────────────────────────────────────────
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '100dfbc4a86d4affbe7eaabe0808a6d8',
  );
  static const String agoraTokenEndpoint = '/agora/token';
  // ─────────────────────────────────────────────────────────────────────────

  // ─── Cloudinary ──────────────────────────────────────────────────────────
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
