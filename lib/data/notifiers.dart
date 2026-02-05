import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

// ValueNotifier<int> pageIndexNotifier = ValueNotifier(0);
// ValueNotifier<int> selectedPageNotifier = ValueNotifier(1);
// ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

final _box = GetStorage();

const _darkKey = 'isDarkMode';

// Load saved value at app start (default false)
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(
  _box.read(_darkKey) ?? false,
);

final ValueNotifier<int> selectedPageNotifier = ValueNotifier(1);

// Helper to toggle + persist
void toggleDarkMode() {
  final newValue = !isDarkModeNotifier.value;
  isDarkModeNotifier.value = newValue;
  _box.write(_darkKey, newValue);
}
