import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/theme/adaptive_color.dart';
import 'package:frontend/theme/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    setAdaptiveMode(AppPaletteMode.light);
    ThemeService.instance.themeMode.value = ThemeMode.light;
    await ThemeService.instance.initialize();
  });

  test('toggle flips theme mode and adaptive mode', () async {
    expect(ThemeService.instance.themeMode.value, ThemeMode.light);
    expect(isAdaptiveDarkMode, isFalse);

    await ThemeService.instance.toggle();

    expect(ThemeService.instance.themeMode.value, ThemeMode.dark);
    expect(isAdaptiveDarkMode, isTrue);
  });

  test('selected mode persists and reloads on initialize', () async {
    await ThemeService.instance.setMode(ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode'), 'dark');

    ThemeService.instance.themeMode.value = ThemeMode.light;
    setAdaptiveMode(AppPaletteMode.light);

    await ThemeService.instance.initialize();

    expect(ThemeService.instance.themeMode.value, ThemeMode.dark);
    expect(isAdaptiveDarkMode, isTrue);
  });
}
