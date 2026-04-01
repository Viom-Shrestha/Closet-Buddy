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
    visualDensity: VisualDensity.standard,
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

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppHexColors.cFFE8E3DB),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppHexColors.cFFFFFFFF,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppHexColors.cFFE8E3DB),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppHexColors.cFFFFFFFF,
      contentTextStyle: const TextStyle(
        color: AppHexColors.cFF1A1A1A,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppHexColors.cFFE8E3DB),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppHexColors.cFFFFFFFF,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppHexColors.cFFE8E3DB,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: const ListTileThemeData(
      dense: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    chipTheme: const ChipThemeData(
      shape: StadiumBorder(),
      side: BorderSide(color: AppHexColors.cFFE8E3DB),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppHexColors.cFF1A1A1A,
      ),
      backgroundColor: AppHexColors.cFFF7F5F2,
      selectedColor: AppHexColors.cFFB85C2E,
      secondarySelectedColor: AppHexColors.cFFB85C2E,
      disabledColor: AppHexColors.cFFF3F4F6,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      brightness: Brightness.light,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      type: BottomNavigationBarType.fixed,
    ),
  );

  static ThemeData darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
    visualDensity: VisualDensity.standard,
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

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppHexColors.cFF2B2D35),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppHexColors.cFF1A1C22,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppHexColors.cFF2B2D35),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppHexColors.cFF1A1C22,
      contentTextStyle: const TextStyle(
        color: AppHexColors.cFFF2F2F5,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppHexColors.cFF2B2D35),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppHexColors.cFF1A1C22,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppHexColors.cFF2B2D35,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: const ListTileThemeData(
      dense: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    chipTheme: const ChipThemeData(
      shape: StadiumBorder(),
      side: BorderSide(color: AppHexColors.cFF2B2D35),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppHexColors.cFFF2F2F5,
      ),
      backgroundColor: AppHexColors.cFF1A1C22,
      selectedColor: AppHexColors.cFFB85C2E,
      secondarySelectedColor: AppHexColors.cFFB85C2E,
      disabledColor: AppHexColors.cFF2B2D35,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      brightness: Brightness.dark,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      type: BottomNavigationBarType.fixed,
    ),
  );
}
