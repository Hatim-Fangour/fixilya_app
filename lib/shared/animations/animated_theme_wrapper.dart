import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AnimatedThemeWrapper extends StatelessWidget {
  const AnimatedThemeWrapper({
    super.key,
    required this.isDarkMode,
    required this.child,
  });

  final bool isDarkMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.primaryColor,
      colorScheme: const ColorScheme.light(primary: AppColors.secondaryColor),
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F1115),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.secondaryColor,
        surface: Color(0xFF151922),
        background: Color(0xFF0F1115),
        onSurface: Color(0xFFE9ECF1),
        onSurfaceVariant: Color(0xFFB8BFCC),
        outlineVariant: Color(0xFF2A3140),
      ),
      dividerColor: const Color(0xFF2A3140),
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
    );

    return AnimatedTheme(
      data: isDarkMode ? darkTheme : lightTheme,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: child,
    );
  }
}
