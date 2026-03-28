import 'app_colors.dart';
import 'adaptive_color.dart';
import 'screen_palettes.dart';

/// Wardrobe and outfit preview tokens.
class WardrobeTokens {
  const WardrobeTokens._();

  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const analyticsStart = AdaptiveColor(
    lightValue: 0xFF8C3E18,
    darkValue: 0xFF2F343D,
  );
  static const analyticsEnd = AdaptiveColor(
    lightValue: 0xFFB85C2E,
    darkValue: 0xFF252830,
  );
  static const onAnalytics = AdaptiveColor(
    lightValue: 0xFFFFFFFF,
    darkValue: 0xFFF2F2F5,
  );
  static const inkDeep = OutfitPalette.ink;
  static const inkStrong = NeutralPalette.inkStrong;
  static const success = AdaptiveColor(
    lightValue: 0xFF16A34A,
    darkValue: 0xFF34D399,
  );
  static const inkStrongAlt = AdaptiveColor(
    lightValue: 0xFF1F2937,
    darkValue: 0xFFD1D5DB,
  );
  static const blue = AdaptiveColor(
    lightValue: 0xFF2563EB,
    darkValue: 0xFF60A5FA,
  );
  static const blueSoft = AdaptiveColor(
    lightValue: 0xFF64B5F6,
    darkValue: 0xFF93C5FD,
  );
  static const muted = OutfitPalette.muted;
  static const grayMid = AdaptiveColor(
    lightValue: 0xFF757575,
    darkValue: 0xFF9CA3AF,
  );
  static const mutedSoft = EditorialPalette.inkMuted;
  static const gray = EditorialPalette.inkMuted;
  static const lineQuiet = OutfitPalette.borderBright;
  static const danger = AdaptiveColor(
    lightValue: 0xFFDC2626,
    darkValue: 0xFFF87171,
  );
  static const lineLight = AdaptiveColor(
    lightValue: 0xFFDED6C8,
    darkValue: 0xFF3A3A42,
  );
  static const redSoft = AdaptiveColor(
    lightValue: 0xFFE57373,
    darkValue: 0xFFFCA5A5,
  );
  static const line = OutfitPalette.border;
  static const borderWarm = OutfitPalette.border;
  static const dangerSoft = NeutralPalette.danger;
  static const surfaceSoft = OutfitPalette.surfaceStrong;
  static const dangerStrong = AdaptiveColor(
    lightValue: 0xFFF44336,
    darkValue: 0xFFF87171,
  );
  static const warning = NeutralPalette.warning;
  static const pageWarm = OutfitPalette.bg;
  static const surfaceAlt = AdaptiveColor(
    lightValue: 0xFFF5F2EE,
    darkValue: 0xFF1E222A,
  );
  static const dangerPale = AdaptiveColor(
    lightValue: 0xFFFECACA,
    darkValue: 0xFF7F1D1D,
  );
  static const dangerBg = AdaptiveColor(
    lightValue: 0xFFFEF2F2,
    darkValue: 0xFF2E1A1A,
  );
  static const surface = OutfitPalette.surface;
}
