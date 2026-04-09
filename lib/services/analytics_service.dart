/// Services - Analytics Service
/// Complete Firebase Analytics and Event Tracking
///
/// Features:
/// - User tracking
/// - Event logging
/// - Screen tracking
/// - E-commerce events
/// - Custom events
/// - User properties
/// - Conversion tracking
library;

import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // ==================== User Tracking ====================

  /// Set user ID
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  /// Set multiple user properties
  Future<void> setUserProperties(Map<String, String> properties) async {
    for (final entry in properties.entries) {
      await setUserProperty(name: entry.key, value: entry.value);
    }
  }

  /// Set user type
  Future<void> setUserType(String userType) async {
    await setUserProperty(name: 'user_type', value: userType);
  }

  /// Set user tier/plan
  Future<void> setUserTier(String tier) async {
    await setUserProperty(name: 'user_tier', value: tier);
  }

  // ==================== Event Logging ====================

  /// Log custom event
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters?.map(
        (key, value) => MapEntry(key, value as Object),
      ),
    );
  }

  // ==================== Authentication Events ====================

  /// Log sign up
  Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// Log login
  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Log logout
  Future<void> logLogout() async {
    await logEvent(name: 'logout');
  }

  // ==================== Screen Tracking ====================

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  /// Log screen views with standard names
  Future<void> logHomeScreen() async {
    await logScreenView(screenName: 'Home');
  }

  Future<void> logProfileScreen() async {
    await logScreenView(screenName: 'Profile');
  }

  Future<void> logSearchScreen() async {
    await logScreenView(screenName: 'Search');
  }

  Future<void> logBookingScreen() async {
    await logScreenView(screenName: 'Booking');
  }

  Future<void> logChatScreen() async {
    await logScreenView(screenName: 'Chat');
  }

  // ==================== User Engagement ====================

  /// Log app open
  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  /// Log session start
  Future<void> logSessionStart() async {
    await logEvent(
      name: 'session_start',
      parameters: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Log session end
  Future<void> logSessionEnd({required int durationSeconds}) async {
    await logEvent(
      name: 'session_end',
      parameters: {
        'duration_seconds': durationSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== Search Events ====================

  /// Log search
  Future<void> logSearch(String searchTerm) async {
    await _analytics.logSearch(searchTerm: searchTerm);
  }

  /// Log search with category
  Future<void> logSearchWithCategory({
    required String searchTerm,
    required String category,
  }) async {
    await _analytics.logSearch(
      searchTerm: searchTerm,
      parameters: {'category': category},
    );
  }

  /// Log handyman search
  Future<void> logHandymanSearch({
    required String searchTerm,
    String? category,
    String? city,
  }) async {
    await logEvent(
      name: 'handyman_search',
      parameters: {
        'search_term': searchTerm,
        if (category != null) 'category': category,
        if (city != null) 'city': city,
      },
    );
  }

  // ==================== Handyman Events ====================

  /// Log handyman view
  Future<void> logHandymanView({
    required String handymanId,
    required String category,
    double? rating,
  }) async {
    await logEvent(
      name: 'handyman_view',
      parameters: {
        'handyman_id': handymanId,
        'category': category,
        if (rating != null) 'rating': rating,
      },
    );
  }

  /// Log handyman profile view
  Future<void> logHandymanProfileView(String handymanId) async {
    await logEvent(
      name: 'handyman_profile_view',
      parameters: {'handyman_id': handymanId},
    );
  }

  /// Log handyman call
  Future<void> logHandymanCall(String handymanId) async {
    await logEvent(
      name: 'handyman_call',
      parameters: {'handyman_id': handymanId},
    );
  }

  /// Log handyman message
  Future<void> logHandymanMessage(String handymanId) async {
    await logEvent(
      name: 'handyman_message',
      parameters: {'handyman_id': handymanId},
    );
  }

  /// Log handyman favorite
  Future<void> logHandymanFavorite({
    required String handymanId,
    required bool isFavorited,
  }) async {
    await logEvent(
      name: isFavorited ? 'handyman_favorited' : 'handyman_unfavorited',
      parameters: {'handyman_id': handymanId},
    );
  }

  // ==================== Booking Events ====================

  /// Log booking started
  Future<void> logBookingStarted({
    required String handymanId,
    required String serviceType,
  }) async {
    await logEvent(
      name: 'booking_started',
      parameters: {'handyman_id': handymanId, 'service_type': serviceType},
    );
  }

  /// Log booking completed
  Future<void> logBookingCompleted({
    required String bookingId,
    required String handymanId,
    required String serviceType,
    required double amount,
  }) async {
    await logEvent(
      name: 'booking_completed',
      parameters: {
        'booking_id': bookingId,
        'handyman_id': handymanId,
        'service_type': serviceType,
        'amount': amount,
      },
    );
  }

  /// Log booking confirmed
  Future<void> logBookingConfirmed({
    required String bookingId,
    required double amount,
  }) async {
    await logEvent(
      name: 'booking_confirmed',
      parameters: {'booking_id': bookingId, 'amount': amount},
    );
  }

  /// Log booking cancelled
  Future<void> logBookingCancelled({
    required String bookingId,
    required String reason,
    required String cancelledBy,
  }) async {
    await logEvent(
      name: 'booking_cancelled',
      parameters: {
        'booking_id': bookingId,
        'reason': reason,
        'cancelled_by': cancelledBy,
      },
    );
  }

  /// Log booking rescheduled
  Future<void> logBookingRescheduled(String bookingId) async {
    await logEvent(
      name: 'booking_rescheduled',
      parameters: {'booking_id': bookingId},
    );
  }

  // ==================== Review Events ====================

  /// Log review submitted
  Future<void> logReviewSubmitted({
    required String handymanId,
    required String bookingId,
    required double rating,
    bool hasComment = false,
  }) async {
    await logEvent(
      name: 'review_submitted',
      parameters: {
        'handyman_id': handymanId,
        'booking_id': bookingId,
        'rating': rating,
        'has_comment': hasComment,
      },
    );
  }

  /// Log review helpful
  Future<void> logReviewHelpful({
    required String reviewId,
    required bool isHelpful,
  }) async {
    await logEvent(
      name: isHelpful ? 'review_marked_helpful' : 'review_marked_not_helpful',
      parameters: {'review_id': reviewId},
    );
  }

  // ==================== Payment Events ====================

  /// Log payment initiated
  Future<void> logPaymentInitiated({
    required double amount,
    required String paymentMethod,
    String? bookingId,
  }) async {
    await logEvent(
      name: 'payment_initiated',
      parameters: {
        'amount': amount,
        'payment_method': paymentMethod,
        if (bookingId != null) 'booking_id': bookingId,
      },
    );
  }

  /// Log payment success
  Future<void> logPaymentSuccess({
    required String transactionId,
    required double amount,
    required String currency,
    String? paymentMethod,
  }) async {
    await _analytics.logPurchase(
      value: amount,
      currency: currency,
      parameters: {
        'transaction_id': transactionId,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
    );
  }

  /// Log payment failure
  Future<void> logPaymentFailure({
    required String reason,
    required double amount,
    String? paymentMethod,
  }) async {
    await logEvent(
      name: 'payment_failed',
      parameters: {
        'reason': reason,
        'amount': amount,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
    );
  }

  /// Log refund
  Future<void> logRefund({
    required String transactionId,
    required double amount,
    required String reason,
  }) async {
    await logEvent(
      name: 'refund_issued',
      parameters: {
        'transaction_id': transactionId,
        'amount': amount,
        'reason': reason,
      },
    );
  }

  // ==================== Share Events ====================

  /// Log share
  Future<void> logShare({
    required String contentType,
    required String contentId,
    String? method,
  }) async {
    await _analytics.logShare(
      contentType: contentType,
      itemId: contentId,
      method: method ?? 'unknown',
    );
  }

  /// Log handyman share
  Future<void> logHandymanShare({
    required String handymanId,
    String? method,
  }) async {
    await logShare(
      contentType: 'handyman',
      contentId: handymanId,
      method: method,
    );
  }

  // ==================== Notification Events ====================

  /// Log notification received
  Future<void> logNotificationReceived({
    required String notificationType,
    Map<String, dynamic>? data,
  }) async {
    await logEvent(
      name: 'notification_received',
      parameters: {
        'notification_type': notificationType,
        if (data != null) ...data,
      },
    );
  }

  /// Log notification opened
  Future<void> logNotificationOpened({
    required String notificationType,
    Map<String, dynamic>? data,
  }) async {
    await logEvent(
      name: 'notification_opened',
      parameters: {
        'notification_type': notificationType,
        if (data != null) ...data,
      },
    );
  }

  // ==================== Error Events ====================

  /// Log error
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screen,
  }) async {
    await logEvent(
      name: 'error_occurred',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
        if (stackTrace != null) 'stack_trace': stackTrace,
        if (screen != null) 'screen': screen,
      },
    );
  }

  // ==================== Feature Usage ====================

  /// Log feature used
  Future<void> logFeatureUsed(String featureName) async {
    await logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName},
    );
  }

  /// Log filter applied
  Future<void> logFilterApplied({
    required String filterType,
    required String filterValue,
  }) async {
    await logEvent(
      name: 'filter_applied',
      parameters: {'filter_type': filterType, 'filter_value': filterValue},
    );
  }

  /// Log sort applied
  Future<void> logSortApplied(String sortType) async {
    await logEvent(name: 'sort_applied', parameters: {'sort_type': sortType});
  }

  // ==================== Conversion Events ====================

  /// Log conversion
  Future<void> logConversion({
    required String conversionType,
    double? value,
    String? currency,
  }) async {
    await logEvent(
      name: 'conversion',
      parameters: {
        'conversion_type': conversionType,
        if (value != null) 'value': value,
        if (currency != null) 'currency': currency,
      },
    );
  }

  /// Log signup conversion
  Future<void> logSignupConversion(String method) async {
    await logConversion(conversionType: 'signup');
  }

  /// Log booking conversion
  Future<void> logBookingConversion(double value) async {
    await logConversion(conversionType: 'booking', value: value);
  }

  // ==================== Debug ====================

  /// Set analytics collection enabled
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }

  /// Reset analytics data (for testing)
  Future<void> resetAnalyticsData() async {
    await _analytics.resetAnalyticsData();
  }
}
