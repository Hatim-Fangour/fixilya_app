// lib/data/controllers/theme_controller.dart
import 'package:fixilya_app/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  final _localStorage = LocalStorageService();

  // Observable dark mode state
  final _isDarkMode = false.obs;

  // Getters
  bool get isDarkMode => _isDarkMode.value;
  ThemeMode get themeMode =>
      _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    _loadThemePreference();
  }

  /// Load saved theme preference
  void _loadThemePreference() {
    final savedTheme = _localStorage.getDarkMode();
    _isDarkMode.value = savedTheme;
    debugPrint('Theme loaded: ${savedTheme ? "Dark" : "Light"}');
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _isDarkMode.value = !_isDarkMode.value;
    await _localStorage.setDarkMode(_isDarkMode.value);

    // Optional: Show snackbar
    Get.snackbar(
      'Theme Changed',
      'Switched to ${_isDarkMode.value ? "Dark" : "Light"} mode',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  /// Set specific theme
  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode.value == isDark) return; // No change needed

    _isDarkMode.value = isDark;
    await _localStorage.setDarkMode(isDark);
  }

  /// Reset to system theme
  Future<void> useSystemTheme() async {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isSystemDark = brightness == Brightness.dark;
    await setTheme(isSystemDark);
  }
}
