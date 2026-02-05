/// User Controller
/// Complete user profile and data management
///
/// Features:
/// - User profile management
/// - Profile updates (name, phone, image, bio)
/// - User preferences
/// - Account settings
/// - Activity tracking
/// - Favorites management
/// - Notifications preferences
/// - Privacy settings
/// - Data caching
/// - Offline support

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/storage_service.dart';
import '../../../core/constants/app_routes.dart';

class UserController extends GetxController {
  final UserRepository _userRepo = UserRepository();
  final StorageService _storageService = StorageService();

  // ==================== Observable State ====================

  // User data
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  final RxBool _isLoading = false.obs;
  final RxBool _isUpdating = false.obs;
  final RxString _error = ''.obs;

  // Profile completion
  final RxInt _profileCompletionPercentage = 0.obs;

  // User preferences
  final RxBool _notificationsEnabled = true.obs;
  final RxBool _emailNotifications = true.obs;
  final RxBool _pushNotifications = true.obs;
  final RxBool _smsNotifications = false.obs;

  // Privacy settings
  final RxBool _profilePublic = true.obs;
  final RxBool _showEmail = false.obs;
  final RxBool _showPhone = false.obs;

  // Activity tracking
  final RxInt _bookingsCount = 0.obs;
  final RxInt _reviewsCount = 0.obs;
  final RxDouble _averageRating = 0.0.obs;

  // Favorites
  final RxList<String> _favoriteHandymen = <String>[].obs;

  // ==================== Getters ====================

  UserModel? get currentUser => _currentUser.value;
  bool get isLoading => _isLoading.value;
  bool get isUpdating => _isUpdating.value;
  String get error => _error.value;

  // User info
  String get userId => _currentUser.value?.id ?? '';
  String get userEmail => _currentUser.value?.email ?? '';
  String get userName => _currentUser.value?.fullName ?? 'User';
  String get userPhone => _currentUser.value?.phone ?? '';
  String get userType => _currentUser.value?.userType ?? 'client';
  String? get userProfileImage => _currentUser.value?.profileImage;
  // String? get userBio => _currentUser.value?.bio;
  // String? get userCity => _currentUser.value?.city;

  // Status
  bool get isClient => userType.toLowerCase() == 'client';
  bool get isHandyman => userType.toLowerCase() == 'handyman';
  // bool get isEmailVerified => _currentUser.value?.emailVerified ?? false;
  // bool get isPhoneVerified => _currentUser.value?.phoneVerified ?? false;
  bool get isProfileComplete => _profileCompletionPercentage.value >= 80;

  // Profile completion
  int get profileCompletionPercentage => _profileCompletionPercentage.value;

  // Preferences
  bool get notificationsEnabled => _notificationsEnabled.value;
  bool get emailNotifications => _emailNotifications.value;
  bool get pushNotifications => _pushNotifications.value;
  bool get smsNotifications => _smsNotifications.value;

  // Privacy
  bool get profilePublic => _profilePublic.value;
  bool get showEmail => _showEmail.value;
  bool get showPhone => _showPhone.value;

  // Activity
  int get bookingsCount => _bookingsCount.value;
  int get reviewsCount => _reviewsCount.value;
  double get averageRating => _averageRating.value;

  // Favorites
  List<String> get favoriteHandymen => _favoriteHandymen;
  bool isFavorite(String handymanId) => _favoriteHandymen.contains(handymanId);

  @override
  void onInit() {
    super.onInit();
    _loadUserPreferences();
  }

  // ==================== User Data Management ====================

