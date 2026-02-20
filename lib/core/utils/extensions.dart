import 'package:flutter/material.dart';

/// String Extensions
extension StringExtensions on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);

  String capitalizeWords() =>
      split(' ').map((word) => word.capitalize()).join(' ');

  bool get isValidEmail => RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  ).hasMatch(this);

  bool get isValidPhone {
    final cleaned = replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleaned);
  }

  String truncate(int maxLength) =>
      length <= maxLength ? this : '${substring(0, maxLength)}...';

  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');
}

/// DateTime Extensions
extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }
}

/// List Extensions
extension ListExtensions<T> on List<T> {
  bool get isNullOrEmpty => isEmpty;

  List<T> get unique => toSet().toList();

  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// Color Extensions
extension ColorExtensions on Color {
  String get toHex => '#${value.toRadixString(16).substring(2)}';
}

/// BuildContext Extensions
extension ContextExtensions on BuildContext {
  // Navigation
  void pop() => Navigator.of(this).pop();
  Future<T?> push<T>(Widget page) =>
      Navigator.of(this).push(MaterialPageRoute(builder: (_) => page));
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) =>
      Navigator.of(this).pushNamed(routeName, arguments: arguments);

  // Theme
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // MediaQuery
  Size get size => MediaQuery.of(this).size;
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;

  // SnackBar
  void showSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
  }
}
