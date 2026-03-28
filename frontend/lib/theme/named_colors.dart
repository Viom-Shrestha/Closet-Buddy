import 'package:flutter/material.dart';

import 'app_colors.dart';

class NamedColors {
  const NamedColors._();

  /// Shared named colors used by admin widgets and clothing detail surfaces.
  static const material = <String, Color>{
    'red': AppHexColors.cFFEF4444,
    'blue': AppHexColors.cFF3B82F6,
    'green': AppHexColors.cFF22C55E,
    'yellow': AppHexColors.cFFFACC15,
    'orange': AppHexColors.cFFF97316,
    'purple': AppHexColors.cFFA855F7,
    'pink': AppHexColors.cFFEC4899,
    'brown': AppHexColors.cFF92400E,
    'black': AppHexColors.cFF6B7280,
    'white': AppHexColors.cFFD1D5DB,
    'grey': AppHexColors.cFF9CA3AF,
    'gray': AppHexColors.cFF9CA3AF,
    'beige': AppHexColors.cFFD4B896,
    'navy': AppHexColors.cFF1E3A8A,
    'teal': AppHexColors.cFF14B8A6,
    'maroon': AppHexColors.cFF9B1C1C,
    'olive': AppHexColors.cFF6B7280,
    'cream': AppHexColors.cFFD4C5A9,
    'khaki': AppHexColors.cFFC2B280,
    'indigo': AppHexColors.cFF6366F1,
  };

  /// Named colors used by outfit canvas and recommendation color dots.
  static const outfit = <String, Color>{
    'navy': AppHexColors.cFF2C3E6B,
    'blue': AppHexColors.cFF3B8BD4,
    'black': AppHexColors.cFF222222,
    'white': AppHexColors.cFFD0CCC6,
    'grey': AppHexColors.cFF888888,
    'gray': AppHexColors.cFF888888,
    'olive': AppHexColors.cFF7A8C5A,
    'green': AppHexColors.cFF2D7A4F,
    'red': AppHexColors.cFFC94040,
    'brown': AppHexColors.cFF8B6347,
    'tan': AppHexColors.cFFC9A96E,
    'beige': AppHexColors.cFFD4B896,
    'pink': AppHexColors.cFFE8A0B0,
    'purple': AppHexColors.cFF7B5EA7,
    'yellow': AppHexColors.cFFE8C547,
    'orange': AppHexColors.cFFE8843C,
    'cream': AppHexColors.cFFEDE7DD,
  };

  /// Broad name map for wardrobe and storage filtering.
  static const wardrobe = <String, Color>{
    'black': AppHexColors.cFF000000,
    'white': AppHexColors.cFFFFFFFF,
    'gray': AppHexColors.cFF9CA3AF,
    'grey': AppHexColors.cFF9CA3AF,
    'red': AppHexColors.cFFEF4444,
    'maroon': AppHexColors.cFF7F1D1D,
    'burgundy': AppHexColors.cFF7C2D12,
    'crimson': AppHexColors.cFFDC143C,
    'pink': AppHexColors.cFFEC4899,
    'rose': AppHexColors.cFFF43F5E,
    'blue': AppHexColors.cFF3B82F6,
    'navy': AppHexColors.cFF1E3A8A,
    'royal blue': AppHexColors.cFF2563EB,
    'sky blue': AppHexColors.cFF0EA5E9,
    'light blue': AppHexColors.cFF7DD3FC,
    'turquoise': AppHexColors.cFF06B6D4,
    'teal': AppHexColors.cFF14B8A6,
    'cyan': AppHexColors.cFF06B6D4,
    'green': AppHexColors.cFF22C55E,
    'forest green': AppHexColors.cFF15803D,
    'lime': AppHexColors.cFF84CC16,
    'olive': AppHexColors.cFF65A30D,
    'mint': AppHexColors.cFF6EE7B7,
    'yellow': AppHexColors.cFFEAB308,
    'gold': AppHexColors.cFFD97706,
    'orange': AppHexColors.cFFF97316,
    'coral': AppHexColors.cFFFB923C,
    'peach': AppHexColors.cFFFDBA74,
    'purple': AppHexColors.cFFA855F7,
    'violet': AppHexColors.cFF8B5CF6,
    'lavender': AppHexColors.cFFC084FC,
    'indigo': AppHexColors.cFF6366F1,
    'brown': AppHexColors.cFF92400E,
    'tan': AppHexColors.cFFD2691E,
    'beige': AppHexColors.cFFD4B896,
    'cream': AppHexColors.cFFFFFDD0,
    'khaki': AppHexColors.cFFC3B091,
    'silver': AppHexColors.cFFC0C0C0,
    'bronze': AppHexColors.cFFCD7F32,
  };
}

Color? matchNamedColor(Map<String, Color> map, String raw) {
  final value = raw.toLowerCase().trim();
  final direct = map[value];
  if (direct != null) {
    return direct;
  }
  for (final entry in map.entries) {
    if (value.contains(entry.key) || entry.key.contains(value)) {
      return entry.value;
    }
  }
  return null;
}
