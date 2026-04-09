/// App Routes
/// Centralized route constants and navigation configuration
///
/// Features:
/// - Named route constants
/// - Route paths
/// - Route parameters
/// - Navigation helpers
/// - Deep linking support
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/features/admin/presentation/screens/admin_home_page.dart';
import 'package:fixilya_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fixilya_app/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:fixilya_app/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:fixilya_app/features/client/presentation/screens/client_bookings_page.dart';
import 'package:fixilya_app/features/client/presentation/screens/handymen_map_page.dart';
import 'package:fixilya_app/features/client/presentation/screens/favorites_page.dart';
import 'package:fixilya_app/features/guest/presentation/screens/guest_home_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_details_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_settings_page.dart';
import 'package:fixilya_app/features/client/presentation/screens/invoices_page.dart';
import 'package:fixilya_app/features/client/presentation/screens/notifications_page.dart';
import 'package:fixilya_app/features/client/presentation/screens/payments_page.dart';
import 'package:fixilya_app/features/client/presentation/screens/settings_screen.dart';
import 'package:fixilya_app/shared/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Import screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/user_type_selection_screen.dart';
import '../../features/auth/presentation/screens/welcome_after_signup.dart';
import '../../features/handyman/presentation/screens/handyman_profile_setup.dart';
import '../../features/client/presentation/screens/client_profile_setup.dart';
import '../../features/client/presentation/screens/client_profile_page.dart';
import '../../features/handyman/presentation/screens/handyman_profile_page.dart';
import '../../views/widget_tree.dart';

/// Routes that don't require authentication.
const _publicRoutes = {
  AppRoutes.splash,
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.userTypeSelection,
  AppRoutes.forgotPassword,
  AppRoutes.guestHome,
};

/// GetX middleware that redirects unauthenticated users to the welcome screen.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (_publicRoutes.contains(route)) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const RouteSettings(name: AppRoutes.welcome);
    }
    return null;
  }
}

class AppRoutes {
  AppRoutes._(); // Private constructor

  // ==================== Route Names ====================

  // Auth Routes
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String emailVerification = '/email-verification';
  static const String userTypeSelection = '/user-type-selection';
  static const String phoneVerification = '/phone-verification';
  static const String welcomeAfterSignup = '/welcome-after-signup';

  // Main App Routes
  static const String home = '/home';
  static const String widgetTree = '/widget-tree';
  static const String explore = '/explore';
  static const String bookings = '/bookings';
  static const String messages = '/messages';
  static const String profile = '/profile';

  // Profile Routes
  static const String handymanProfileSetup = '/handyman-profile-setup';
  static const String clientProfileSetup = '/client-profile-setup';
  static const String clientProfile = '/client-profile';
  static const String handymanProfile = '/handyman-profile';
  static const String editProfile = '/edit-profile';
  static const String clientSettings = '/client-settings';
  static const String changePassword = '/change-password';
  static const String clientNotifications = '/client-notifications';
  static const String notificationSettings = '/notification-settings';
  static const String clientFavorites = '/client-favorites';
  static const String clientBookings = '/client-bookings';

  // Handyman Routes
  static const String handymanDetails = '/handyman-details';
  static const String handymanList = '/handyman-list';
  static const String handymanSearch = '/handyman-search';
  static const String handymanReviews = '/handyman-reviews';
  static const String handymanSettings = '/handyman-settings'; // ✅ NEW

  // Admin
  static const String admin = '/admin';

  // Guest
  static const String guestHome = '/guest-home';

  // Booking Routes
  static const String createBooking = '/create-booking';
  static const String bookingDetails = '/booking-details';
  static const String bookingHistory = '/booking-history';
  static const String bookingConfirmation = '/booking-confirmation';
  static const String bookingTracking = '/booking-tracking';

  // Chat Routes
  static const String chatList = '/chat-list';
  static const String chatRoom = '/chat-room';

  // Payment Routes
  static const String payment = '/payment';
  static const String paymentMethods = '/payment-methods';
  static const String addPaymentMethod = '/add-payment-method';
  static const String paymentSuccess = '/payment-success';
  static const String paymentFailed = '/payment-failed';

  // Review Routes
  static const String reviews = '/reviews';
  static const String writeReview = '/write-review';

  // Map Routes
  static const String handymenMap = '/handymen-map';

  // Quick Action Routes
  static const String invoices = '/invoices';
  static const String payments = '/payments';

  // Navigation helpers
  static Future<void> toInvoices() => to(invoices)!;
  static Future<void> toClientNotifications() => to(clientNotifications)!;
  static Future<void> toPayments() => to(payments)!;
  static Future<void> toClientSettings() => to(clientSettings)!;

  // Category Routes
  static const String categories = '/categories';
  static const String categoryDetails = '/category-details';

  // Search & Filter Routes
  static const String search = '/search';
  static const String filter = '/filter';

  // Help & Support Routes
  static const String help = '/help';
  static const String helpCenter = '/help-center';
  static const String contactSupport = '/contact-support';
  static const String faq = '/faq';
  static const String about = '/about';
  static const String terms = '/terms';
  static const String privacy = '/privacy';

