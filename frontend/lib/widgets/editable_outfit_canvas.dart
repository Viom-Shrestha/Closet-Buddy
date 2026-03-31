import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
  // In read-only preview mode, normalize transforms so all items stay visible.
  final bool autoFitContent;
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
    this.autoFitContent = true,
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
  static const _safePaddingRatio = 0.03;
  static const _previewMarginRatio = 0.05;

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
    final itemsChanged = oldWidget.items != widget.items;
    final previewLayoutChanged =
        !widget.interactive &&
        oldWidget.interactive == widget.interactive &&
        !mapEquals(oldWidget.initialTransforms, widget.initialTransforms);
    if (itemsChanged || previewLayoutChanged) {
      _seedDefaults();
    }
  }

  void _seedDefaults() {
    final incomingIds = widget.items.map((e) => e.id).toSet();
    _transforms.removeWhere((key, value) => !incomingIds.contains(key));
    for (final item in widget.items) {
      final incoming = widget.initialTransforms[item.id];
      final base =
          incoming ??
          EditableCanvasTransform(offset: item.defaultOffset, scale: 1);
      final safeScale = _clampScaleForItem(item, base.scale);
      final safeOffset = _clampOffsetForItem(item, base.offset, safeScale);
      _transforms[item.id] = EditableCanvasTransform(
        offset: safeOffset,
        scale: safeScale,
      );
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
        final defaultRatio = widget.interactive ? 1.3 : 1.0;
        final maxHeight = widget.interactive ? 560.0 : 460.0;
        final resolvedHeight =
            widget.height ??
            (constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : math.min(maxHeight, constraints.maxWidth * defaultRatio));
        final size = Size(constraints.maxWidth, resolvedHeight);
        final effectiveTransforms = _effectiveTransforms(size);

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
                        color: WidgetTokens.borderWarmSoft.withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ),
                  ),
                ),
              for (final item in _orderedItems())
                _buildItem(
                  item,
                  size,
                  effectiveTransforms[item.id] ??
                      const EditableCanvasTransform(
                        offset: Offset.zero,
                        scale: 1,
                      ),
                ),
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

  Map<String, EditableCanvasTransform> _effectiveTransforms(Size canvasSize) {
    final normalized = <String, EditableCanvasTransform>{};
    for (final item in widget.items) {
      final base =
          _transforms[item.id] ??
          EditableCanvasTransform(offset: item.defaultOffset, scale: 1);
      final safeScale = _clampScaleForItem(item, base.scale);
      final safeOffset = _clampOffsetForItem(item, base.offset, safeScale);
      normalized[item.id] = EditableCanvasTransform(
        offset: safeOffset,
        scale: safeScale,
      );
    }

    if (widget.interactive || !widget.autoFitContent || normalized.isEmpty) {
      return normalized;
    }
    return _fitTransformsForPreview(normalized, canvasSize);
  }

  Map<String, EditableCanvasTransform> _fitTransformsForPreview(
    Map<String, EditableCanvasTransform> transforms,
    Size canvasSize,
  ) {
    if (widget.items.isEmpty) return transforms;

    Rect? bounds;
    for (final item in widget.items) {
      final transform = transforms[item.id];
      if (transform == null) continue;
      final rect = _itemRect(item, transform, canvasSize);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    if (bounds == null) return transforms;

    final targetWidth = canvasSize.width * (1 - (_previewMarginRatio * 2));
    final targetHeight = canvasSize.height * (1 - (_previewMarginRatio * 2));
    if (targetWidth <= 0 || targetHeight <= 0) return transforms;

    final fitScale = math.min(
      1.0,
      math.min(
        targetWidth / math.max(bounds.width, 1),
        targetHeight / math.max(bounds.height, 1),
      ),
    );

    final boundsCenter = bounds.center;
    final canvasCenter = Offset(canvasSize.width / 2, canvasSize.height / 2);

    final fitted = <String, EditableCanvasTransform>{};
    for (final item in widget.items) {
      final transform = transforms[item.id];
      if (transform == null) continue;
      final rawCenter = _centerFor(transform.offset, canvasSize);
      final fittedCenter = Offset(
        ((rawCenter.dx - boundsCenter.dx) * fitScale) + canvasCenter.dx,
        ((rawCenter.dy - boundsCenter.dy) * fitScale) + canvasCenter.dy,
      );
      final fittedScale = _clampScaleForItem(item, transform.scale * fitScale);
      final fittedOffset = Offset(
        (fittedCenter.dx / canvasSize.width) - 0.5,
        (fittedCenter.dy / canvasSize.height) - 0.5,
      );
      final safeOffset = _clampOffsetForItem(item, fittedOffset, fittedScale);
      fitted[item.id] = EditableCanvasTransform(
        offset: safeOffset,
        scale: fittedScale,
      );
    }
    return fitted;
  }

  Offset _centerFor(Offset offset, Size canvasSize) {
    return Offset(
      canvasSize.width * (0.5 + offset.dx),
      canvasSize.height * (0.5 + offset.dy),
    );
  }

  Rect _itemRect(
    EditableCanvasItem item,
    EditableCanvasTransform transform,
    Size canvasSize,
  ) {
    final width = canvasSize.width * item.widthFactor * transform.scale;
    final height = canvasSize.height * item.heightFactor * transform.scale;
    final center = _centerFor(transform.offset, canvasSize);
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  double _maxScaleForItem(EditableCanvasItem item) {
    final visibleFactor = 1 - (_safePaddingRatio * 2);
    final widthCap = visibleFactor / math.max(item.widthFactor, 0.0001);
    final heightCap = visibleFactor / math.max(item.heightFactor, 0.0001);
    return math.min(widthCap, heightCap);
  }

  double _clampScaleForItem(EditableCanvasItem item, double scale) {
    final safeInput = scale.isFinite ? scale : 1.0;
    final itemCap = _maxScaleForItem(item);
    final upper = math.max(_minScale, math.min(_maxScale, itemCap));
    return safeInput.clamp(_minScale, upper).toDouble();
  }

  Offset _clampOffsetForItem(
    EditableCanvasItem item,
    Offset offset,
    double scale,
  ) {
    final safeDx = offset.dx.isFinite ? offset.dx : 0.0;
    final safeDy = offset.dy.isFinite ? offset.dy : 0.0;
    final halfWidth = (item.widthFactor * scale) / 2;
    final halfHeight = (item.heightFactor * scale) / 2;

    double clampAxis(double value, double halfExtent) {
      final maxOffset = 0.5 - _safePaddingRatio - halfExtent;
      if (!maxOffset.isFinite || maxOffset <= 0) return 0.0;
      return value.clamp(-maxOffset, maxOffset).toDouble();
    }

    return Offset(clampAxis(safeDx, halfWidth), clampAxis(safeDy, halfHeight));
  }

  Widget _buildItem(
    EditableCanvasItem item,
    Size canvasSize,
    EditableCanvasTransform displayTransform,
  ) {
    final sourceTransform = _transforms[item.id] ?? displayTransform;
    final transform = displayTransform;
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
          _gestureStartScale = sourceTransform.scale;
        },
        onScaleUpdate: (details) {
          final current = _transforms[item.id] ?? sourceTransform;
          final rawOffset = Offset(
            current.offset.dx + (details.focalPointDelta.dx / canvasSize.width),
            current.offset.dy +
                (details.focalPointDelta.dy / canvasSize.height),
          );
          final nextScale = _clampScaleForItem(
            item,
            _gestureStartScale * details.scale,
          );
          final nextOffset = _clampOffsetForItem(item, rawOffset, nextScale);

          setState(() {
            _transforms[item.id] = current.copyWith(
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
