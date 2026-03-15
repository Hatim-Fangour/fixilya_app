import 'package:get_storage/get_storage.dart';

/// Local data source for auth-related persistence.
///
/// Uses GetStorage to store/retrieve auth tokens,
/// user type, and onboarding completion status.
class AuthLocalData {
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserType = 'user_type';
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyUserId = 'user_id';

  final GetStorage _storage;

  AuthLocalData({GetStorage? storage}) : _storage = storage ?? GetStorage();

  // ==================== Auth Token ====================

  /// Store the auth token locally.
  Future<void> saveAuthToken(String token) async {
    await _storage.write(_keyAuthToken, token);
  }

  /// Retrieve the stored auth token, or null if not present.
  String? getAuthToken() {
    return _storage.read<String>(_keyAuthToken);
  }

  /// Remove the stored auth token.
  Future<void> clearAuthToken() async {
    await _storage.remove(_keyAuthToken);
  }

  // ==================== User Type ====================

  /// Store the user type (e.g. 'client' or 'handyman').
  Future<void> saveUserType(String userType) async {
    await _storage.write(_keyUserType, userType);
  }

  /// Retrieve the stored user type, or null if not set.
  String? getUserType() {
    return _storage.read<String>(_keyUserType);
  }

  /// Remove the stored user type.
  Future<void> clearUserType() async {
    await _storage.remove(_keyUserType);
  }

  // ==================== Onboarding ====================

  /// Mark onboarding as completed.
  Future<void> setOnboardingComplete(bool complete) async {
    await _storage.write(_keyOnboardingComplete, complete);
  }

  /// Check whether onboarding has been completed.
  bool isOnboardingComplete() {
    return _storage.read<bool>(_keyOnboardingComplete) ?? false;
  }

  // ==================== User ID ====================

  /// Store the current user ID for quick access.
  Future<void> saveUserId(String userId) async {
    await _storage.write(_keyUserId, userId);
  }

  /// Retrieve the stored user ID, or null if not set.
  String? getUserId() {
    return _storage.read<String>(_keyUserId);
  }

  // ==================== Clear All ====================

  /// Clear all auth-related local data (e.g. on logout).
  Future<void> clearAll() async {
    await _storage.remove(_keyAuthToken);
    await _storage.remove(_keyUserType);
    await _storage.remove(_keyOnboardingComplete);
    await _storage.remove(_keyUserId);
  }
}
