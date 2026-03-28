import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// A static, slot-based outfit canvas.
///
/// Use this when you want stable fixed slots (gallery cards/detail fallback).
///
/// Slots:
///   • outerwear  — optional, full-width, shown at top only when set
///   • topwear    — full-width
///   • bottomwear — left half  (same row as shoes)
///   • shoes      — right half (same row as bottomwear)
///   • accessories — optional, horizontal strip at bottom, shown only when non-empty
///
/// Each slot renders the item's network image inside a styled card.
/// When no item is set for an optional slot the slot is hidden entirely.
/// Required slots (top/bottom/shoes) show an empty-state placeholder instead.
class OutfitCanvas extends StatelessWidget {
  final Map<String, dynamic>? outerwear;
  final Map<String, dynamic>? topwear;
  final Map<String, dynamic>? bottomwear;
  final Map<String, dynamic>? shoes;
  final List<Map<String, dynamic>> accessories;

  /// Callback fired when the user taps a slot — passes the slot name.
  final void Function(String slot)? onSlotTap;

  /// When true the canvas is rendered smaller for use in gallery grid cards.
  final bool compact;

  /// Scales slot heights in non-compact mode.
  final double slotScale;

  const OutfitCanvas({
    super.key,
    this.outerwear,
    this.topwear,
    this.bottomwear,
    this.shoes,
    this.accessories = const [],
    this.onSlotTap,
    this.compact = false,
    this.slotScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = compact ? 1.0 : slotScale.clamp(0.8, 1.5);
    final bool showOptionalSlots = onSlotTap != null;
    final double gap = (compact ? 6 : 8) * scale;
    final double radius = compact ? 12 : 16;

    return Container(
      decoration: BoxDecoration(
        color: OutfitCanvasTokens.bg,
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        border: Border.all(color: OutfitCanvasTokens.border),
      ),
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Outerwear (optional) ───────────────────────────────────────
          if (outerwear != null || showOptionalSlots) ...[
            _FullWidthSlot(
              slot: 'outerwear',
              item: outerwear,
              label: 'Outerwear',
              height: (compact ? 80 : 120) * scale,
              radius: radius,
              compact: compact,
              onTap: onSlotTap,
            ),
            SizedBox(height: gap),
          ],

          // ── Topwear (required slot) ────────────────────────────────────
          _FullWidthSlot(
            slot: 'topwear',
            item: topwear,
            label: 'Topwear',
            height: (compact ? 90 : 140) * scale,
            radius: radius,
            compact: compact,
            onTap: onSlotTap,
          ),
          SizedBox(height: gap),

          // ── Bottomwear + Shoes (required slots, side by side) ──────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HalfSlot(
                    slot: 'bottomwear',
                    item: bottomwear,
                    label: 'Bottoms',
                    height: (compact ? 100 : 152) * scale,
                    radius: radius,
                    compact: compact,
                    onTap: onSlotTap,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _HalfSlot(
                    slot: 'shoes',
                    item: shoes,
                    label: 'Footwear',
                    height: (compact ? 100 : 152) * scale,
                    radius: radius,
                    compact: compact,
                    onTap: onSlotTap,
                  ),
                ),
              ],
            ),
          ),

          // ── Accessories strip (optional) ───────────────────────────────
          if (accessories.isNotEmpty || showOptionalSlots) ...[
            SizedBox(height: gap),
            _AccessoriesStrip(
              accessories: accessories,
              compact: compact,
              radius: radius,
              showWhenEmpty: showOptionalSlots,
              scale: scale,
              onTap: onSlotTap,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-width slot (outerwear / topwear)
// ─────────────────────────────────────────────────────────────────────────────

class _FullWidthSlot extends StatelessWidget {
  final String slot;
  final Map<String, dynamic>? item;
  final String label;
  final double height;
  final double radius;
  final bool compact;
  final void Function(String)? onTap;

  const _FullWidthSlot({
    required this.slot,
    required this.item,
    required this.label,
    required this.height,
    required this.radius,
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SlotTapArea(
      onTap: onTap == null ? null : () => onTap!(slot),
      radius: radius,
      child: _SlotCard(
        item: item,
        label: label,
        height: height,
        radius: radius,
        compact: compact,
        isHalf: false,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Half-width slot (bottomwear / shoes)
// ─────────────────────────────────────────────────────────────────────────────

class _HalfSlot extends StatelessWidget {
  final String slot;
  final Map<String, dynamic>? item;
  final String label;
  final double height;
  final double radius;
  final bool compact;
  final void Function(String)? onTap;

  const _HalfSlot({
    required this.slot,
    required this.item,
    required this.label,
    required this.height,
    required this.radius,
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SlotTapArea(
      onTap: onTap == null ? null : () => onTap!(slot),
      radius: radius,
      child: _SlotCard(
        item: item,
        label: label,
        height: height,
        radius: radius,
        compact: compact,
        isHalf: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared slot card UI
// ─────────────────────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final Map<String, dynamic>? item;
  final String label;
  final double height;
  final double radius;
  final bool compact;
  final bool isHalf;

  const _SlotCard({
    required this.item,
    required this.label,
    required this.height,
    required this.radius,
    required this.compact,
    required this.isHalf,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImage(item?['image']);
    final hasItem = imageUrl.isNotEmpty;
    final itemName = _itemName();
    final accentColor = _accentColor();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: OutfitCanvasTokens.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: hasItem
              ? OutfitCanvasTokens.border
              : OutfitCanvasTokens.emptyBorder,
          width: hasItem ? 1 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Item image ────────────────────────────────────────────────
          if (hasItem)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(compact ? 8 : 9),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) =>
                      _EmptyState(label: label, compact: compact),
                ),
              ),
            )
          else
            Positioned.fill(
              child: _EmptyState(label: label, compact: compact),
            ),

          // ── Accent color strip at bottom ──────────────────────────────
          if (hasItem && accentColor != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(radius),
                    bottomRight: Radius.circular(radius),
                  ),
                ),
              ),
            ),

          // ── Category chip (top-left) ──────────────────────────────────
          if (!compact)
            Positioned(top: 8, left: 8, child: _CategoryChip(label: label)),

          // ── Item name label (bottom-left) ─────────────────────────────
          if (hasItem && itemName.isNotEmpty && !compact)
            Positioned(
              bottom: 10,
              left: 8,
              right: 32,
              child: _NameLabel(name: itemName),
            ),

          // ── Tap ripple indicator (edit icon, top-right) ───────────────
          if (!compact && item != null)
            const Positioned(top: 8, right: 8, child: _EditBadge()),
        ],
      ),
    );
  }

  String _itemName() {
    if (item == null) return '';
    final sub = item!['subcategory']?.toString() ?? '';
    final cat = item!['category']?.toString() ?? '';
    return sub.isNotEmpty ? sub : cat;
  }

  Color? _accentColor() {
    final color = item?['color']?.toString().toLowerCase() ?? '';
    for (final entry in NamedColors.outfit.entries) {
      if (color.contains(entry.key)) return entry.value;
    }
    return OutfitCanvasTokens.borderWarm;
  }

  String _resolveImage(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accessories horizontal strip
// ─────────────────────────────────────────────────────────────────────────────

class _AccessoriesStrip extends StatelessWidget {
  final List<Map<String, dynamic>> accessories;
  final bool compact;
  final double radius;
  final bool showWhenEmpty;
  final double scale;
  final void Function(String)? onTap;

  const _AccessoriesStrip({
    required this.accessories,
    required this.compact,
    required this.radius,
    this.showWhenEmpty = false,
    this.scale = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double tileSize = (compact ? 44 : 64) * scale;
    final bool showPlaceholder = showWhenEmpty && accessories.isEmpty;
    final int itemCount = showPlaceholder ? 1 : accessories.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: _CategoryChip(label: 'Accessories'),
          ),
        SizedBox(
          height: tileSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (showPlaceholder) {
                return _SlotTapArea(
                  onTap: onTap == null ? null : () => onTap!('accessories'),
                  radius: compact ? 8 : 12,
                  child: Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: OutfitCanvasTokens.cardBg,
                      borderRadius: BorderRadius.circular(compact ? 8 : 12),
                      border: Border.all(color: OutfitCanvasTokens.emptyBorder),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: tileSize * 0.36,
                      color: OutfitCanvasTokens.categoryText,
                    ),
                  ),
                );
              }
              final acc = accessories[index];
              final imageUrl = _resolveImage(acc['image']);
              return _SlotTapArea(
                onTap: onTap == null ? null : () => onTap!('accessories'),
                radius: compact ? 8 : 12,
                child: Container(
                  width: tileSize,
                  height: tileSize,
                  decoration: BoxDecoration(
                    color: OutfitCanvasTokens.cardBg,
                    borderRadius: BorderRadius.circular(compact ? 8 : 12),
                    border: Border.all(color: OutfitCanvasTokens.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.watch_outlined,
                          size: tileSize * 0.4,
                          color: OutfitCanvasTokens.categoryText,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.watch_outlined,
                              size: tileSize * 0.4,
                              color: OutfitCanvasTokens.categoryText,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _resolveImage(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }
}

class _SlotTapArea extends StatelessWidget {
  final VoidCallback? onTap;
  final double radius;
  final Widget child;

  const _SlotTapArea({
    required this.onTap,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: OutfitCanvasTokens.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String label;
  final bool compact;

  const _EmptyState({required this.label, required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Icon(_iconFor(label), color: OutfitCanvasTokens.iconMuted, size: 22),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(label), color: OutfitCanvasTokens.iconMuted, size: 28),
          const SizedBox(height: 6),
          Text(
            'Add $label',
            style: const TextStyle(
              fontSize: 11,
              color: OutfitCanvasTokens.categoryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('shoe') || l.contains('foot')) {
      return Icons.directions_walk_outlined;
    }
    if (l.contains('outer') || l.contains('jacket')) {
      return Icons.layers_outlined;
    }
    if (l.contains('access')) {
      return Icons.watch_outlined;
    }
    return Icons.checkroom_outlined;
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: OutfitCanvasTokens.labelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OutfitCanvasTokens.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: OutfitCanvasTokens.categoryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NameLabel extends StatelessWidget {
  final String name;

  const _NameLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OutfitCanvasTokens.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OutfitCanvasTokens.border),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: OutfitCanvasTokens.ink,
        ),
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: OutfitCanvasTokens.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: OutfitCanvasTokens.border),
      ),
      child: const Icon(
        Icons.swap_horiz_rounded,
        size: 14,
        color: OutfitCanvasTokens.categoryText,
      ),
    );
  }
}