  // ==================== Route Parameters ====================

  static const String paramId = 'id';
  static const String paramUserId = 'userId';
  static const String paramUserType = 'userType';
  static const String paramUserName = 'userName';
  static const String paramEmail = 'email';
  static const String paramPhone = 'phone';
  static const String paramFullName = 'fullName';
  static const String paramHandymanId = 'handymanId';
  static const String paramBookingId = 'bookingId';
  static const String paramChatId = 'chatId';
  static const String paramCategoryId = 'categoryId';
  static const String paramReviewId = 'reviewId';

  // ==================== GetX Pages ====================

  static List<GetPage> pages = [
    // Welcome & Splash
    GetPage(
      name: splash,
      page: () => const SplashScreen(), // ✅ New - checks auth first
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: welcome,
      page: () => WelcomeScreen(),
      transition: Transition.fadeIn,
    ),

    // Auth Pages
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: userTypeSelection,
      page: () => UserTypeSelectionScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: signup,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return SignUpScreen(userType: args?[paramUserType] ?? 'client');
      },
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: emailVerification,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;


        return EmailVerificationScreen(
          userType: args[paramUserType],
          userName: args[paramUserName],
          email: args[paramEmail],
          phone: args[paramPhone],
          fullName: args[paramFullName],
        );
      },
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: forgotPassword,
      page: () {
        // final args = Get.arguments as Map<String, dynamic>;
        return ForgotPasswordScreen();
      },
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: welcomeAfterSignup,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        return WelcomeAfterSignup(
          userType: args[paramUserType],
          userName: args[paramUserName],
        );
      },
      transition: Transition.fadeIn,
    ),

    // Profile Setup
    GetPage(
      name: handymanProfileSetup,
      page: () => HandymanProfileSetup(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: clientProfileSetup,
      page: () => ClientProfileSetup(),
      transition: Transition.rightToLeft,
    ),

    // Main App - WidgetTree (Your main home screen)
    GetPage(
      name: widgetTree,
      page: () => const WidgetTree(),
      transition: Transition.fadeIn,
      middlewares: [AuthGuard()],
    ),

    GetPage(
      name: home,
      page: () => const WidgetTree(),
      transition: Transition.fadeIn,
      middlewares: [AuthGuard()],
    ),

    // Profile Pages
    GetPage(
      name: clientProfile,
      page: () => ClientProfilePage(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: handymanProfile,
      page: () => HandymanProfilePage(),
      transition: Transition.rightToLeft,
    ),

    // handymanDetails
    GetPage(
      name: handymanDetails,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        final handyman = args["handyman"] as Map<String, dynamic>;

        return HandymanDetailsPage(handyman: handyman);
      },
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Handyman Settings Page
    GetPage(
      name: handymanSettings,
      page: () => HandymanSettingsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // Quick Action Pages
    GetPage(
      name: invoices,
      page: () => InvoicesPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: clientNotifications,
      page: () => ClientNotificationsPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: payments,
      page: () => PaymentsPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: clientSettings,
      page: () => ClientSettingsPage(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: admin,
      page: () => AdminDashboardPage(),
      transition: Transition.rightToLeft,
      middlewares: [AuthGuard()],
    ),

    GetPage(
      name: AppRoutes.guestHome,
      page: () => const GuestHomePage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(name: AppRoutes.clientFavorites, page: () => FavoritesPage()),
    GetPage(name: clientBookings, page: () => ClientBookingsPage()),
    GetPage(
      name: handymenMap,
      page: () => const HandymenMapPage(),
      transition: Transition.rightToLeft,
    ),

    // Chat
    GetPage(
      name: chatList,
      page: () => const ChatListScreen(),
      transition: Transition.rightToLeft,
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: chatRoom,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        return ChatRoomScreen(
          chatId: args[paramChatId] ?? '',
          otherUserId: args[paramHandymanId] ?? args['otherUserId'] ?? '',
          otherUserName: args['otherUserName'] ?? '',
          otherUserPicture: args['otherUserPicture'] as String?,
        );
      },
      transition: Transition.rightToLeft,
    ),
  ];

  static void toHandymenMap() => Get.toNamed(handymenMap);

  static void toFavorites() {
    Get.toNamed(clientFavorites);
  }

  static void toClientBookings() {
    Get.toNamed(clientBookings);
  }

  // ==================== Navigation Helpers ====================

  static Future<T?>? to<T>(String route, {dynamic arguments}) {
    return Get.toNamed<T>(route, arguments: arguments);
  }

  /// Navigate to route

  /// Navigate to route and remove previous route
  static Future<T?>? off<T>(String route, {dynamic arguments}) {
    return Get.offNamed<T>(route, arguments: arguments);
  }

  /// Navigate to route and remove all previous routes
  static Future<T?>? offAll<T>(String route, {dynamic arguments}) {
    return Get.offAllNamed<T>(route, arguments: arguments);
  }

  /// Navigate back
  static void back<T>({T? result}) {
    Get.back<T>(result: result);
  }

  /// Navigate to route until predicate
  static Future<T?>? offUntil<T>(
    String route, {
    bool Function(Route<dynamic>)? predicate,
    dynamic arguments,
  }) {
    return Get.offNamedUntil<T>(
      route,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }

  // ==================== Specific Navigation Methods ====================
  /// Navigate to welcome screen
  static Future<void> toWelcome() => to(welcome)!;

  /// Navigate to login
  static Future<void> toLogin() => to(login)!;

  /// Navigate to user type selection
  static Future<void> toUserTypeSelection() => to(userTypeSelection)!;

  /// Navigate to signup with user type
  static Future<void> toSignup(String userType) {
    return to(signup, arguments: {paramUserType: userType})!;
  }

  static void toAdmin() => Get.toNamed(admin);

  static void toGuestHome() {
    Get.offAllNamed(guestHome);
  }

  /// Navigate to email verification
  static Future<void> toEmailVerification({
    required String userType,
    required String userName,
    required String email,
    required String phone,
    required String fullName,
  }) {
    return to(
      emailVerification,
      arguments: {
        paramUserType: userType,
        paramUserName: userName,
        paramEmail: email,
        paramPhone: phone,
        paramFullName: fullName,
      },
    )!;
  }

  /// Navigate to welcome after signup
  static Future<void> toWelcomeAfterSignup({
    required String userType,
    required String userName,
  }) {
    return to(
      welcomeAfterSignup,
      arguments: {paramUserType: userType, paramUserName: userName},
    )!;
  }

  /// Navigate to profile setup based on user type
  static Future<void> toProfileSetup(String userType) {
    if (userType.toLowerCase() == 'handyman') {
      return to(handymanProfileSetup)!;
    } else {
      return to(clientProfileSetup)!;
    }
  }

  /// Navigate to main app (WidgetTree) - clear stack
  static Future<void> toHome() => offAll(widgetTree)!;

  /// Navigate to WidgetTree - clear stack
  static Future<void> toWidgetTree() => offAll(widgetTree)!;

  /// Navigate to profile based on user type
  static Future<void> toProfile(String userType) {
    if (userType.toLowerCase() == 'handyman') {
      return to(handymanProfile)!;
    } else {
      return to(clientProfile)!;
    }
  }

  /// Navigate to handyman details
  static Future<void> toHandymanDetails(Map<String, dynamic> handyman) {
    return to(handymanDetails, arguments: {'handyman': handyman})!;
  }

  // Navigate to handyman settings
  static Future<void> toHandymanSettings() => to(handymanSettings)!;

  /// Navigate to booking details
  static Future<void> toBookingDetails(String bookingId) {
    return to(bookingDetails, arguments: {paramBookingId: bookingId})!;
  }

  /// Navigate to chat room
  static Future<void> toChatRoom(String chatId, String handymanId) {
    return to(
      chatRoom,
      arguments: {paramChatId: chatId, paramHandymanId: handymanId},
    )!;
  }

  /// Navigate to create booking
  static Future<void> toCreateBooking(String handymanId) {
    return to(createBooking, arguments: {paramHandymanId: handymanId})!;
  }

  /// Navigate to write review
  static Future<void> toWriteReview(String bookingId) {
    return to(writeReview, arguments: {paramBookingId: bookingId})!;
  }

  /// Navigate to payment
  static Future<void> toPayment(String bookingId, double amount) {
    return to(
      payment,
      arguments: {paramBookingId: bookingId, 'amount': amount},
    )!;
  }

  // ==================== Route Guards ====================

  /// Returns true when a Firebase user is signed in.
  static bool get isAuthenticated =>
      FirebaseAuth.instance.currentUser != null;

  /// Get initial route based on auth state
  static String get initialRoute =>
      isAuthenticated ? widgetTree : welcome;

  // ==================== Deep Linking Support ====================

  /// Parse deep link
  static String? parseDeepLink(Uri uri) {
    final path = uri.path;

    // Handle different deep link patterns
    if (path.startsWith('/handyman/')) {
      final id = path.split('/').last;
      return '$handymanDetails?$paramHandymanId=$id';
    } else if (path.startsWith('/booking/')) {
      final id = path.split('/').last;
      return '$bookingDetails?$paramBookingId=$id';
    }

    return null;
  }

  /// Build route with parameters
  static String buildRoute(String route, Map<String, dynamic> params) {
    final buffer = StringBuffer(route);
    if (params.isNotEmpty) {
      buffer.write('?');
      params.forEach((key, value) {
        buffer.write('$key=$value&');
      });
    }
    return buffer.toString().replaceAll(RegExp(r'&$'), '');
  }

  // ==================== Route History ====================

  /// Get current route
  static String get currentRoute {
    return Get.currentRoute;
  }

  /// Get previous route
  static String? get previousRoute {
    return Get.previousRoute;
  }

  /// Check if can pop
  static bool get canPop {
    return Navigator.canPop(Get.context!);
  }

  // ==================== Route Analytics ====================

  /// Log route change (for analytics)
  static void logRouteChange(String route) {
    // Implement analytics logging
    // Get.find<AnalyticsService>().logScreenView(route);
  }
}
