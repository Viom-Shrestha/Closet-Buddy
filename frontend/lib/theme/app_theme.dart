import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'adaptive_color.dart';
export 'admin_tokens.dart';
export 'auth_tokens.dart';
export 'app_colors.dart';
export 'named_colors.dart';
export 'recommendation_tokens.dart';
export 'screen_palettes.dart';
export 'screen_tokens.dart';
export 'storage_tokens.dart';
export 'theme_service.dart';
export 'upload_tokens.dart';
export 'wardrobe_tokens.dart';
export 'widget_tokens.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppHexColors.cFF2A7FFF),
    scaffoldBackgroundColor: AppHexColors.cFFF5F7FB,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppHexColors.c00000000,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppHexColors.cFF000000,
      ),
      iconTheme: IconThemeData(color: AppHexColors.cFF000000),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppHexColors.cFFFFFFFF,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.page,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppHexColors.c00000000,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppHexColors.cFFF2F2F5,
      ),
      iconTheme: IconThemeData(color: AppHexColors.cFFF2F2F5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppHexColors.cFF1A1C22,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppHexColors.cFF2B2D35),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppHexColors.cFF2B2D35),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppHexColors.cFFB85C2E),
      ),
    ),
  );
}
