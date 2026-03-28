import 'app_colors.dart';
import 'adaptive_color.dart';
import 'screen_palettes.dart';

/// Recommendation flow tokens.
class RecommendationTokens {
  const RecommendationTokens._();

  static const black = AppHexColors.cFF000000;
  static const success = NeutralPalette.success;
  static const inkStrong = NeutralPalette.inkStrong;
  static const ink = NeutralPalette.ink;
  static const slateSoft = AdaptiveColor(
    lightValue: 0xFF4B5563,
    darkValue: 0xFFAEAEB8,
  );
  static const muted = NeutralPalette.inkMuted;
  static const dangerDeep = AdaptiveColor(
    lightValue: 0xFF991B1B,
    darkValue: 0xFFFCA5A5,
  );
  static const mutedSoft = AdaptiveColor(
    lightValue: 0xFF9CA3AF,
    darkValue: 0xFF68687A,
  );
  static const line = NeutralPalette.line;
  static const surfaceSoft = NeutralPalette.lineSoft;
  static const warning = NeutralPalette.warning;
  static const pageBg = NeutralPalette.page;
  static const surfaceAlt = AdaptiveColor(
    lightValue: 0xFFF9FAFB,
    darkValue: 0xFF1E222A,
  );
  static const alertSoft = AdaptiveColor(
    lightValue: 0xFFFCA5A5,
    darkValue: 0xFF7F1D1D,
  );
  static const alertBg = AdaptiveColor(
    lightValue: 0xFFFEE2E2,
    darkValue: 0xFF2A1515,
  );
  static const surface = NeutralPalette.paper;
}
