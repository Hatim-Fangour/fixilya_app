import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends GetxController {
  static const String _languageKey = 'app_language';

  final Rx<Locale> _locale = Locale('en').obs;
  Locale get locale => _locale.value;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLanguage();
  }

  /// Load saved language from SharedPreferences
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      _locale.value = Locale(languageCode);
      Get.updateLocale(_locale.value);
    } catch (e) {
      print('Error loading language: $e');
    }
  }

  /// Change app language
  Future<void> changeLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);

      _locale.value = Locale(languageCode);
      Get.updateLocale(_locale.value);

      print('✅ Language changed to: $languageCode');
    } catch (e) {
      print('❌ Error changing language: $e');
    }
  }

  /// Get available languages
  List<Map<String, String>> get availableLanguages => [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
  ];

  /// Check if current language is RTL
  bool get isRTL => _locale.value.languageCode == 'ar';
}
