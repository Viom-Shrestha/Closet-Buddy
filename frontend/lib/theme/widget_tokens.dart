import 'app_colors.dart';
import 'adaptive_color.dart';
import 'screen_palettes.dart';

/// Shared widget tokens.
class WidgetTokens {
  const WidgetTokens._();

  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const ink = OutfitPalette.ink;
  static const mutedWarm = OutfitPalette.muted;
  static const borderWarmSoft = OutfitPalette.borderBright;
  static const accent = OutfitPalette.accent;
  static const iconMuted = AdaptiveColor(
    lightValue: 0xFFCCC7C0,
    darkValue: 0xFF68687A,
  );
  static const borderWarm = OutfitPalette.border;
  static const lineWarm = OutfitPalette.border;
  static const surfaceWarm = AdaptiveColor(
    lightValue: 0xFFF7F5F2,
    darkValue: 0xFF1E2128,
  );
  static const surface = OutfitPalette.surface;
}