  /// Load user data by ID
  Future<void> loadUser(String userId) async {
    try {
      _isLoading.value = true;
      _error.value = '';

      final user = await _userRepo.getUserById(userId);
      if (user != null) {
        _currentUser.value = user;
        _calculateProfileCompletion();
        await _loadUserActivity();
      }
    } catch (e) {
      _error.value = e.toString();
      _showError('Failed to load user data');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Reload current user data
  Future<void> reloadUser() async {
    if (userId.isNotEmpty) {
      await loadUser(userId);
    }
  }

  /// Listen to user data stream
  void listenToUser(String userId) {
    _userRepo
        .getUserStream(userId)
        .listen(
          (user) {
            if (user != null) {
              _currentUser.value = user;
              _calculateProfileCompletion();
            }
          },
          onError: (e) {
            _error.value = e.toString();
          },
        );
  }

  // ==================== Profile Updates ====================

  /// Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    if (_currentUser.value == null) return false;

    try {
      _isUpdating.value = true;
      _error.value = '';

      final updatedUser = _currentUser.value!.copyWith(
        fullName: fullName,
        phone: phone,
        // bio: bio,
        // city: city,
        // address: address,
        // latitude: latitude,
        // longitude: longitude,
      );

      await _userRepo.updateUser(updatedUser);
      _currentUser.value = updatedUser;
      _calculateProfileCompletion();

      _showSuccess('Profile updated successfully');
      return true;
    } catch (e) {
      _error.value = e.toString();
      _showError('Failed to update profile');
      return false;
    } finally {
      _isUpdating.value = false;
    }
  }

  /// Update profile image
  Future<bool> updateProfileImage(ImageSource source) async {
    if (_currentUser.value == null) return false;

    try {
      _isUpdating.value = true;

      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        _isUpdating.value = false;
        return false;
      }

      // Upload to storage
      final imageUrl = await _storageService.uploadProfilePicture(
        userId: userId,
        imageFile: File(image.path),
      );

      // Update user document
      final updatedUser = _currentUser.value!.copyWith(profileImage: imageUrl);

      await _userRepo.updateUser(updatedUser);
      _currentUser.value = updatedUser;

      _showSuccess('Profile image updated');
      return true;
    } catch (e) {
      _error.value = e.toString();
      _showError('Failed to update profile image');
      return false;
    } finally {
      _isUpdating.value = false;
    }
  }

  /// Remove profile image
  Future<bool> removeProfileImage() async {
    if (_currentUser.value == null) return false;

    try {
      _isUpdating.value = true;

      // Delete from storage if exists
      if (_currentUser.value!.profileImage != null) {
        await _storageService.deleteImage(_currentUser.value!.profileImage!);
      }

      // Update user document
      final updatedUser = _currentUser.value!.copyWith(profileImage: null);

      await _userRepo.updateUser(updatedUser);
      _currentUser.value = updatedUser;

      _showSuccess('Profile image removed');
      return true;
    } catch (e) {
      _error.value = e.toString();
      _showError('Failed to remove profile image');
      return false;
    } finally {
      _isUpdating.value = false;
    }
  }

  // ==================== Preferences Management ====================

  /// Toggle notifications
  void toggleNotifications(bool value) {
    _notificationsEnabled.value = value;
    _saveUserPreferences();
  }

  /// Toggle email notifications
  void toggleEmailNotifications(bool value) {
    _emailNotifications.value = value;
    _saveUserPreferences();
  }

  /// Toggle push notifications
  void togglePushNotifications(bool value) {
    _pushNotifications.value = value;
    _saveUserPreferences();
  }

  /// Toggle SMS notifications
  void toggleSmsNotifications(bool value) {
    _smsNotifications.value = value;
    _saveUserPreferences();
  }

  /// Toggle profile visibility
  void toggleProfilePublic(bool value) {
    _profilePublic.value = value;
    _saveUserPreferences();
  }

  /// Toggle email visibility
  void toggleShowEmail(bool value) {
    _showEmail.value = value;
    _saveUserPreferences();
  }

  /// Toggle phone visibility
  void toggleShowPhone(bool value) {
    _showPhone.value = value;
    _saveUserPreferences();
  }

  // ==================== Favorites Management ====================

  /// Add handyman to favorites
  Future<void> addToFavorites(String handymanId) async {
    if (_favoriteHandymen.contains(handymanId)) return;

    try {
      _favoriteHandymen.add(handymanId);
      await _saveFavorites();
      _showSuccess('Added to favorites');
    } catch (e) {
      _favoriteHandymen.remove(handymanId);
      _showError('Failed to add to favorites');
    }
  }

