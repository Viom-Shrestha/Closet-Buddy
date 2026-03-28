import 'adaptive_color.dart';
import 'screen_palettes.dart';

enum AdminThemeMode { light, dark }

void setAdminThemeMode(AdminThemeMode mode) {
  setAdaptiveMode(
    mode == AdminThemeMode.dark ? AppPaletteMode.dark : AppPaletteMode.light,
  );
}

bool get isAdminDarkTheme => isAdaptiveDarkMode;

// Backgrounds (light palette mirrors HomeScreen's warm editorial style)
const kAdminBg = AdminPalette.bg;
const kAdminSurface = AdminPalette.surface;
const kAdminSurface2 = AdminPalette.surface2;
const kAdminSurface3 = AdminPalette.surface3;

// Borders
const kAdminBorder = AdminPalette.border;
const kAdminBorderBright = AdminPalette.borderBright;

// Text
const kAdminText = AdminPalette.text;
const kAdminTextMuted = AdminPalette.textMuted;
const kAdminTextDim = AdminPalette.textDim;

// Accent - terracotta in light mode, lavender in dark mode
const kAdminAccent = AdminPalette.accent;
const kAdminAccentDim = AdminPalette.accentDim;
const kAdminAccentDeep = AdminPalette.accentDeep;

// Semantic colors
const kAdminBlue = AdminPalette.blue;
const kAdminBlueDim = AdminPalette.blueDim;

const kAdminGreen = AdminPalette.green;
const kAdminGreenDim = AdminPalette.greenDim;

const kAdminRed = AdminPalette.red;
const kAdminRedDim = AdminPalette.redDim;

const kAdminYellow = AdminPalette.yellow;
const kAdminYellowDim = AdminPalette.yellowDim;

// Exact-value neutral aliases used by admin-related UI files.
const kAdminNeutralMuted = AdminPalette.textMuted;
const kAdminNeutralSoft = AdminPalette.surface2;
const kAdminBlack = AdaptiveColor(lightValue: 0xFF000000, darkValue: 0xFFF0F0F5);
const kAdminWhite = AdaptiveColor(lightValue: 0xFFFFFFFF, darkValue: 0xFFF2F2F5);
