import 'app_colors.dart';
import 'adaptive_color.dart';
import 'screen_palettes.dart';

/// Screen-specific semantic tokens.
///
/// Keep per-screen color aliases here so UI files stay focused on layout and
/// behavior.
class AddItemTokens {
  const AddItemTokens._();

  static const pageBg = NeutralPalette.page;
  static const surface = NeutralPalette.paper;
  static const ink = NeutralPalette.ink;
  static const muted = NeutralPalette.inkMuted;
  static const line = NeutralPalette.line;

  // Compatibility aliases while migrating UI files away from hex-style tokens.
  static const black = AppHexColors.cFF000000;
  static const success = NeutralPalette.success;
  static const info = NeutralPalette.info;
  static const purple = AdaptiveColor(
    lightValue: 0xFF8B5CF6,
    darkValue: 0xFFC084FC,
  );
  static const mutedSoft = AdaptiveColor(
    lightValue: 0xFF9CA3AF,
    darkValue: 0xFF68687A,
  );
  static const surfaceSoft = NeutralPalette.lineSoft;
  static const warning = NeutralPalette.warning;
}

class HomeTokens {
  const HomeTokens._();

  static const cream = EditorialPalette.cream;
  static const parchment = EditorialPalette.parchment;
  static const card = EditorialPalette.card;
  static const ink = EditorialPalette.ink;
  static const inkSub = EditorialPalette.inkSub;
  static const inkMuted = EditorialPalette.inkMuted;
  static const rule = EditorialPalette.rule;
  static const accent = EditorialPalette.accent;
  static const accentBg = EditorialPalette.accentBg;
  static const gold = EditorialPalette.gold;
  static const goldBg = EditorialPalette.goldBg;
  static const sage = EditorialPalette.sage;
  static const sageBg = EditorialPalette.sageBg;
  static const sky = EditorialPalette.sky;
  static const skyBg = EditorialPalette.skyBg;

  // Compatibility aliases while migrating UI files away from hex-style tokens.
  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const skyMuted = AdaptiveColor(
    lightValue: 0xFF5A8FA0,
    darkValue: 0xFF7CAEE6,
  );
  static const skySoft = AdaptiveColor(
    lightValue: 0xFF7B8FA0,
    darkValue: 0xFF93B4D3,
  );
  static const rose = EditorialPalette.rose;
  static const roseBg = AdaptiveColor(
    lightValue: 0xFFFAEEF0,
    darkValue: 0xFF2E1F27,
  );
  static const white = AppHexColors.cFFFFFFFF;
}

class ProfileTokens {
  const ProfileTokens._();

  static const cream = EditorialPalette.cream;
  static const parchment = EditorialPalette.parchment;
  static const card = EditorialPalette.card;
  static const ink = EditorialPalette.ink;
  static const inkSub = EditorialPalette.inkSub;
  static const inkMuted = EditorialPalette.inkMuted;
  static const rule = EditorialPalette.rule;
  static const accent = EditorialPalette.accent;
  static const accentBg = EditorialPalette.accentBg;
  static const gold = EditorialPalette.gold;
  static const goldBg = EditorialPalette.goldBg;
  static const sage = EditorialPalette.sage;
  static const sageBg = EditorialPalette.sageBg;
  static const rose = EditorialPalette.rose;
  static const sky = EditorialPalette.sky;
  static const danger = EditorialPalette.danger;
  static const dangerBg = EditorialPalette.dangerBg;

  // Compatibility aliases while migrating UI files away from hex-style tokens.
  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const white = AppHexColors.cFFFFFFFF;
}

class OutfitTokens {
  const OutfitTokens._();

