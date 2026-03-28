import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adaptive_color.dart';

class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const _themeModeKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  bool get isDark => themeMode.value == ThemeMode.dark;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey) ?? 'light';
    final mode = raw == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _applyMode(mode);
  }

  Future<void> toggle() async {
    await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    _applyMode(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  void _applyMode(ThemeMode mode) {
    setAdaptiveMode(
      mode == ThemeMode.dark ? AppPaletteMode.dark : AppPaletteMode.light,
    );
    themeMode.value = mode;
  }
}
