import 'app_colors.dart';
import 'adaptive_color.dart';
import 'screen_palettes.dart';

/// Authentication flow tokens (login/register/loading).
class AuthTokens {
  const AuthTokens._();

  static const transparent = AppHexColors.c00000000;
  static const black = AppHexColors.cFF000000;
  static const success = NeutralPalette.success;
  static const ink = NeutralPalette.ink;
  static const muted = NeutralPalette.inkMuted;
  static const mutedSoft = AdaptiveColor(
    lightValue: 0xFF9CA3AF,
    darkValue: 0xFF68687A,
  );
  static const line = NeutralPalette.line;
  static const danger = NeutralPalette.danger;
  static const dangerStrong = AdaptiveColor(
    lightValue: 0xFFF44336,
    darkValue: 0xFFF87171,
  );
  static const pageBg = NeutralPalette.page;
  static const surface = NeutralPalette.paper;
}
