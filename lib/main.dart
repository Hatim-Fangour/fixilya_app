// lib/main.dart
import "package:firebase_core/firebase_core.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:fixilya_app/core/constants/app_routes.dart";
import "package:fixilya_app/core/constants/app_colors.dart";
import "package:fixilya_app/data/controllers/auth_controller.dart";
import "package:fixilya_app/data/controllers/theme_controller.dart";
import "package:fixilya_app/data/controllers/user_controller.dart";
import "package:fixilya_app/core/config/environment.dart";
import "package:fixilya_app/firebase_options.dart";
import "package:fixilya_app/l10n/app_localizations.dart";
import "package:fixilya_app/services/api_client.dart";
import "package:fixilya_app/services/data_persistence_service.dart";
import "package:fixilya_app/services/local_storage_service.dart";
import "package:fixilya_app/services/notification_service.dart";
import "package:fixilya_app/services/service_locator.dart";
import "package:fixilya_app/services/language_service.dart";
import "package:fixilya_app/shared/animations/animated_theme_wrapper.dart";
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter/foundation.dart";

import "package:get/get.dart";

void main() async {
  // ensureInitialized and ALL runApp calls must be in the same zone.
  // Using async main (no runZonedGuarded) eliminates zone mismatch entirely.
  WidgetsFlutterBinding.ensureInitialized();

  // Catch unhandled async platform errors without creating a new zone.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error\n$stack');
    return true;
  };

  try {
    await _bootstrap();
  } catch (error, stack) {
    debugPrint('FATAL STARTUP ERROR: $error\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              'STARTUP CRASH\n\n$error\n\n$stack',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    ));
  }
}

Future<void> _bootstrap() async {
  // Set environment based on build mode
  EnvironmentConfig.setEnvironment(
    kReleaseMode ? Environment.production : Environment.development,
  );

  await LocalStorageService().init();
  await LocalStorageService().migrateDarkModeToThemePreference();

  // Initialise the data persistence cache (separate GetStorage container)
  await DataPersistenceService().init();

  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Enable Firestore offline persistence (100 MB cap)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
  );

  // Initialize controllers in order
  Get.put(ThemeController()); // Theme first
  Get.put(AuthController());
  Get.put(UserController());
  Get.put(LanguageService());

  ServiceLocator.init();

  // Initialize API client
  ApiClient().init();

  // Initialize push notifications (after Firebase + ApiClient are ready)
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final languageService = Get.find<LanguageService>();

    return Obx(
      () => AnimatedThemeWrapper(
        isDarkMode: themeController.isDarkMode,
        child: GetMaterialApp(
          title: 'Fixilya',

          // ✅ Localization Delegates
          localizationsDelegates: [
            AppLocalizations.delegate, // ✅ Your app localizations
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // ✅ Supported Locales
          supportedLocales: [Locale('en'), Locale('ar'), Locale('fr')],

          // ✅ Current Locale
          locale: languageService.locale,

          // ✅ Fallback Locale
          fallbackLocale: Locale('en'),
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeController.themeMode,
          initialRoute: '/',
          getPages: AppRoutes.pages,
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(primary: AppColors.secondary),
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F1115),
      colorScheme: const ColorScheme.dark(primary: AppColors.secondary),
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        backgroundColor: Color(0xFF0F1115),
      ),
    );
  }
}
