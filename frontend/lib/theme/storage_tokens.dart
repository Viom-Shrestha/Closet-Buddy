import 'app_colors.dart';
import 'adaptive_color.dart';
import 'screen_palettes.dart';

/// Storage flow tokens (detail, selector, and space screens).
class StorageTokens {
  const StorageTokens._();

  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const analyticsStart = AdaptiveColor(
    lightValue: 0xFF1A1714,
    darkValue: 0xFF2F343D,
  );
  static const analyticsEnd = AdaptiveColor(
    lightValue: 0xFF4A4540,
    darkValue: 0xFF252830,
  );
  static const onAnalytics = AdaptiveColor(
    lightValue: 0xFFFFFFFF,
    darkValue: 0xFFF2F2F5,
  );
  static const success = NeutralPalette.success;
  static const inkStrong = NeutralPalette.inkStrong;
  static const teal = AdaptiveColor(
    lightValue: 0xFF14B8A6,
    darkValue: 0xFF2DD4BF,
  );
  static const ink = NeutralPalette.ink;
  static const blue = NeutralPalette.info;
  static const blueStrong = AdaptiveColor(
    lightValue: 0xFF2563EB,
    darkValue: 0xFF60A5FA,
  );
  static const slate = EditorialPalette.inkSub;
  static const slateSoft = EditorialPalette.inkMuted;
  static const green = AdaptiveColor(
    lightValue: 0xFF4CAF50,
    darkValue: 0xFF6EE7B7,
  );
  static const steel = AdaptiveColor(
    lightValue: 0xFF7B8FA0,
    darkValue: 0xFF9CA3AF,
  );
  static const muted = EditorialPalette.inkSub;
  static const purple = AdaptiveColor(
    lightValue: 0xFF8B5CF6,
    darkValue: 0xFFC084FC,
  );
  static const mutedSoft = EditorialPalette.inkMuted;
  static const gray = EditorialPalette.inkMuted;
  static const lineQuiet = OutfitPalette.borderBright;
  static const lineLight = AdaptiveColor(
    lightValue: 0xFFDED6C8,
    darkValue: 0xFF3A3A42,
  );
  static const line = OutfitPalette.border;
  static const pink = AdaptiveColor(
    lightValue: 0xFFEC4899,
    darkValue: 0xFFF472B6,
  );
  static const lineSoft = NeutralPalette.lineSoft;
  static const danger = NeutralPalette.danger;
  static const surfaceSoft = OutfitPalette.surfaceStrong;
  static const dangerStrong = AdaptiveColor(
    lightValue: 0xFFF44336,
    darkValue: 0xFFF87171,
  );
  static const warning = NeutralPalette.warning;
  static const surfaceTint = AdaptiveColor(
    lightValue: 0xFFF5F2EE,
    darkValue: 0xFF1A1C22,
  );
  static const pageBg = EditorialPalette.cream;
  static const surfaceAlt = AdaptiveColor(
    lightValue: 0xFFFCFAF7,
    darkValue: 0xFF1E1E22,
  );
  static const surface = OutfitPalette.surface;
}
