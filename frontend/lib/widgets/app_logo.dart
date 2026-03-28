import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool darkBackground;

  const AppLogo({
    super.key,
    this.size = 40,
    this.borderRadius = 12,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = darkBackground ? WidgetTokens.ink : WidgetTokens.surface;
    final fallbackColor = darkBackground
        ? WidgetTokens.surface
        : WidgetTokens.accent;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: darkBackground
            ? null
            : Border.all(color: WidgetTokens.borderWarm),
      ),
      child: Image.asset(
        'assets/images/Logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.checkroom_rounded, color: fallbackColor);
        },
      ),
    );
  }
}
