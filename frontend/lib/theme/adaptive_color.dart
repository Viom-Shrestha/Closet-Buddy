import 'dart:ui' show ColorSpace;

import 'package:flutter/material.dart';

enum AppPaletteMode { light, dark }

/// Theme-aware constant color that can be used inside const widget trees.
class AdaptiveColor extends Color {
  const AdaptiveColor({required this.lightValue, required this.darkValue})
    : super(lightValue);

  final int lightValue;
  final int darkValue;

  static AppPaletteMode _mode = AppPaletteMode.light;

  static void setMode(AppPaletteMode mode) {
    _mode = mode;
  }

  static bool get isDark => _mode == AppPaletteMode.dark;

  Color get _active => Color(isDark ? darkValue : lightValue);

  @override
  double get a => _active.a;

  @override
  double get r => _active.r;

  @override
  double get g => _active.g;

  @override
  double get b => _active.b;

  @override
  ColorSpace get colorSpace => _active.colorSpace;

  @override
  int get value => _active.toARGB32();
}

void setAdaptiveMode(AppPaletteMode mode) {
  AdaptiveColor.setMode(mode);
}

bool get isAdaptiveDarkMode => AdaptiveColor.isDark;
