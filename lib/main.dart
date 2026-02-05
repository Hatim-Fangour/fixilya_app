// lib/main.dart
import "package:firebase_core/firebase_core.dart";
import "package:fixilya_app/core/constants/app_routes.dart";
import "package:fixilya_app/core/constants/app_theme.dart";
import "package:fixilya_app/data/controllers/auth_controller.dart";
import "package:fixilya_app/data/controllers/theme_controller.dart";
import "package:fixilya_app/data/controllers/user_controller.dart";
import "package:fixilya_app/firebase_options.dart";
import "package:fixilya_app/services/firebase_image_service.dart";
import "package:fixilya_app/services/local_storage_service.dart";
import "package:fixilya_app/services/service_locator.dart";
import "package:fixilya_app/shared/animations/animated_theme_wrapper.dart";
import "package:flutter/material.dart";
import "package:get/get.dart";
import 'package:fixilya_app/services/cloudinary_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Cloudinary
  // final cloudinaryService = CloudinaryService(
  //   cloudName: 'dbz3wtlbj', // ← From Cloudinary Dashboard
  //   uploadPreset: 'fixilya_app', // ← Your upload preset name
  // );

  await LocalStorageService().init();

  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Initialize controllers in order
  Get.put(ThemeController()); // Theme first
  Get.put(AuthController());
  Get.put(UserController());

  ServiceLocator.init();

  // final firebaseImageService = FirebaseImageService();
  // ✅ Initialize local storage FIRST

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(
      () => AnimatedThemeWrapper(
        isDarkMode: themeController.isDarkMode,
        child: GetMaterialApp(
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
