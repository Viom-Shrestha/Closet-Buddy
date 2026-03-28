import 'package:flutter/material.dart';

import 'adaptive_color.dart';

/// Global semantic colors shared across the app.
class AppColors {
  const AppColors._();

  static const page = AdaptiveColor(
    lightValue: 0xFFFAF7F2,
    darkValue: 0xFF101114,
  );
  static const surface = AdaptiveColor(
    lightValue: 0xFFFFFFFF,
    darkValue: 0xFF17191F,
  );
  static const surfaceSoft = AdaptiveColor(
    lightValue: 0xFFF2EDE4,
    darkValue: 0xFF1A1C22,
  );
  static const textPrimary = AdaptiveColor(
    lightValue: 0xFF1A1714,
    darkValue: 0xFFF2F2F5,
  );
  static const textSecondary = AdaptiveColor(
    lightValue: 0xFF4A4540,
    darkValue: 0xFFCFCFD8,
  );
  static const textMuted = AdaptiveColor(
    lightValue: 0xFF9E9890,
    darkValue: 0xFF9C9DAA,
  );
  static const border = AdaptiveColor(
    lightValue: 0xFFE8E2D9,
    darkValue: 0xFF2B2D35,
  );
  static const accent = AdaptiveColor(
    lightValue: 0xFFB85C2E,
    darkValue: 0xFFD38762,
  );
  static const success = AdaptiveColor(
    lightValue: 0xFF10B981,
    darkValue: 0xFF34D399,
  );
  static const warning = AdaptiveColor(
    lightValue: 0xFFF59E0B,
    darkValue: 0xFFFBBF24,
  );
  static const danger = AdaptiveColor(
    lightValue: 0xFFEF4444,
    darkValue: 0xFFF87171,
  );
}

