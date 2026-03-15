import 'package:flutter/material.dart';

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
    final bgColor = darkBackground ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Image.asset(
        'assets/images/Logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.checkroom_rounded, color: Colors.white);
        },
      ),
    );
  }
}

