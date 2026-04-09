/// Core Utils - Validators
/// Comprehensive form validation functions
///
/// Usage:
/// validator: Validators.validateEmail
///
library;
import '../constants/app_strings.dart';

class Validators {
  Validators._(); // Private constructor

  // ==================== Email Validation ====================

  /// Validates email address
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.invalidEmail;
    }

    return null;
  }

  // ==================== Password Validation ====================

  /// Validates password (minimum 6 characters)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 6) {
      return AppStrings.invalidPassword;
    }

    return null;
  }

  /// Validates strong password
  /// Requirements: min 8 chars, uppercase, lowercase, number, special char
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Validates password confirmation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return AppStrings.passwordMismatch;
    }

    return null;
  }

  // ==================== Phone Validation ====================

  /// Validates phone number (basic)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    // Remove spaces, dashes, parentheses
    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it contains only digits and optional + at start
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleanedValue)) {
      return AppStrings.invalidPhone;
    }

    return null;
  }

  /// Validates Moroccan phone number
  static String? validateMoroccanPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Moroccan format: +212 6/7 XX XX XX XX or 06/07 XX XX XX XX
    final moroccanRegex = RegExp(r'^(\+212|0)[67][0-9]{8}$');

    if (!moroccanRegex.hasMatch(cleanedValue)) {
      return 'Please enter a valid Moroccan phone number';
    }

    return null;
  }

  // ==================== Name Validation ====================

  /// Validates full name
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }

    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }

    // Check for at least 2 words
    if (value.trim().split(' ').length < 2) {
      return 'Please enter your full name';
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s\-']+$").hasMatch(value)) {
      return 'Name can only contain letters';
    }

    return null;
  }

  /// Validates name (single word)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s\-']+$").hasMatch(value)) {
      return 'Name can only contain letters';
    }

    return null;
  }

  // ==================== Required Field Validation ====================

  /// Validates required field
  static String? validateRequired(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? 'Please enter $fieldName'
          : AppStrings.required;
    }
    return null;
  }

  /// Validates required field with minimum length
  static String? validateRequiredMinLength(
    String? value,
    int minLength, [
    String? fieldName,
  ]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? 'Please enter $fieldName'
          : AppStrings.required;
    }

    if (value.trim().length < minLength) {
      return fieldName != null
          ? '$fieldName must be at least $minLength characters'
          : 'Must be at least $minLength characters';
    }

    return null;
  }

  // ==================== Number Validation ====================

  /// Validates number
  static String? validateNumber(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? 'Please enter $fieldName'
          : AppStrings.required;
    }

    if (double.tryParse(value) == null) {
      return 'Please enter a valid number';
    }

    return null;
  }

  /// Validates positive number
  static String? validatePositiveNumber(String? value, [String? fieldName]) {
    final numberError = validateNumber(value, fieldName);
    if (numberError != null) return numberError;

    if (double.parse(value!) <= 0) {
      return 'Please enter a positive number';
    }

    return null;
  }

  /// Validates integer
  static String? validateInteger(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null
          ? 'Please enter $fieldName'
          : AppStrings.required;
    }

    if (int.tryParse(value) == null) {
      return 'Please enter a valid whole number';
    }

    return null;
  }

  // ==================== Price/Amount Validation ====================

  /// Validates price
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a price';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price <= 0) {
      return 'Price must be greater than 0';
    }

    if (price > 10000) {
      return 'Price seems too high';
    }

    return null;
  }

  /// Validates hourly rate
  static String? validateHourlyRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter hourly rate';
    }

    final rate = double.tryParse(value);
    if (rate == null) {
      return 'Please enter a valid rate';
    }

    if (rate < 50) {
      return 'Hourly rate must be at least 50 DH';
    }

    if (rate > 1000) {
      return 'Hourly rate seems too high';
    }

    return null;
  }

  // ==================== URL Validation ====================

  /// Validates URL
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a URL';
    }

    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  // ==================== Date Validation ====================

  /// Validates date (future)
  static String? validateFutureDate(DateTime? value) {
    if (value == null) {
      return 'Please select a date';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(value.year, value.month, value.day);

    if (selectedDate.isBefore(today)) {
      return 'Please select a future date';
    }

    return null;
  }

  /// Validates date (past)
  static String? validatePastDate(DateTime? value) {
    if (value == null) {
      return 'Please select a date';
    }

    final now = DateTime.now();
    if (value.isAfter(now)) {
      return 'Please select a past date';
    }

    return null;
  }

  // ==================== Text Length Validation ====================

  /// Validates minimum length
  static String? validateMinLength(
    String? value,
    int minLength, [
    String? fieldName,
  ]) {
    if (value == null || value.isEmpty) {
      return fieldName != null
          ? 'Please enter $fieldName'
          : AppStrings.required;
    }

    if (value.length < minLength) {
      return fieldName != null
          ? '$fieldName must be at least $minLength characters'
          : 'Must be at least $minLength characters';
    }

    return null;
  }

  /// Validates maximum length
  static String? validateMaxLength(
    String? value,
    int maxLength, [
    String? fieldName,
  ]) {
    if (value != null && value.length > maxLength) {
      return fieldName != null
          ? '$fieldName must not exceed $maxLength characters'
          : 'Must not exceed $maxLength characters';
    }

    return null;
  }

  /// Validates length range
  static String? validateLengthRange(
    String? value,
    int minLength,
    int maxLength, [
    String? fieldName,
  ]) {
    final minError = validateMinLength(value, minLength, fieldName);
    if (minError != null) return minError;

    return validateMaxLength(value, maxLength, fieldName);
  }

  // ==================== Special Validations ====================

  /// Validates username
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }

    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (value.length > 20) {
      return 'Username must not exceed 20 characters';
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    return null;
  }

  /// Validates rating (1-5)
  static String? validateRating(double? value) {
    if (value == null) {
      return 'Please provide a rating';
    }

    if (value < 1 || value > 5) {
      return 'Rating must be between 1 and 5';
    }

    return null;
  }

  /// Validates OTP code
  static String? validateOTP(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the OTP code';
    }

    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }

    return null;
  }

  // ==================== Combination Validators ====================

  /// Combines multiple validators
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
