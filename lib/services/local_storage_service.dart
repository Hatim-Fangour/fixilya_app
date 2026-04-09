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
  static const String _darkModeKey = 'dark_mode'; // Legacy
  static const String _themePreferenceKey = 'theme_preference'; // ✅ NEW
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

  // ==================== Theme Preference (NEW) ====================

  /// Get theme preference (light, dark, system)
  String? getThemePreference() {
    try {
      return _box.read<String>(_themePreferenceKey);
    } catch (e) {
      debugPrint('❌ Error reading theme preference: $e');
      return null;
    }
  }

  /// Save theme preference
  Future<void> setThemePreference(String preference) async {
    try {
      await _box.write(_themePreferenceKey, preference);
      debugPrint('✅ Theme preference saved: $preference');
    } catch (e) {
      debugPrint('❌ Error saving theme preference: $e');
    }
  }

  // ==================== Dark Mode (Legacy - Keep for backward compatibility) ====================

  /// Get dark mode preference (legacy)
  bool getDarkMode() {
    try {
      return _box.read<bool>(_darkModeKey) ?? false;
    } catch (e) {
      debugPrint('❌ Error reading dark mode: $e');
      return false;
    }
  }

  /// Save dark mode preference (legacy)
  Future<void> setDarkMode(bool isDark) async {
    try {
      await _box.write(_darkModeKey, isDark);
      debugPrint('✅ Dark mode saved: $isDark');
    } catch (e) {
      debugPrint('❌ Error saving dark mode: $e');
    }
  }

  // ==================== Language ====================

  /// Get saved language
  String? getLanguage() {
    try {
      return _box.read<String>(_languageKey);
    } catch (e) {
      debugPrint('❌ Error reading language: $e');
      return null;
    }
  }

  /// Save language preference
  Future<void> setLanguage(String languageCode) async {
    try {
      await _box.write(_languageKey, languageCode);
      debugPrint('✅ Language saved: $languageCode');
    } catch (e) {
      debugPrint('❌ Error saving language: $e');
    }
  }

  // ==================== First Launch ====================

  /// Check if this is first app launch
  bool isFirstLaunch() {
    try {
      return _box.read<bool>(_firstLaunchKey) ?? true;
    } catch (e) {
      debugPrint('❌ Error reading first launch: $e');
      return true;
    }
  }

  /// Mark app as launched
  Future<void> setFirstLaunchComplete() async {
    try {
      await _box.write(_firstLaunchKey, false);
      debugPrint('✅ First launch complete marked');
    } catch (e) {
      debugPrint('❌ Error saving first launch: $e');
    }
  }

  // ==================== User Preferences ====================

  /// Get user preferences
  Map<String, dynamic>? getUserPreferences() {
    try {
      return _box.read<Map<String, dynamic>>(_userPrefsKey);
    } catch (e) {
      debugPrint('❌ Error reading user preferences: $e');
      return null;
    }
  }

  /// Save user preferences
  Future<void> setUserPreferences(Map<String, dynamic> prefs) async {
    try {
      await _box.write(_userPrefsKey, prefs);
      debugPrint('✅ User preferences saved');
    } catch (e) {
      debugPrint('❌ Error saving user preferences: $e');
    }
  }

  // ==================== Generic Methods ====================

  /// Read any value with type safety
  T? read<T>(String key) {
    try {
      return _box.read<T>(key);
    } catch (e) {
      debugPrint('❌ Error reading $key: $e');
      return null;
    }
  }

  /// Write any value
  Future<void> write(String key, dynamic value) async {
    try {
      await _box.write(key, value);
      debugPrint('✅ Written $key: $value');
    } catch (e) {
      debugPrint('❌ Error writing $key: $e');
    }
  }

  /// Remove a key
  Future<void> remove(String key) async {
    try {
      await _box.remove(key);
      debugPrint('✅ Removed key: $key');
    } catch (e) {
      debugPrint('❌ Error removing $key: $e');
    }
  }

  /// Clear all storage
  Future<void> clearAll() async {
    try {
      await _box.erase();
      debugPrint('✅ All storage cleared');
    } catch (e) {
      debugPrint('❌ Error clearing storage: $e');
    }
  }

  /// Check if key exists
  bool hasData(String key) {
    try {
      return _box.hasData(key);
    } catch (e) {
      debugPrint('❌ Error checking key $key: $e');
      return false;
    }
  }

  /// Get all keys
  List<String> getKeys() {
    try {
      return _box.getKeys().cast<String>();
    } catch (e) {
      debugPrint('❌ Error getting keys: $e');
      return [];
    }
  }

  /// Get all values
  Map<String, dynamic> getValues() {
    try {
      return _box.getValues();
    } catch (e) {
      debugPrint('❌ Error getting values: $e');
      return {};
    }
  }

  // ==================== Migration Helper ====================

  /// Migrate old dark mode setting to new theme preference
  Future<void> migrateDarkModeToThemePreference() async {
    try {
      // Check if already migrated
      if (hasData(_themePreferenceKey)) {
        debugPrint('✅ Theme preference already set, skipping migration');
        return;
      }

      // Check if old dark mode exists
      if (hasData(_darkModeKey)) {
        final isDark = getDarkMode();
        final newPreference = isDark ? 'dark' : 'light';
        await setThemePreference(newPreference);
        debugPrint(
          '✅ Migrated dark mode ($isDark) to theme preference ($newPreference)',
        );
      } else {
        // Set default to system if nothing exists
        await setThemePreference('system');
        debugPrint('✅ Set default theme preference to system');
      }
    } catch (e) {
      debugPrint('❌ Error migrating theme preference: $e');
    }
  }
}