  static const bg = OutfitPalette.bg;
  static const surface = OutfitPalette.surface;
  static const ink = OutfitPalette.ink;
  static const muted = OutfitPalette.muted;
  static const border = OutfitPalette.border;
  static const accent = OutfitPalette.accent;
  static const tagBg = OutfitPalette.tagBg;
  static const heroStart = AdaptiveColor(
    lightValue: 0xFF8C3E18,
    darkValue: 0xFF2F343D,
  );
  static const heroEnd = AdaptiveColor(
    lightValue: 0xFFB85C2E,
    darkValue: 0xFF252830,
  );
  static const onHero = AdaptiveColor(
    lightValue: 0xFFFFFFFF,
    darkValue: 0xFFF2F2F5,
  );
  static const onHeroMuted = AdaptiveColor(
    lightValue: 0xFFF7DED0,
    darkValue: 0xFFAEAEB8,
  );

  // Compatibility aliases while migrating UI files away from hex-style tokens.
  static const black = AppHexColors.cFF000000;
  static const inkStrong = AdaptiveColor(
    lightValue: 0xFF111827,
    darkValue: 0xFF2F343D,
  );
  static const inkStrongAlt = AdaptiveColor(
    lightValue: 0xFF1F2937,
    darkValue: 0xFF252830,
  );
  static const slate = EditorialPalette.inkSub;
  static const mutedSoft = EditorialPalette.inkMuted;
  static const lineQuiet = AdaptiveColor(
    lightValue: 0xFFD1D5DB,
    darkValue: 0xFFAEAEB8,
  );
  static const danger = AdaptiveColor(
    lightValue: 0xFFDC2626,
    darkValue: 0xFFF87171,
  );
  static const line = OutfitPalette.border;
  static const tagBgSoft = OutfitPalette.tagBg;
  static const dangerStrong = AdaptiveColor(
    lightValue: 0xFFF44336,
    darkValue: 0xFFF87171,
  );
  static const warning = NeutralPalette.warning;
  static const surfaceWarm = OutfitPalette.surfaceStrong;
  static const white = AppHexColors.cFFFFFFFF;
}

class ClothingDetailTokens {
  const ClothingDetailTokens._();

  static const bg = OutfitPalette.bg;
  static const surface = OutfitPalette.surface;
  static const card = OutfitPalette.surface;
  static const surfaceStrong = OutfitPalette.surfaceStrong;
  static const border = OutfitPalette.border;
  static const borderBright = OutfitPalette.borderBright;
  static const text = OutfitPalette.ink;
  static const textSub = NeutralPalette.inkMuted;
  static const textMuted = OutfitPalette.muted;
  static const accent = OutfitPalette.accent;
  static const accentDeep = OutfitPalette.accentDeep;
  static const danger = AdaptiveColor(
    lightValue: 0xFFDC2626,
    darkValue: 0xFFF87171,
  );
  static const dangerBg = AdaptiveColor(
    lightValue: 0xFFFDECEC,
    darkValue: 0xFF2E1A1A,
  );
  static const success = AdaptiveColor(
    lightValue: 0xFF16A34A,
    darkValue: 0xFF34D399,
  );

  // Compatibility aliases while migrating UI files away from hex-style tokens.
  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const info = NeutralPalette.info;
  static const white = AppHexColors.cFFFFFFFF;
}

class OutfitCanvasTokens {
  const OutfitCanvasTokens._();

  static const bg = AdaptiveColor(
    lightValue: 0xFFF7F5F2,
    darkValue: 0xFF1E2128,
  );
  static const cardBg = AdaptiveColor(
    lightValue: 0xFFFCFAF7,
    darkValue: 0xFF262A33,
  );
  static const border = OutfitPalette.border;
  static const emptyBorder = OutfitPalette.borderBright;
  static const labelBg = AdaptiveColor(
    lightValue: 0xFFFAF8F5,
    darkValue: 0xFF1E222A,
  );
  static const categoryText = OutfitPalette.muted;
  static const ink = OutfitPalette.ink;

  // Compatibility aliases while migrating UI files away from hex-style tokens.
  static const transparent = AppHexColors.c00000000;
  static const iconMuted = AdaptiveColor(
    lightValue: 0xFFCCC7C0,
    darkValue: 0xFF68687A,
  );
  static const borderWarm = OutfitPalette.borderBright;
  static const white = AppHexColors.cFFFFFFFF;
}
