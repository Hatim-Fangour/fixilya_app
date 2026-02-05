// lib/data/services/local_storage_service.dart
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late final GetStorage _box;
  bool _isInitialized = false;

  // Storage Keys
  static const String _darkModeKey = 'isDarkMode';
  static const String _languageKey = 'language';
  static const String _firstLaunchKey = 'isFirstLaunch';
  static const String _userPrefsKey = 'userPreferences';

  /// Initialize GetStorage - call this in main()
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await GetStorage.init();
      _box = GetStorage();
      _isInitialized = true;
      debugPrint('✅ LocalStorageService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing LocalStorageService: $e');
      rethrow;
    }
  }

  /// Check if storage is initialized
  bool get isInitialized => _isInitialized;

  // ==================== Dark Mode ====================

  /// Get dark mode preference
  bool getDarkMode() {
    try {
      return _box.read<bool>(_darkModeKey) ?? false;
    } catch (e) {
      debugPrint('Error reading dark mode: $e');
      return false;
    }
  }

  /// Save dark mode preference
  Future<void> setDarkMode(bool isDark) async {
    try {
      await _box.write(_darkModeKey, isDark);
      debugPrint('Dark mode saved: $isDark');
    } catch (e) {
      debugPrint('Error saving dark mode: $e');
    }
  }

  // ==================== Language ====================

  /// Get saved language
  String? getLanguage() {
    try {
      return _box.read<String>(_languageKey);
    } catch (e) {
      debugPrint('Error reading language: $e');
      return null;
    }
  }

  /// Save language preference
  Future<void> setLanguage(String languageCode) async {
    try {
      await _box.write(_languageKey, languageCode);
      debugPrint('Language saved: $languageCode');
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  // ==================== First Launch ====================

  /// Check if this is first app launch
  bool isFirstLaunch() {
    try {
      return _box.read<bool>(_firstLaunchKey) ?? true;
    } catch (e) {
      debugPrint('Error reading first launch: $e');
      return true;
    }
  }

  /// Mark app as launched
  Future<void> setFirstLaunchComplete() async {
    try {
      await _box.write(_firstLaunchKey, false);
    } catch (e) {
      debugPrint('Error saving first launch: $e');
    }
  }

  // ==================== Generic Methods ====================

  /// Read any value with type safety
  T? read<T>(String key) {
    try {
      return _box.read<T>(key);
    } catch (e) {
      debugPrint('Error reading $key: $e');
      return null;
    }
  }

  /// Write any value
  Future<void> write(String key, dynamic value) async {
    try {
      await _box.write(key, value);
    } catch (e) {
      debugPrint('Error writing $key: $e');
    }
  }

  /// Remove a key
  Future<void> remove(String key) async {
    try {
      await _box.remove(key);
      debugPrint('Removed key: $key');
    } catch (e) {
      debugPrint('Error removing $key: $e');
    }
  }

  /// Clear all storage
  Future<void> clearAll() async {
    try {
      await _box.erase();
      debugPrint('All storage cleared');
    } catch (e) {
      debugPrint('Error clearing storage: $e');
    }
  }

  /// Check if key exists
  bool hasData(String key) {
    try {
      return _box.hasData(key);
    } catch (e) {
      debugPrint('Error checking key $key: $e');
      return false;
    }
  }
}
