import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HoverClickable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double hoverScale;
  final bool enableShadow;

  const HoverClickable({
    super.key,
    required this.child,
    this.onTap,
    this.hoverScale = 1.03,
    this.enableShadow = true,
  });

  @override
  State<HoverClickable> createState() => _HoverClickableState();
}

class _HoverClickableState extends State<HoverClickable> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? widget.hoverScale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: widget.enableShadow && _hovering
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: WidgetTokens.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