  /// Remove handyman from favorites
  Future<void> removeFromFavorites(String handymanId) async {
    if (!_favoriteHandymen.contains(handymanId)) return;

    try {
      _favoriteHandymen.remove(handymanId);
      await _saveFavorites();
      _showSuccess('Removed from favorites');
    } catch (e) {
      _favoriteHandymen.add(handymanId);
      _showError('Failed to remove from favorites');
    }
  }

  /// Toggle favorite
  Future<void> toggleFavorite(String handymanId) async {
    if (isFavorite(handymanId)) {
      await removeFromFavorites(handymanId);
    } else {
      await addToFavorites(handymanId);
    }
  }

  // ==================== Account Actions ====================

  /// Delete account
  Future<bool> deleteAccount() async {
    try {
      _isLoading.value = true;

      // Delete user data from Firestore
      await _userRepo.deleteUser(userId);

      // Delete profile image from storage
      if (_currentUser.value?.profileImage != null) {
        await _storageService.deleteImage(_currentUser.value!.profileImage!);
      }

      // Delete Firebase Auth account
      await FirebaseAuth.instance.currentUser?.delete();

      _showSuccess('Account deleted successfully');
      AppRoutes.toLogin();
      return true;
    } catch (e) {
      _error.value = e.toString();
      _showError('Failed to delete account');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // ==================== Helper Methods ====================

  /// Calculate profile completion percentage
  void _calculateProfileCompletion() {
    if (_currentUser.value == null) {
      _profileCompletionPercentage.value = 0;
      return;
    }

    int completed = 0;
    const int total = 8;

    final user = _currentUser.value!;

    if (user.fullName.isNotEmpty) completed++;
    if (user.email.isNotEmpty) completed++;
    if (user.phone.isNotEmpty) completed++;
    if (user.profileImage != null) completed++;
    // if (user.bio != null && user.bio!.isNotEmpty) completed++;
    // if (user.city != null && user.city!.isNotEmpty) completed++;
    // if (user.address != null && user.address!.isNotEmpty) completed++;
    if (user.emailVerified) completed++;

    _profileCompletionPercentage.value = ((completed / total) * 100).round();
  }

  /// Load user activity stats
  Future<void> _loadUserActivity() async {
    try {
      // TODO: Load from Firestore
      // For now, using placeholder values
      _bookingsCount.value = 0;
      _reviewsCount.value = 0;
      _averageRating.value = 0.0;
    } catch (e) {
      print('Error loading user activity: $e');
    }
  }

  /// Save user preferences to local storage
  Future<void> _saveUserPreferences() async {
    try {
      // TODO: Save to local storage (SharedPreferences or GetStorage)
      final prefs = {
        'notificationsEnabled': _notificationsEnabled.value,
        'emailNotifications': _emailNotifications.value,
        'pushNotifications': _pushNotifications.value,
        'smsNotifications': _smsNotifications.value,
        'profilePublic': _profilePublic.value,
        'showEmail': _showEmail.value,
        'showPhone': _showPhone.value,
      };

      // await GetStorage().write('userPreferences', prefs);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  /// Load user preferences from local storage
  Future<void> _loadUserPreferences() async {
    try {
      // TODO: Load from local storage
      // final prefs = GetStorage().read('userPreferences');
      // if (prefs != null) {
      //   _notificationsEnabled.value = prefs['notificationsEnabled'] ?? true;
      //   ...
      // }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  /// Save favorites to Firestore
  Future<void> _saveFavorites() async {
    if (userId.isEmpty) return;

    try {
      await _userRepo.updateUserFields(userId, {
        'favorites': _favoriteHandymen.toList(),
      });
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  /// Show success message
  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: Duration(seconds: 2),
    );
  }

  /// Show error message
  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: Duration(seconds: 3),
    );
  }

  /// Clear user data
  void clearUser() {
    _currentUser.value = null;
    _profileCompletionPercentage.value = 0;
    _bookingsCount.value = 0;
    _reviewsCount.value = 0;
    _averageRating.value = 0.0;
    _favoriteHandymen.clear();
  }
}
