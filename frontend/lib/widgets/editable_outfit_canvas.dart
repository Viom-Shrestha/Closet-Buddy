import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

class EditableCanvasItem {
  final String id;
  final String label;
  final String imageUrl;
  final double widthFactor;
  final double heightFactor;
  final Offset defaultOffset;

  const EditableCanvasItem({
    required this.id,
    required this.label,
    required this.imageUrl,
    required this.widthFactor,
    required this.heightFactor,
    required this.defaultOffset,
  });
}

class EditableCanvasTransform {
  final Offset offset;
  final double scale;

  const EditableCanvasTransform({required this.offset, required this.scale});

  EditableCanvasTransform copyWith({Offset? offset, double? scale}) {
    return EditableCanvasTransform(
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
    );
  }
}

/// A freeform canvas used for drag/resize outfit composition.
///
/// This is intentionally separate from `OutfitCanvas`, which is static and
/// slot-based.
class EditableOutfitCanvas extends StatefulWidget {
  final List<EditableCanvasItem> items;
  final Map<String, EditableCanvasTransform> initialTransforms;
  final bool interactive;
  final bool showGuide;
  final double? height;
  final bool showSurface;
  final bool showBorder;
  final double borderRadius;
  final ValueChanged<String>? onItemLongPress;
  final ValueChanged<Map<String, EditableCanvasTransform>>? onChanged;

  const EditableOutfitCanvas({
    super.key,
    required this.items,
    this.initialTransforms = const {},
    this.interactive = true,
    this.showGuide = false,
    this.height,
    this.showSurface = true,
    this.showBorder = true,
    this.borderRadius = 16,
    this.onItemLongPress,
    this.onChanged,
  });

  @override
  State<EditableOutfitCanvas> createState() => _EditableOutfitCanvasState();
}

class _EditableOutfitCanvasState extends State<EditableOutfitCanvas> {
  static const _minScale = 0.35;
  static const _maxScale = 2.6;

  final Map<String, EditableCanvasTransform> _transforms = {};
  String? _activeId;
  double _gestureStartScale = 1.0;

  @override
  void initState() {
    super.initState();
    _seedDefaults();
  }

  @override
  void didUpdateWidget(covariant EditableOutfitCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _seedDefaults();
    }
  }

  void _seedDefaults() {
    final incomingIds = widget.items.map((e) => e.id).toSet();
    _transforms.removeWhere((key, value) => !incomingIds.contains(key));
    for (final item in widget.items) {
      _transforms.putIfAbsent(
        item.id,
        () => EditableCanvasTransform(offset: item.defaultOffset, scale: 1),
      );
    }
    for (final entry in widget.initialTransforms.entries) {
      if (_transforms.containsKey(entry.key)) {
        _transforms[entry.key] = entry.value;
      }
    }
  }

  void _notifyChange() {
    widget.onChanged?.call(
      Map<String, EditableCanvasTransform>.from(_transforms),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedHeight =
            widget.height ?? math.min(560, constraints.maxWidth * 1.3);
        final size = Size(constraints.maxWidth, resolvedHeight);

        return Container(
          width: double.infinity,
          height: size.height,
          decoration: BoxDecoration(
            color: widget.showSurface
                ? WidgetTokens.surfaceWarm
                : WidgetTokens.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.showBorder
                ? Border.all(color: WidgetTokens.lineWarm)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (widget.showGuide)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.accessibility_new_rounded,
                        size: size.height * 0.82,
                        color: WidgetTokens.borderWarmSoft.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              for (final item in _orderedItems()) _buildItem(item, size),
            ],
          ),
        );
      },
    );
  }

  List<EditableCanvasItem> _orderedItems() {
    final copy = [...widget.items];
    if (_activeId == null) return copy;
    copy.sort((a, b) {
      if (a.id == _activeId) return 1;
      if (b.id == _activeId) return -1;
      return 0;
    });
    return copy;
  }

  Widget _buildItem(EditableCanvasItem item, Size canvasSize) {
    final transform = _transforms[item.id]!;
    final scaledWidth = canvasSize.width * item.widthFactor * transform.scale;
    final scaledHeight =
        canvasSize.height * item.heightFactor * transform.scale;

    final centerX = canvasSize.width * (0.5 + transform.offset.dx);
    final centerY = canvasSize.height * (0.5 + transform.offset.dy);
    final left = centerX - (scaledWidth / 2);
    final top = centerY - (scaledHeight / 2);
    final isActive = _activeId == item.id;

    final child = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? WidgetTokens.accent : WidgetTokens.transparent,
          width: 1.8,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.network(
        _resolveImage(item.imageUrl),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image_outlined,
          color: WidgetTokens.mutedWarm,
        ),
      ),
    );

    if (!widget.interactive) {
      return Positioned(
        left: left,
        top: top,
        width: scaledWidth,
        height: scaledHeight,
        child: child,
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: scaledWidth,
      height: scaledHeight,
      child: GestureDetector(
        onTap: () => setState(() => _activeId = item.id),
        onLongPress: widget.onItemLongPress == null
            ? null
            : () => widget.onItemLongPress!(item.id),
        onScaleStart: (details) {
          setState(() => _activeId = item.id);
          _gestureStartScale = transform.scale;
        },
        onScaleUpdate: (details) {
          final current = _transforms[item.id] ?? transform;
          final nextOffset = Offset(
            current.offset.dx + (details.focalPointDelta.dx / canvasSize.width),
            current.offset.dy +
                (details.focalPointDelta.dy / canvasSize.height),
          );
          final nextScale = (_gestureStartScale * details.scale).clamp(
            _minScale,
            _maxScale,
          );

          setState(() {
            _transforms[item.id] = transform.copyWith(
              offset: nextOffset,
              scale: nextScale,
            );
          });
          _notifyChange();
        },
        child: child,
      ),
    );
  }

  String _resolveImage(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }
}