/// Canonical literal color registry.
///
/// Use these instead of inline `Color(0x...)` outside theme files.
class AppHexColors {
  const AppHexColors._();
  static const c00000000 = Color(0X00000000);
  static const cFF000000 = Color(0XFF000000);
  static const cFF06B6D4 = Color(0XFF06B6D4);
  static const cFF0EA5E9 = Color(0XFF0EA5E9);
  static const cFF0F0F0F = Color(0XFF0F0F0F);
  static const cFF101114 = Color(0XFF101114);
  static const cFF10B981 = Color(0XFF10B981);
  static const cFF111827 = Color(0XFF111827);
  static const cFF14B8A6 = Color(0XFF14B8A6);
  static const cFF15803D = Color(0XFF15803D);
  static const cFF16A34A = Color(0XFF16A34A);
  static const cFF1A1A1A = Color(0XFF1A1A1A);
  static const cFF1A1C22 = Color(0XFF1A1C22);
  static const cFF1E3A8A = Color(0XFF1E3A8A);
  static const cFF1F2937 = Color(0XFF1F2937);
  static const cFF222222 = Color(0XFF222222);
  static const cFF22C55E = Color(0XFF22C55E);
  static const cFF2563EB = Color(0XFF2563EB);
  static const cFF2A7FFF = Color(0XFF2A7FFF);
  static const cFF2B2D35 = Color(0XFF2B2D35);
  static const cFF2C3E6B = Color(0XFF2C3E6B);
  static const cFF2D7A4F = Color(0XFF2D7A4F);
  static const cFF374151 = Color(0XFF374151);
  static const cFF3B82F6 = Color(0XFF3B82F6);
  static const cFF3B8BD4 = Color(0XFF3B8BD4);
  static const cFF4B5563 = Color(0XFF4B5563);
  static const cFF5A8FA0 = Color(0XFF5A8FA0);
  static const cFF60A5FA = Color(0XFF60A5FA);
  static const cFF6366F1 = Color(0XFF6366F1);
  static const cFF64748B = Color(0XFF64748B);
  static const cFF65A30D = Color(0XFF65A30D);
  static const cFF68687A = Color(0XFF68687A);
  static const cFF6B7280 = Color(0XFF6B7280);
  static const cFF6EE7B7 = Color(0XFF6EE7B7);
  static const cFF7A8C5A = Color(0XFF7A8C5A);
  static const cFF7B5EA7 = Color(0XFF7B5EA7);
  static const cFF7B8FA0 = Color(0XFF7B8FA0);
  static const cFF7C2D12 = Color(0XFF7C2D12);
  static const cFF7DD3FC = Color(0XFF7DD3FC);
  static const cFF7F1D1D = Color(0XFF7F1D1D);
  static const cFF84CC16 = Color(0XFF84CC16);
  static const cFF888888 = Color(0XFF888888);
  static const cFF8B5CF6 = Color(0XFF8B5CF6);
  static const cFF8B6347 = Color(0XFF8B6347);
  static const cFF92400E = Color(0XFF92400E);
  static const cFF9E9E9E = Color(0XFF9E9E9E);
  static const cFF991B1B = Color(0XFF991B1B);
  static const cFF9A8F7F = Color(0XFF9A8F7F);
  static const cFF9B1C1C = Color(0XFF9B1C1C);
  static const cFF9CA3AF = Color(0XFF9CA3AF);
  static const cFFA84F5F = Color(0XFFA84F5F);
  static const cFFA855F7 = Color(0XFFA855F7);
  static const cFFB5854D = Color(0XFFB5854D);
  static const cFFB85C2E = Color(0XFFB85C2E);
  static const cFFBFB8AD = Color(0XFFBFB8AD);
  static const cFFC084FC = Color(0XFFC084FC);
  static const cFFC0C0C0 = Color(0XFFC0C0C0);
  static const cFFC2B280 = Color(0XFFC2B280);
  static const cFFC3B091 = Color(0XFFC3B091);
  static const cFFC94040 = Color(0XFFC94040);
  static const cFFC9A96E = Color(0XFFC9A96E);
  static const cFFCCC7C0 = Color(0XFFCCC7C0);
  static const cFFCD7F32 = Color(0XFFCD7F32);
  static const cFFD0CCC6 = Color(0XFFD0CCC6);
  static const cFFD1D5DB = Color(0XFFD1D5DB);
  static const cFFD2691E = Color(0XFFD2691E);
  static const cFFD4B896 = Color(0XFFD4B896);
  static const cFFD4C5A9 = Color(0XFFD4C5A9);
  static const cFFD5CFC6 = Color(0XFFD5CFC6);
  static const cFFD97706 = Color(0XFFD97706);
  static const cFFDC143C = Color(0XFFDC143C);
  static const cFFDC2626 = Color(0XFFDC2626);
  static const cFFDED6C8 = Color(0XFFDED6C8);
  static const cFFE5E7EB = Color(0XFFE5E7EB);
  static const cFFE0E0E0 = Color(0XFFE0E0E0);
  static const cFFEEEEEE = Color(0XFFEEEEEE);
  static const cFFE8843C = Color(0XFFE8843C);
  static const cFFE8A0B0 = Color(0XFFE8A0B0);
  static const cFFE8C547 = Color(0XFFE8C547);
  static const cFFE8E3DB = Color(0XFFE8E3DB);
  static const cFFEAB308 = Color(0XFFEAB308);
  static const cFFEC4899 = Color(0XFFEC4899);
  static const cFFEDE7DD = Color(0XFFEDE7DD);
  static const cFFEF4444 = Color(0XFFEF4444);
  static const cFFF0ECE5 = Color(0XFFF0ECE5);
  static const cFFF1EDE6 = Color(0XFFF1EDE6);
  static const cFFF2F2F5 = Color(0XFFF2F2F5);
  static const cFFF3F4F6 = Color(0XFFF3F4F6);
  static const cFFF43F5E = Color(0XFFF43F5E);
  static const cFFF44336 = Color(0XFFF44336);
  static const cFFF5F5F5 = Color(0XFFF5F5F5);
  static const cFFF59E0B = Color(0XFFF59E0B);
  static const cFFF5F2EE = Color(0XFFF5F2EE);
  static const cFFF5F7FB = Color(0XFFF5F7FB);
  static const cFFF7F5F2 = Color(0XFFF7F5F2);
  static const cFFF8F9FA = Color(0XFFF8F9FA);
  static const cFFF97316 = Color(0XFFF97316);
  static const cFFF9FAFB = Color(0XFFF9FAFB);
  static const cFFFACC15 = Color(0XFFFACC15);
  static const cFFFAEEF0 = Color(0XFFFAEEF0);
  static const cFFFAFAFA = Color(0XFFFAFAFA);
  static const cFFFAF8F5 = Color(0XFFFAF8F5);
  static const cFFFB923C = Color(0XFFFB923C);
  static const cFF64B5F6 = Color(0XFF64B5F6);
  static const cFF757575 = Color(0XFF757575);
  static const cFF2196F3 = Color(0XFF2196F3);
  static const cFF4CAF50 = Color(0XFF4CAF50);
  static const cFFE57373 = Color(0XFFE57373);
  static const cFFFCA5A5 = Color(0XFFFCA5A5);
  static const cFFFCFAF7 = Color(0XFFFCFAF7);
  static const cFFFDBA74 = Color(0XFFFDBA74);
  static const cFFFDECEC = Color(0XFFFDECEC);
  static const cFFFECACA = Color(0XFFFECACA);
  static const cFFFEE2E2 = Color(0XFFFEE2E2);
  static const cFFFEF2F2 = Color(0XFFFEF2F2);
  static const cFFFFFDD0 = Color(0XFFFFFDD0);
  static const cFFFFFFFF = Color(0XFFFFFFFF);
}
