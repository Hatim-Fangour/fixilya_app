// lib/data/controllers/theme_controller.dart
import 'package:fixilya_app/services/local_storage_service.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ThemePreference { light, dark, system }

class ThemeController extends GetxController {
  final _localStorage = LocalStorageService();
  final _handymanDataService = HandymanDataService();
  final _auth = FirebaseAuth.instance;

  final _themePreference = ThemePreference.system.obs;
  final _isDarkMode = false.obs;

  ThemePreference get themePreference => _themePreference.value;
  bool get isDarkMode => _isDarkMode.value;

  ThemeMode get themeMode {
    switch (_themePreference.value) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.system:
        return ThemeMode.system;
    }
  }

  @override
  void onInit() {
    super.onInit();

    _loadThemePreference();

    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
          debugPrint('🔔 System brightness changed!');
          if (_themePreference.value == ThemePreference.system) {
            _updateDarkModeBasedOnSystem();
            update();
          }
        };

    _auth.authStateChanges().listen((user) async {
      if (user == null) {
        debugPrint('🔓 User logged out - resetting theme to system');
        await _resetToSystemTheme();
      } else {
        debugPrint('🔐 User logged in - loading theme preferences');
        await _loadThemePreference();
      }
    });
  }

  Future<void> _loadThemePreference() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        // ✅ GUEST MODE: FORCE system theme
        debugPrint('👤 Guest mode - FORCING system theme');

        await _localStorage.setThemePreference('system');
        _themePreference.value = ThemePreference.system;
        _updateDarkMode();

        debugPrint('✅ Guest theme: ${_themePreference.value}');
        debugPrint(
          '✅ System brightness: ${SchedulerBinding.instance.platformDispatcher.platformBrightness}',
        );
        debugPrint('✅ Dark mode: ${_isDarkMode.value}');
        return;
      }

      debugPrint('🔐 Loading theme for user: ${user.uid}');

      final profile = await _handymanDataService.getHandymanProfile();

      if (profile != null && profile['themePreference'] != null) {
        final savedTheme = profile['themePreference'] as String;
        _themePreference.value = _parseThemePreference(savedTheme);
        debugPrint('✅ Theme from Firestore: $savedTheme');
      } else {
        final savedTheme = _localStorage.getThemePreference();

        if (savedTheme == null || savedTheme.isEmpty) {
          debugPrint('⚠️ No saved theme - defaulting to system');
          _themePreference.value = ThemePreference.system;
        } else {
          _themePreference.value = _parseThemePreference(savedTheme);
          debugPrint('✅ Theme from storage: $savedTheme');
        }
      }

      _updateDarkMode();
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
      _themePreference.value = ThemePreference.system;
      _updateDarkMode();
    }
  }

  void _updateDarkMode() {
    if (_themePreference.value == ThemePreference.system) {
      _updateDarkModeBasedOnSystem();
    } else {
      _isDarkMode.value = _themePreference.value == ThemePreference.dark;
    }
  }

  void _updateDarkModeBasedOnSystem() {
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    final wasInDarkMode = _isDarkMode.value;
    _isDarkMode.value = brightness == Brightness.dark;

    debugPrint('🌓 System brightness: $brightness');
    debugPrint('🌓 Was dark: $wasInDarkMode → Now dark: ${_isDarkMode.value}');

    if (wasInDarkMode != _isDarkMode.value) {
      debugPrint('🔄 Dark mode changed - rebuilding UI');
    }
  }

  ThemePreference _parseThemePreference(String? value) {
    switch (value) {
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
      case 'system':
      default:
        return ThemePreference.system;
    }
  }

  Future<void> setThemePreference(ThemePreference preference) async {
    final user = _auth.currentUser;

    if (user == null) {
      debugPrint('⚠️ Cannot set theme - user not logged in');
      Get.snackbar(
        'Login Required',
        'Please login to customize your theme',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
      return;
    }

    if (_themePreference.value == preference) return;

    _themePreference.value = preference;
    _updateDarkMode();

    await _localStorage.setThemePreference(preference.name);

    try {
      await _handymanDataService.updateHandymanProfile({
        'themePreference': preference.name,
        'themeUpdatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Theme saved to Firestore: ${preference.name}');
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    final newPreference = _isDarkMode.value
        ? ThemePreference.light
        : ThemePreference.dark;
    await setThemePreference(newPreference);
  }

  Future<void> resetThemeToSystem() async {
    debugPrint('🔄 Resetting theme to system...');
    await _resetToSystemTheme();
    debugPrint('✅ Theme reset complete');
  }

  Future<void> _resetToSystemTheme() async {
    _themePreference.value = ThemePreference.system;
    _updateDarkMode();
    await _localStorage.setThemePreference('system');

    debugPrint('✅ Theme preference: ${_themePreference.value}');
    debugPrint('✅ Dark mode: ${_isDarkMode.value}');
  }

  String getThemePreferenceName() {
    switch (_themePreference.value) {
      case ThemePreference.light:
        return 'Light';
      case ThemePreference.dark:
        return 'Dark';
      case ThemePreference.system:
        return 'System';
    }
  }

  bool get isUserLoggedIn => _auth.currentUser != null;

  Brightness get systemBrightness =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness;
}
