/// Core Utils - Helpers
/// Utility functions for formatting, converting, and common operations
///
library;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class Helpers {
  Helpers._(); // Private constructor

  // ==================== String Helpers ====================

  /// Capitalizes first letter of string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Capitalizes first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  /// Truncates string with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Removes all whitespace
  static String removeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), '');
  }

  /// Get initials from name
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // ==================== Number Formatting ====================

  /// Format number with thousand separators
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// Format price in DH
  static String formatPrice(num price) {
    return '${formatNumber(price)} DH';
  }

  /// Format decimal to fixed places
  static String formatDecimal(double number, [int decimalPlaces = 2]) {
    return number.toStringAsFixed(decimalPlaces);
  }

  /// Format percentage
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  // ==================== Date/Time Formatting ====================

  /// Format date to readable string (e.g., "Jan 15, 2026")
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Format time (e.g., "10:30 AM")
  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  /// Format date and time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(dateTime);
  }

  /// Format relative time (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  // ==================== Phone Formatting ====================

  /// Format phone number (Moroccan style)
  static String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+212')) {
      return '+212 ${cleaned.substring(4, 5)} ${cleaned.substring(5, 7)} ${cleaned.substring(7, 9)} ${cleaned.substring(9, 11)} ${cleaned.substring(11)}';
    } else if (cleaned.startsWith('0')) {
      return '0${cleaned.substring(1, 2)} ${cleaned.substring(2, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8)}';
    }

    return phone;
  }

  // ==================== Validation Helpers ====================

  /// Check if email is valid
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Check if phone is valid
  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleaned);
  }

  /// Check if URL is valid
  static bool isValidUrl(String url) {
    return RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    ).hasMatch(url);
  }

  // ==================== List Helpers ====================

  /// Check if list is null or empty
  static bool isNullOrEmpty(List? list) {
    return list == null || list.isEmpty;
  }

  /// Get unique items from list
  static List<T> unique<T>(List<T> list) {
    return list.toSet().toList();
  }

  /// Chunk list into smaller lists
  static List<List<T>> chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(
        list.sublist(i, i + size > list.length ? list.length : i + size),
      );
    }
    return chunks;
  }

  // ==================== Map Helpers ====================

  /// Check if map is null or empty
  static bool isMapNullOrEmpty(Map? map) {
    return map == null || map.isEmpty;
  }

  // ==================== Color Helpers ====================

  /// Convert hex string to Color
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// Convert Color to hex string
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }

  // ==================== Size Helpers ====================

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // ==================== Rating Helpers ====================

  /// Format rating (e.g., "4.8" or "5.0")
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  /// Get star rating text
  static String getStarRating(double rating, int reviews) {
    return '${formatRating(rating)} ⭐ ($reviews reviews)';
  }

  // ==================== Distance Helpers ====================

  /// Format distance in km
  static String formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  // ==================== URL Helpers ====================

  /// Encode URL parameters
  static String encodeUrlParams(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  /// Build URL with parameters
  static String buildUrl(String baseUrl, Map<String, String> params) {
    if (params.isEmpty) return baseUrl;
    return '$baseUrl?${encodeUrlParams(params)}';
  }

  // ==================== Comparison Helpers ====================

  /// Compare versions (e.g., "1.2.3" vs "1.2.4")
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (var i = 0; i < parts1.length && i < parts2.length; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }

    return parts1.length.compareTo(parts2.length);
  }

  // ==================== Random Helpers ====================

  /// Generate random string
  static String randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      length,
      (index) => chars[(random + index) % chars.length],
    ).join();
  }

  // ==================== Delay Helper ====================

  /// Delay execution
  static Future<void> delay(Duration duration) {
    return Future.delayed(duration);
  }

  /// Debounce function calls
  static Function debounce(Function func, Duration delay) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(delay, () => func());
    };
  }
}
