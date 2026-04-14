import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';

import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/accessory_service.dart';
import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/services/outfit_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/editable_outfit_canvas.dart';
import 'package:frontend/widgets/outfit_canvas.dart';
import 'package:frontend/features/home/screens/add_item_screen.dart';
import 'package:frontend/features/storage/screens/storage_detail_screen.dart';
import 'package:frontend/features/recommendation/screens/recommendation_screen.dart';
import 'package:frontend/utils/outfit_slot_rules.dart';

// ═════════════════════════════════════════════════════════════════════════════
// OutfitsPage — gallery of saved outfits
// ═════════════════════════════════════════════════════════════════════════════

class OutfitsPage extends StatefulWidget {
  final bool embedded;
  final bool favouritesOnly;

  const OutfitsPage({
    super.key,
    this.embedded = false,
    this.favouritesOnly = false,
  });

  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> {
  final OutfitService _outfitService = ServiceRegistry.instance.outfitService;

  List<Map<String, dynamic>> _outfits = [];
  bool _loading = true;
  bool _selectMode = false;
  final Set<int> _selectedIds = {};
  String _sortBy = 'Newest first';

  static const List<String> _sortOptions = [
    'Newest first',
    'Oldest first',
    'Rating (high to low)',
    'Favourites first',
  ];

  List<Map<String, dynamic>> get _displayOutfits {
    final list = List<Map<String, dynamic>>.from(_outfits);
    switch (_sortBy) {
      case 'Oldest first':
        list.sort(
          (a, b) =>
              (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
        );
      case 'Rating (high to low)':
        list.sort((a, b) {
          final ra = int.tryParse(a['rating']?.toString() ?? '') ?? 0;
          final rb = int.tryParse(b['rating']?.toString() ?? '') ?? 0;
          return rb.compareTo(ra);
        });
      case 'Favourites first':
        list.sort((a, b) {
          final fa = (a['is_favourite'] == true) ? 0 : 1;
          final fb = (b['is_favourite'] == true) ? 0 : 1;
          return fa.compareTo(fb);
        });
      default:
        list.sort(
          (a, b) =>
              (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
        );
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    setState(() => _loading = true);
    final outfits = await _outfitService.getAll(
      favouritesOnly: widget.favouritesOnly ? true : null,
    );
    if (!mounted) return;
    setState(() {
      _outfits = outfits;
      _loading = false;
    });
  }

  Future<void> _openCreateFlow() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OutfitItemSelectionPage()),
    );
    if (changed == true) _loadOutfits();
  }

  Future<void> _openRecommendations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecommendationScreen(title: 'Outfit Generation'),
      ),
    );
    if (mounted) {
      _loadOutfits();
    }
  }

  Future<void> _openDetail(Map<String, dynamic> outfit) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailPage(initialOutfit: outfit),
      ),
    );
    _loadOutfits();
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(int? id) {
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected outfits?'),
        content: Text('This will delete ${_selectedIds.length} outfit(s).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: OutfitTokens.dangerStrong,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ids = _selectedIds.toList();
    await Future.wait(ids.map(_outfitService.delete));
    if (!mounted) return;
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    _loadOutfits();
  }

  @override
  Widget build(BuildContext context) {
    final total = _outfits.length;
    final favs = _outfits.where((o) => o['is_favourite'] == true).length;
    final ratings = _outfits
        .map((o) => int.tryParse(o['rating']?.toString() ?? '') ?? 0)
        .where((r) => r > 0)
        .toList();
    final avgRating = ratings.isEmpty
        ? null
        : (ratings.reduce((a, b) => a + b) / ratings.length);

    final page = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadOutfits,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeaderSection(
                  totalOutfits: total,
                  favoriteOutfits: favs,
                  avgRating: avgRating,
                  loading: _loading,
                  onCreateTap: _openCreateFlow,
                  onGenerateTap: _openRecommendations,
                  onSelectTap: _toggleSelectMode,
                  selectMode: _selectMode,
                  selectedCount: _selectedIds.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text(
                    widget.favouritesOnly
                        ? '$total Favourite ${total == 1 ? 'Outfit' : 'Outfits'}'
                        : '$total Saved ${total == 1 ? 'Outfit' : 'Outfits'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: OutfitTokens.slate,
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_outfits.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _emptyState(),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _sortBar()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final displayed = _displayOutfits;
                      final width = constraints.crossAxisExtent;
                      final crossAxisCount = width > 900
                          ? 4
                          : width > 700
                          ? 3
                          : 2;
                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final outfit = displayed[index];
                          final id = outfit['id'] is int
                              ? outfit['id'] as int
                              : int.tryParse('${outfit['id']}');
                          final selected =
                              id != null && _selectedIds.contains(id);
                          return _GalleryCard(
                            outfit: outfit,
                            onTap: (data) {
                              if (_selectMode) {
                                _toggleSelected(id);
                              } else {
                                _openDetail(data);
                              }
                            },
                            onLongPress: (data) {
                              if (!_selectMode) {
                                _toggleSelectMode();
                              }
                              _toggleSelected(id);
                            },
                            selectionMode: _selectMode,
                            selected: selected,
                          );
                        }, childCount: displayed.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.46,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_selectMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: OutfitTokens.ink,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: OutfitTokens.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: const TextStyle(
                        color: OutfitTokens.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _toggleSelectMode,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: OutfitTokens.dangerStrong,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return page;

    return Scaffold(
      backgroundColor: OutfitTokens.bg,
      appBar: AppBar(
        title: Text(widget.favouritesOnly ? 'Favourite Outfits' : 'Outfits'),
        backgroundColor: OutfitTokens.surface,
        foregroundColor: OutfitTokens.ink,
      ),
      body: page,
    );
  }

  Widget _sortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: OutfitTokens.muted),
          const SizedBox(width: 8),
          const Text(
            'Sort:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OutfitTokens.muted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sortOptions.map((option) {
                  final active = _sortBy == option;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _sortBy = option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? OutfitTokens.inkStrong
                              : OutfitTokens.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? OutfitTokens.inkStrong
                                : OutfitTokens.border,
                          ),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? OutfitTokens.white
                                : OutfitTokens.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final title = widget.favouritesOnly
        ? 'No favourite outfits yet'
        : 'No outfits yet';
    final subtitle = widget.favouritesOnly
        ? 'Favourite an outfit to see it here.'
        : 'Build your first look and it will appear here.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        color: OutfitTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OutfitTokens.border),
        boxShadow: [
          BoxShadow(
            color: OutfitTokens.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: OutfitTokens.tagBgSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 30,
              color: OutfitTokens.muted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OutfitTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: OutfitTokens.muted),
            textAlign: TextAlign.center,
          ),
          if (!widget.favouritesOnly) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openCreateFlow,
              icon: const Icon(Icons.add),
              label: const Text('Create Outfit'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header section
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  final int totalOutfits;
  final int favoriteOutfits;
  final double? avgRating;
  final bool loading;
  final VoidCallback onCreateTap;
  final VoidCallback onGenerateTap;
  final VoidCallback onSelectTap;
  final bool selectMode;
  final int selectedCount;

  const _HeaderSection({
    required this.totalOutfits,
    required this.favoriteOutfits,
    required this.avgRating,
    required this.loading,
    required this.onCreateTap,
    required this.onGenerateTap,
    required this.onSelectTap,
    required this.selectMode,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OutfitTokens.heroStart, OutfitTokens.heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: OutfitTokens.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outfit Studio',
            style: TextStyle(
              color: OutfitTokens.onHero,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Build and review your saved looks.',
            style: TextStyle(color: OutfitTokens.onHeroMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(Icons.checkroom_outlined, 'Total', '$totalOutfits'),
              _StatPill(
                Icons.favorite_border,
                'Favourites',
                '$favoriteOutfits',
              ),
              _StatPill(
                Icons.star_border,
                'Avg rating',
                avgRating == null ? '-' : avgRating!.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onCreateTap,
                  icon: const Icon(Icons.add),
                  style: FilledButton.styleFrom(
                    backgroundColor: OutfitTokens.onHero,
                    foregroundColor: OutfitTokens.ink,
                  ),
                  label: const Text('Create Outfit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onGenerateTap,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OutfitTokens.onHero,
                    side: const BorderSide(color: OutfitTokens.onHeroMuted),
                  ),
                  label: const Text('Generate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: loading ? null : onSelectTap,
              icon: Icon(
                selectMode ? Icons.close : Icons.checklist_rtl,
                color: OutfitTokens.onHero,
                size: 18,
              ),
              label: Text(
                selectMode
                    ? 'Exit selection ($selectedCount)'
                    : 'Select outfits',
                style: const TextStyle(color: OutfitTokens.onHero),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatPill(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OutfitTokens.onHero.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OutfitTokens.onHero.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: OutfitTokens.onHero),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: OutfitTokens.onHero,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery card — compact version of canvas in a grid cell
// ─────────────────────────────────────────────────────────────────────────────

class _CardMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _CardMetaPill({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OutfitTokens.tagBgSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OutfitTokens.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? OutfitTokens.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OutfitTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final Map<String, dynamic> outfit;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>) onLongPress;
  final bool selectionMode;
  final bool selected;

  const _GalleryCard({
    required this.outfit,
    required this.onTap,
    required this.onLongPress,
    required this.selectionMode,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final name = (outfit['name'] ?? 'Untitled Outfit').toString();
    final occasion = (outfit['occasion'] ?? 'Any Occasion').toString();
    final rating = _asInt(outfit['rating']);
    final aiRatingScore = _asDouble(outfit['ai_rating_score']);
    final wearCount = _asInt(outfit['wear_count']) ?? 0;
    final isFav = outfit['is_favourite'] == true;
    final previewItems = _previewItems(outfit);
    final previewTransforms = _layoutToTransforms(_previewLayout(outfit));
    final combinedRatingLabel = (aiRatingScore != null && rating != null)
        ? 'AI ${aiRatingScore.toStringAsFixed(1)} · U $rating/5'
        : null;

    return GestureDetector(
      onTap: () => onTap(outfit),
      onLongPress: () => onLongPress(outfit),
      child: Container(
        decoration: BoxDecoration(
          color: OutfitTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? OutfitTokens.accent : OutfitTokens.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: OutfitTokens.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.62,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: OutfitTokens.tagBgSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: previewItems.isNotEmpty
                        ? EditableOutfitCanvas(
                            items: previewItems,
                            initialTransforms: previewTransforms,
                            interactive: false,
                          )
                        : OutfitCanvas(
                            outerwear: _slot(outfit, 'outerwear_item'),
                            topwear: _slot(outfit, 'topwear_item'),
                            bottomwear: _slot(outfit, 'bottomwear_item'),
                            shoes: _slot(outfit, 'shoes_item'),
                            accessories: _accessoryList(outfit),
                            compact: true,
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: OutfitTokens.ink,
                          ),
                        ),
                      ),
                      Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFav ? OutfitTokens.danger : OutfitTokens.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    occasion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OutfitTokens.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (combinedRatingLabel != null)
                        _CardMetaPill(
                          icon: Icons.auto_awesome_rounded,
                          label: combinedRatingLabel,
                          iconColor: OutfitTokens.warning,
                        )
                      else if (aiRatingScore != null)
                        _CardMetaPill(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI ${aiRatingScore.toStringAsFixed(1)}',
                          iconColor: OutfitTokens.warning,
                        ),
                      _CardMetaPill(
                        icon: Icons.checkroom_outlined,
                        label: wearCount == 0
                            ? 'New outfit'
                            : '$wearCount wears',
                      ),
                      if (rating != null && combinedRatingLabel == null)
                        _CardMetaPill(
                          icon: Icons.star_outline_rounded,
                          label: 'User $rating/5',
                        ),
                      if (selectionMode)
                        _CardMetaPill(
                          icon: selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          label: selected ? 'Selected' : 'Tap to select',
                          iconColor: selected
                              ? OutfitTokens.accent
                              : OutfitTokens.muted,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _slot(Map<String, dynamic> outfit, String key) {
    final raw = outfit[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  List<Map<String, dynamic>> _accessoryList(Map<String, dynamic> outfit) {
    final raw = outfit['accessory_items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _previewLayout(Map<String, dynamic> outfit) {
    final raw = outfit['preview_layout'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<EditableCanvasItem> _previewItems(Map<String, dynamic> outfit) {
    final top = _slot(outfit, 'topwear_item');
    final bottom = _slot(outfit, 'bottomwear_item');
    final shoes = _slot(outfit, 'shoes_item');
    final outerwear = _slot(outfit, 'outerwear_item');
    final accs = _accessoryList(outfit);
    final items = <EditableCanvasItem>[];
    if (bottom != null) {
      items.add(
        EditableCanvasItem(
          id: 'bottom-${_asInt(bottom['id']) ?? 0}',
          label: 'Bottomwear',
          imageUrl: _imageOf(bottom),
          widthFactor: 0.5,
          heightFactor: 0.27,
          defaultOffset: const Offset(0, 0.23),
        ),
      );
    }
    if (top != null) {
      items.add(
        EditableCanvasItem(
          id: 'top-${_asInt(top['id']) ?? 0}',
          label: 'Topwear',
          imageUrl: _imageOf(top),
          widthFactor: 0.62,
          heightFactor: 0.28,
          defaultOffset: const Offset(0, -0.03),
        ),
      );
    }
    if (outerwear != null) {
      items.add(
        EditableCanvasItem(
          id: 'outerwear-${_asInt(outerwear['id']) ?? 0}',
          label: 'Outerwear',
          imageUrl: _imageOf(outerwear),
          widthFactor: 0.64,
          heightFactor: 0.24,
          defaultOffset: const Offset(0, -0.23),
        ),
      );
    }
    if (shoes != null) {
      items.add(
        EditableCanvasItem(
          id: 'shoes-${_asInt(shoes['id']) ?? 0}',
          label: 'Shoes',
          imageUrl: _imageOf(shoes),
          widthFactor: 0.46,
          heightFactor: 0.17,
          defaultOffset: const Offset(0, 0.41),
        ),
      );
    }
    for (var i = 0; i < accs.length; i++) {
      final acc = accs[i];
      final col = i % 4;
      final row = i ~/ 4;
      items.add(
        EditableCanvasItem(
          id: 'acc-${_asInt(acc['id']) ?? i}',
          label: 'Accessory',
          imageUrl: _imageOf(acc),
          widthFactor: 0.17,
          heightFactor: 0.11,
          defaultOffset: Offset(-0.225 + (col * 0.15), 0.5 - (row * 0.09)),
        ),
      );
    }
    return items.where((item) => item.imageUrl.isNotEmpty).toList();
  }

  Map<String, EditableCanvasTransform> _layoutToTransforms(
    Map<String, dynamic> layout,
  ) {
    final out = <String, EditableCanvasTransform>{};
    layout.forEach((key, value) {
      if (value is! Map) return;
      final x = (value['offset_x'] is num)
          ? (value['offset_x'] as num).toDouble()
          : double.tryParse('${value['offset_x']}');
      final y = (value['offset_y'] is num)
          ? (value['offset_y'] as num).toDouble()
          : double.tryParse('${value['offset_y']}');
      final s = (value['scale'] is num)
          ? (value['scale'] as num).toDouble()
          : double.tryParse('${value['scale']}');
      if (x == null || y == null || s == null) return;
      out[key] = EditableCanvasTransform(offset: Offset(x, y), scale: s);
    });
    return out;
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  String _imageOf(Map<String, dynamic> item) {
    final raw = (item['image'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiClient.host}$raw';
    return '${ApiClient.host}/$raw';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OutfitItemSelectionPage — pick initial clothes then continue to builder
// ═════════════════════════════════════════════════════════════════════════════

class OutfitItemSelectionPage extends StatefulWidget {
  const OutfitItemSelectionPage({super.key});

  @override
  State<OutfitItemSelectionPage> createState() =>
      _OutfitItemSelectionPageState();
}

class _OutfitItemSelectionPageState extends State<OutfitItemSelectionPage> {
  final AccessoryService _accessoryService =
      ServiceRegistry.instance.accessoryService;
  final ClothingService _clothingService =
      ServiceRegistry.instance.clothingService;

  // Items per slot
  List<Map<String, dynamic>> _tops = [];
  List<Map<String, dynamic>> _bottoms = [];
  List<Map<String, dynamic>> _shoes = [];
  List<Map<String, dynamic>> _outerwear = [];
  List<Map<String, dynamic>> _accessories = [];

  // Selected indices (-1 = none)
  int _topIndex = -1;
  int _bottomIndex = -1;
  int _shoesIndex = -1;
  int _outerwearIndex = -1; // optional
  final Set<int> _accessoryIndices = {}; // optional, multi-select

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClothes();
  }

  Future<void> _loadClothes() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _clothingService.getAllClothes(excludePutAway: true),
      _accessoryService.getAll(),
    ]);
    final items = results[0];
    final accessoryItems = results[1];
    if (!mounted) return;

    final tops = <Map<String, dynamic>>[];
    final bottoms = <Map<String, dynamic>>[];
    final shoes = <Map<String, dynamic>>[];
    final outerwear = <Map<String, dynamic>>[];
    final accessories = <Map<String, dynamic>>[...accessoryItems];

    for (final item in items) {
      final slot = OutfitSlotRules.slotFor(item);
      switch (slot) {
        case 'shoes':
          shoes.add(item);
          break;
        case 'bottomwear':
          bottoms.add(item);
          break;
        case 'outerwear':
          outerwear.add(item);
          break;
        case 'accessories':
          // Accessories now come from dedicated model/service.
          break;
        default:
          tops.add(item);
          break;
      }
    }

    setState(() {
      _tops = tops;
      _bottoms = bottoms;
      _shoes = shoes;
      _outerwear = outerwear;
      _accessories = accessories;
      _topIndex = tops.isEmpty ? -1 : 0;
      _bottomIndex = bottoms.isEmpty ? -1 : 0;
      _shoesIndex = shoes.isEmpty ? -1 : 0;
      _outerwearIndex = -1; // optional — not pre-selected
      _accessoryIndices.clear();
      _loading = false;
    });
  }

  Future<void> _openBuilder() async {
    if (_tops.isEmpty && _bottoms.isEmpty && _shoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add some clothes first to create an outfit'),
        ),
      );
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(
          initialTopId: _idAt(_tops, _topIndex),
          initialBottomId: _idAt(_bottoms, _bottomIndex),
          initialShoesId: _idAt(_shoes, _shoesIndex),
          initialOuterwearId: _idAt(_outerwear, _outerwearIndex),
          initialAccessoryIds: _accessoryIndices
              .map((i) => _idAt(_accessories, i))
              .whereType<int>()
              .toList(),
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutfitTokens.bg,
      appBar: AppBar(
        backgroundColor: OutfitTokens.surface,
        foregroundColor: OutfitTokens.ink,
        title: const Text('Select Clothes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Required slots
                _SelectorCard(
                  title: 'Topwear',
                  items: _tops,
                  selectedIndex: _topIndex,
                  onSelect: (i) => setState(() => _topIndex = i),
                  onAddItem: _openAddAndRefresh,
                ),
                const SizedBox(height: 12),
                _SelectorCard(
                  title: 'Bottomwear',
                  items: _bottoms,
                  selectedIndex: _bottomIndex,
                  onSelect: (i) => setState(() => _bottomIndex = i),
                  onAddItem: _openAddAndRefresh,
                ),
                const SizedBox(height: 12),
                _SelectorCard(
                  title: 'Shoes',
                  items: _shoes,
                  selectedIndex: _shoesIndex,
                  onSelect: (i) => setState(() => _shoesIndex = i),
                  onAddItem: _openAddAndRefresh,
                ),
                const SizedBox(height: 12),

                // Optional slots header
                _SectionDivider(
                  label: 'Optional Pieces',
                  subtitle: 'Add to elevate the look',
                ),
                const SizedBox(height: 12),

                // Outerwear — single-select, optional
                _SelectorCard(
                  title: 'Outerwear',
                  subtitle: 'Optional',
                  items: _outerwear,
                  selectedIndex: _outerwearIndex,
                  onSelect: (i) => setState(() {
                    // Toggle off if tapping same item
                    _outerwearIndex = _outerwearIndex == i ? -1 : i;
                  }),
                  onAddItem: _openAddAndRefresh,
                  optional: true,
                ),
                const SizedBox(height: 12),

                // Accessories — multi-select, optional
                _MultiSelectorCard(
                  title: 'Accessories',
                  subtitle: 'Optional — pick multiple',
                  items: _accessories,
                  selectedIndices: _accessoryIndices,
                  onToggle: (i) => setState(() {
                    if (_accessoryIndices.contains(i)) {
                      _accessoryIndices.remove(i);
                    } else {
                      _accessoryIndices.add(i);
                    }
                  }),
                  onAddItem: _openAddAndRefresh,
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _openBuilder,
                  style: FilledButton.styleFrom(
                    backgroundColor: OutfitTokens.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.design_services_outlined),
                  label: const Text('Continue to Builder'),
                ),
              ],
            ),
    );
  }

  Future<void> _openAddAndRefresh() async {
    await showAddItemSheet(context);
    if (!mounted) return;
    _loadClothes();
  }

  int? _idAt(List<Map<String, dynamic>> items, int index) {
    if (index < 0 || index >= items.length) return null;
    final raw = items[index]['id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable selector cards
// ─────────────────────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  final String subtitle;

  const _SectionDivider({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: OutfitTokens.border)),
        const SizedBox(width: 12),
        Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OutfitTokens.ink,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: OutfitTokens.muted),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: OutfitTokens.border)),
      ],
    );
  }
}

/// Single-select horizontal scrollable item picker.
class _SelectorCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Map<String, dynamic>> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddItem;
  final bool optional;

  const _SelectorCard({
    required this.title,
    this.subtitle,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddItem,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: OutfitTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OutfitTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OutfitTokens.tagBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: OutfitTokens.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty) ...[
            Text(
              optional
                  ? 'No $title items. Add some to your wardrobe.'
                  : 'No items found.',
              style: const TextStyle(fontSize: 12, color: OutfitTokens.muted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: Text('Add $title'),
            ),
          ] else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _ItemTile(
                  item: items[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelect(index),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-select card for accessories.
class _MultiSelectorCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Map<String, dynamic>> items;
  final Set<int> selectedIndices;
  final ValueChanged<int> onToggle;
  final VoidCallback onAddItem;

  const _MultiSelectorCard({
    required this.title,
    this.subtitle,
    required this.items,
    required this.selectedIndices,
    required this.onToggle,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: OutfitTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OutfitTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Accessories',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(width: 6),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OutfitTokens.tagBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: OutfitTokens.muted,
                    ),
                  ),
                ),
              const Spacer(),
              if (selectedIndices.isNotEmpty)
                Text(
                  '${selectedIndices.length} selected',
                  style: const TextStyle(
                    fontSize: 11,
                    color: OutfitTokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty) ...[
            const Text(
              'No accessories found. Add watches, belts, bags, etc.',
              style: TextStyle(fontSize: 12, color: OutfitTokens.muted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Accessory'),
            ),
          ] else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _ItemTile(
                  item: items[index],
                  selected: selectedIndices.contains(index),
                  onTap: () => onToggle(index),
                  multiSelect: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;
  final bool multiSelect;

  const _ItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
    this.multiSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = _resolveImage(item['image']);
    final label = (item['subcategory'] ?? item['category'] ?? 'Item')
        .toString();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? OutfitTokens.surfaceWarm : OutfitTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? OutfitTokens.ink : OutfitTokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: image.isEmpty
                        ? const Icon(
                            Icons.image_not_supported_outlined,
                            size: 28,
                            color: OutfitTokens.muted,
                          )
                        : Image.network(image, fit: BoxFit.contain),
                  ),
                  if (selected && multiSelect)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: OutfitTokens.ink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: OutfitTokens.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
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

// ═════════════════════════════════════════════════════════════════════════════
// OutfitBuilderPage — main builder with live canvas + inline slot switcher
// ═════════════════════════════════════════════════════════════════════════════

class OutfitBuilderPage extends StatefulWidget {
  final Map<String, dynamic>? existingOutfit;
  final int? initialTopId;
  final int? initialBottomId;
  final int? initialShoesId;
  final int? initialOuterwearId;
  final List<int> initialAccessoryIds;

  const OutfitBuilderPage({
    super.key,
    this.existingOutfit,
    this.initialTopId,
    this.initialBottomId,
    this.initialShoesId,
    this.initialOuterwearId,
    this.initialAccessoryIds = const [],
  });

  @override
  State<OutfitBuilderPage> createState() => _OutfitBuilderPageState();
}

class _OutfitBuilderPageState extends State<OutfitBuilderPage> {
  final AccessoryService _accessoryService =
      ServiceRegistry.instance.accessoryService;
  final ClothingService _clothingService =
      ServiceRegistry.instance.clothingService;
  final OutfitService _outfitService = ServiceRegistry.instance.outfitService;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _occasionCtrl = TextEditingController();
  double? _aiRatingScore;
  List<String> _aiRatingReasons = [];
  Map<String, dynamic> _aiRatingBreakdown = {};
  String? _aiRatedAt;
  double? _aiRatingDelta;
  bool _aiRatingLoading = false;
  bool _aiRatingStale = false;

  // All items grouped by slot
  List<Map<String, dynamic>> _tops = [];
  List<Map<String, dynamic>> _bottoms = [];
  List<Map<String, dynamic>> _shoes = [];
  List<Map<String, dynamic>> _outerwear = [];
  List<Map<String, dynamic>> _accessories = [];

  // Selected indices
  int _topIndex = -1;
  int _bottomIndex = -1;
  int _shoesIndex = -1;
  int _outerwearIndex = -1; // -1 = none (optional)
  final Set<int> _accessoryIndices = {};

  // Builder UI state
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _previewLayout = {};

  int? get _editingOutfitId => _asInt(widget.existingOutfit?['id']);

  // ── Init ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _prefillMetadata();
    _loadClothes();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _occasionCtrl.dispose();
    super.dispose();
  }

  void _prefillMetadata() {
    final e = widget.existingOutfit;
    if (e == null) return;
    _nameCtrl.text = (e['name'] ?? '').toString();
    _occasionCtrl.text = (e['occasion'] ?? '').toString();
    final rawPreview = e['preview_layout'];
    if (rawPreview is Map<String, dynamic>) {
      _previewLayout = rawPreview;
    } else if (rawPreview is Map) {
      _previewLayout = Map<String, dynamic>.from(rawPreview);
    }
    _refreshAiSnapshot(e);
  }

  Future<void> _loadClothes() async {
    final results = await Future.wait([
      _clothingService.getAllClothes(excludePutAway: true),
      _accessoryService.getAll(),
    ]);
    final items = results[0];
    final accessoryItems = results[1];
    if (!mounted) return;

    final tops = <Map<String, dynamic>>[];
    final bottoms = <Map<String, dynamic>>[];
    final shoes = <Map<String, dynamic>>[];
    final outerwear = <Map<String, dynamic>>[];
    final accessories = <Map<String, dynamic>>[...accessoryItems];

    for (final item in items) {
      switch (OutfitSlotRules.slotFor(item)) {
        case 'shoes':
          shoes.add(item);
          break;
        case 'bottomwear':
          bottoms.add(item);
          break;
        case 'outerwear':
          outerwear.add(item);
          break;
        case 'accessories':
          // Accessories now come from dedicated model/service.
          // Ignore legacy classified clothing accessories here.
          break;
        default:
          tops.add(item);
          break;
      }
    }

    setState(() {
      _tops = tops;
      _bottoms = bottoms;
      _shoes = shoes;
      _outerwear = outerwear;
      _accessories = accessories;
      _topIndex = tops.isEmpty ? -1 : 0;
      _bottomIndex = bottoms.isEmpty ? -1 : 0;
      _shoesIndex = shoes.isEmpty ? -1 : 0;
      _outerwearIndex = -1;
      _loading = false;
    });

    _applyExistingSelection();
    _applyInitialSelection();
  }

  void _applyExistingSelection() {
    final e = widget.existingOutfit;
    if (e == null) return;

    void findAndSet(
      String slotKey,
      List<Map<String, dynamic>> list,
      void Function(int) setter,
    ) {
      final id = _asInt(_slotMap(e, slotKey)?['id']);
      if (id == null) return;
      final idx = _indexById(list, id);
      if (idx >= 0) setter(idx);
    }

    setState(() {
      findAndSet('topwear_item', _tops, (i) => _topIndex = i);
      findAndSet('bottomwear_item', _bottoms, (i) => _bottomIndex = i);
      findAndSet('shoes_item', _shoes, (i) => _shoesIndex = i);
      findAndSet('outerwear_item', _outerwear, (i) => _outerwearIndex = i);

      // Accessories (list)
      final rawAccs = e['accessory_items'];
      if (rawAccs is List) {
        for (final acc in rawAccs.whereType<Map>()) {
          final id = _asInt(acc['id']);
          if (id == null) continue;
          final idx = _indexById(_accessories, id);
          if (idx >= 0) _accessoryIndices.add(idx);
        }
      }
    });
  }

  void _applyInitialSelection() {
    if (widget.existingOutfit != null) return;

    void findAndSet(
      int? id,
      List<Map<String, dynamic>> list,
      void Function(int) setter,
    ) {
      if (id == null || list.isEmpty) return;
      final idx = _indexById(list, id);
      if (idx >= 0) setter(idx);
    }

    setState(() {
      findAndSet(widget.initialTopId, _tops, (i) => _topIndex = i);
      findAndSet(widget.initialBottomId, _bottoms, (i) => _bottomIndex = i);
      findAndSet(widget.initialShoesId, _shoes, (i) => _shoesIndex = i);
      findAndSet(
        widget.initialOuterwearId,
        _outerwear,
        (i) => _outerwearIndex = i,
      );
      for (final id in widget.initialAccessoryIds) {
        final idx = _indexById(_accessories, id);
        if (idx >= 0) _accessoryIndices.add(idx);
      }
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _saveOutfit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Outfit name is required')));
      return;
    }

    final top = _selected(_tops, _topIndex);
    final bottom = _selected(_bottoms, _bottomIndex);
    final shoes = _selected(_shoes, _shoesIndex);

    if (top == null && bottom == null && shoes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one main item to save')),
      );
      return;
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'name': name,
      'occasion': _occasionCtrl.text.trim().isEmpty
          ? null
          : _occasionCtrl.text.trim(),
      'preview_layout': _layoutForSave(),
      'outerwear_id': _asInt(_selected(_outerwear, _outerwearIndex)?['id']),
      'topwear_id': _asInt(top?['id']),
      'bottomwear_id': _asInt(bottom?['id']),
      'shoes_id': _asInt(shoes?['id']),
      'accessory_ids': _accessoryIndices
          .map((i) => _asInt(_selected(_accessories, i)?['id']))
          .whereType<int>()
          .toList(),
    };
    payload.addAll(_buildAiSnapshotForSave());

    final id = _editingOutfitId;
    final result = id == null
        ? await _outfitService.create(payload)
        : await _outfitService.update(id, payload);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save outfit')));
      return;
    }
    Navigator.pop(context, true);
  }

  Map<String, dynamic> _buildAiSnapshotForSave() {
    if (_aiRatingScore != null && !_aiRatingStale) {
      return {
        'ai_rating_score': _aiRatingScore,
        'ai_rating_reasons': _aiRatingReasons,
        'ai_rating_breakdown': _aiRatingBreakdown,
        'ai_rated_at': _aiRatedAt,
      };
    }
    return {
      'ai_rating_score': null,
      'ai_rating_reasons': <String>[],
      'ai_rating_breakdown': <String, dynamic>{},
      'ai_rated_at': null,
    };
  }

  void _refreshAiSnapshot(Map<String, dynamic> payload) {
    _aiRatingScore = _asDouble(payload['ai_rating_score']);
    _aiRatingReasons = _stringList(payload['ai_rating_reasons']);
    final rawBreakdown = payload['ai_rating_breakdown'];
    if (rawBreakdown is Map<String, dynamic>) {
      _aiRatingBreakdown = rawBreakdown;
    } else if (rawBreakdown is Map) {
      _aiRatingBreakdown = Map<String, dynamic>.from(rawBreakdown);
    } else {
      _aiRatingBreakdown = {};
    }
    _aiRatedAt = payload['ai_rated_at']?.toString();
    _aiRatingDelta = null;
    _aiRatingStale = false;
  }

  void _markAiRatingStale() {
    if (_aiRatingScore == null || _aiRatingStale) return;
    _aiRatingDelta = null;
    _aiRatingStale = true;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final previewItems = _canvasPreviewItems();
    final previewTransforms = _layoutToTransforms(_previewLayout);
    final builderCanvasHeight = (MediaQuery.of(context).size.width * 1.7)
        .clamp(620.0, 820.0)
        .toDouble();

    return Scaffold(
      backgroundColor: OutfitTokens.bg,
      appBar: AppBar(
        backgroundColor: OutfitTokens.surface,
        foregroundColor: OutfitTokens.ink,
        title: Text(
          _editingOutfitId == null ? 'Outfit Builder' : 'Edit Outfit',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // ── Live canvas ──────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Editable Outfit Canvas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: OutfitTokens.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (previewItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: OutfitTokens.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: OutfitTokens.border),
                              ),
                              child: const Text(
                                'Select items to enable freeform canvas.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: OutfitTokens.muted,
                                ),
                              ),
                            )
                          else
                            EditableOutfitCanvas(
                              items: previewItems,
                              initialTransforms: previewTransforms,
                              showGuide: false,
                              height: builderCanvasHeight,
                              onItemLongPress: _handleCanvasItemLongPress,
                              onChanged: (value) {
                                setState(() {
                                  _previewLayout = _transformsToLayout(value);
                                });
                              },
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Long press item to switch slot. Drag to move, pinch to scale.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OutfitTokens.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Static Slot Preview',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: OutfitTokens.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutfitCanvas(
                            outerwear: _selected(_outerwear, _outerwearIndex),
                            topwear: _selected(_tops, _topIndex),
                            bottomwear: _selected(_bottoms, _bottomIndex),
                            shoes: _selected(_shoes, _shoesIndex),
                            accessories: _selectedAccessories(),
                            slotScale: 1.15,
                            onSlotTap: _handleSlotTap,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap any slot to change selected items.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OutfitTokens.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildCreationSection(),
                          const SizedBox(height: 10),
                          _buildEvaluationSection(),
                        ],
                      ),
                    ),
                  ),
                  // ── Action row ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveOutfit,
                            style: FilledButton.styleFrom(
                              backgroundColor: OutfitTokens.ink,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: OutfitTokens.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _editingOutfitId == null
                                  ? 'Save Outfit'
                                  : 'Update Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _openAddAndRefresh() async {
    await showAddItemSheet(context);
    if (!mounted) return;
    _loadClothes();
  }

  Future<void> _rateOutfitAi() async {
    if (_aiRatingLoading) return;

    final topId = _asInt(_selected(_tops, _topIndex)?['id']);
    final bottomId = _asInt(_selected(_bottoms, _bottomIndex)?['id']);
    final shoesId = _asInt(_selected(_shoes, _shoesIndex)?['id']);
    if (topId == null || bottomId == null || shoesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select topwear, bottomwear, and shoes before AI rating.',
          ),
        ),
      );
      return;
    }

    final previousScore = _aiRatingScore;
    final hadSnapshot = _aiRatingScore != null;

    final payload = <String, dynamic>{
      'topwear_id': topId,
      'bottomwear_id': bottomId,
      'shoes_id': shoesId,
      'outerwear_id': _asInt(_selected(_outerwear, _outerwearIndex)?['id']),
      'accessory_ids': _accessoryIndices
          .map((i) => _asInt(_selected(_accessories, i)?['id']))
          .whereType<int>()
          .toList(),
    };
    if (_editingOutfitId != null) {
      payload['outfit_id'] = _editingOutfitId;
    }

    try {
      setState(() => _aiRatingLoading = true);
      final result = await _outfitService.rateAi(payload);
      if (!mounted) return;
      final newScore = _asDouble(result['ai_rating_score']);
      final scoreDelta =
          hadSnapshot && previousScore != null && newScore != null
          ? newScore - previousScore
          : null;
      final scoreUnchanged = scoreDelta != null && scoreDelta.abs() < 0.01;
      setState(() {
        _refreshAiSnapshot(result);
        _aiRatingDelta = scoreDelta;
      });
      final keepHint = _editingOutfitId == null
          ? ' Save this outfit to keep the AI rating.'
          : '';
      final message = scoreUnchanged
          ? 'AI rating refreshed: ${newScore!.toStringAsFixed(1)}/5.$keepHint'
          : 'AI rating updated${newScore == null ? '' : ': ${newScore.toStringAsFixed(1)}/5'}.$keepHint';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _aiRatingLoading = false);
      }
    }
  }

  Widget _buildCreationSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OutfitTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OutfitTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creation',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OutfitTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Outfit name *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _occasionCtrl,
            decoration: const InputDecoration(
              labelText: 'Occasion',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use slot taps above to adjust topwear, bottomwear, shoes, outerwear, and accessories.',
            style: TextStyle(fontSize: 11, color: OutfitTokens.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationSection() {
    final hasAiScore = _aiRatingScore != null;
    final canRate =
        _selected(_tops, _topIndex) != null &&
        _selected(_bottoms, _bottomIndex) != null &&
        _selected(_shoes, _shoesIndex) != null;
    final actionLabel = _aiRatingLoading
        ? 'Rating...'
        : !hasAiScore
        ? 'Rate Outfit'
        : _aiRatingStale
        ? 'Re-rate Outfit'
        : 'Refresh Rating';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OutfitTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OutfitTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Style Rating',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OutfitTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Evaluate this outfit after you finish creating it.',
            style: TextStyle(fontSize: 11, color: OutfitTokens.muted),
          ),
          if (hasAiScore && !_aiRatingStale) ...[
            const SizedBox(height: 4),
            const Text(
              'No item changes detected since last rating.',
              style: TextStyle(fontSize: 11, color: OutfitTokens.muted),
            ),
          ],
          if (!canRate) ...[
            const SizedBox(height: 4),
            const Text(
              'Select topwear, bottomwear, and shoes to enable AI rating.',
              style: TextStyle(fontSize: 11, color: OutfitTokens.muted),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_aiRatingLoading || !canRate) ? null : _rateOutfitAi,
              style: FilledButton.styleFrom(
                backgroundColor: OutfitTokens.accent,
                foregroundColor: OutfitTokens.white,
              ),
              icon: _aiRatingLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OutfitTokens.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(actionLabel),
            ),
          ),
          if (hasAiScore) ...[
            const SizedBox(height: 10),
            _AiRatingCard(
              score: _aiRatingScore!,
              reasons: _aiRatingReasons,
              breakdown: _aiRatingBreakdown,
              ratedAtText: _formatAiRatedAt(_aiRatedAt),
              scoreDelta: _aiRatingDelta,
              stale: _aiRatingStale,
            ),
          ],
        ],
      ),
    );
  }

  void _handleCanvasItemLongPress(String id) {
    if (id.startsWith('top-')) {
      _openSlotPicker('topwear');
      return;
    }
    if (id.startsWith('bottom-')) {
      _openSlotPicker('bottomwear');
      return;
    }
    if (id.startsWith('shoes-')) {
      _openSlotPicker('shoes');
      return;
    }
    if (id.startsWith('outerwear-')) {
      _openSlotPicker('outerwear');
      return;
    }
    if (id.startsWith('acc-')) {
      _openSlotPicker('accessories');
    }
  }

  List<EditableCanvasItem> _canvasPreviewItems() {
    final top = _selected(_tops, _topIndex);
    final bottom = _selected(_bottoms, _bottomIndex);
    final shoes = _selected(_shoes, _shoesIndex);
    final outerwear = _selected(_outerwear, _outerwearIndex);
    final accessories = _selectedAccessories();
    final items = <EditableCanvasItem>[];

    if (bottom != null) {
      items.add(
        EditableCanvasItem(
          id: 'bottom-${_asInt(bottom['id']) ?? 0}',
          label: 'Bottomwear',
          imageUrl: _imageOf(bottom),
          widthFactor: 0.5,
          heightFactor: 0.27,
          defaultOffset: const Offset(0, 0.23),
        ),
      );
    }
    if (top != null) {
      items.add(
        EditableCanvasItem(
          id: 'top-${_asInt(top['id']) ?? 0}',
          label: 'Topwear',
          imageUrl: _imageOf(top),
          widthFactor: 0.62,
          heightFactor: 0.28,
          defaultOffset: const Offset(0, -0.03),
        ),
      );
    }
    if (outerwear != null) {
      items.add(
        EditableCanvasItem(
          id: 'outerwear-${_asInt(outerwear['id']) ?? 0}',
          label: 'Outerwear',
          imageUrl: _imageOf(outerwear),
          widthFactor: 0.64,
          heightFactor: 0.24,
          defaultOffset: const Offset(0, -0.23),
        ),
      );
    }
    if (shoes != null) {
      items.add(
        EditableCanvasItem(
          id: 'shoes-${_asInt(shoes['id']) ?? 0}',
          label: 'Shoes',
          imageUrl: _imageOf(shoes),
          widthFactor: 0.46,
          heightFactor: 0.17,
          defaultOffset: const Offset(0, 0.41),
        ),
      );
    }
    for (var i = 0; i < accessories.length; i++) {
      final acc = accessories[i];
      final col = i % 4;
      final row = i ~/ 4;
      items.add(
        EditableCanvasItem(
          id: 'acc-${_asInt(acc['id']) ?? i}',
          label: 'Accessory',
          imageUrl: _imageOf(acc),
          widthFactor: 0.17,
          heightFactor: 0.11,
          defaultOffset: Offset(-0.225 + (col * 0.15), 0.5 - (row * 0.09)),
        ),
      );
    }

    return items.where((item) => item.imageUrl.isNotEmpty).toList();
  }

  Map<String, EditableCanvasTransform> _layoutToTransforms(
    Map<String, dynamic> layout,
  ) {
    final out = <String, EditableCanvasTransform>{};
    layout.forEach((key, value) {
      if (value is! Map) return;
      final x = (value['offset_x'] is num)
          ? (value['offset_x'] as num).toDouble()
          : double.tryParse('${value['offset_x']}');
      final y = (value['offset_y'] is num)
          ? (value['offset_y'] as num).toDouble()
          : double.tryParse('${value['offset_y']}');
      final s = (value['scale'] is num)
          ? (value['scale'] as num).toDouble()
          : double.tryParse('${value['scale']}');
      if (x == null || y == null || s == null) return;
      out[key] = EditableCanvasTransform(offset: Offset(x, y), scale: s);
    });
    return out;
  }

  Map<String, dynamic> _transformsToLayout(
    Map<String, EditableCanvasTransform> transforms,
  ) {
    final out = <String, dynamic>{};
    transforms.forEach((key, value) {
      out[key] = {
        'offset_x': value.offset.dx,
        'offset_y': value.offset.dy,
        'scale': value.scale,
      };
    });
    return out;
  }

  Map<String, dynamic> _layoutForSave() {
    final items = _canvasPreviewItems();
    if (items.isEmpty) return {};

    final existing = _layoutToTransforms(_previewLayout);
    final effective = <String, EditableCanvasTransform>{};
    for (final item in items) {
      effective[item.id] =
          existing[item.id] ??
          EditableCanvasTransform(offset: item.defaultOffset, scale: 1.0);
    }
    return _transformsToLayout(effective);
  }

  List<Map<String, dynamic>> _selectedAccessories() {
    return _accessoryIndices
        .map((i) => _selected(_accessories, i))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _handleSlotTap(String slot) => _openSlotPicker(slot);

  Future<void> _openSlotPicker(String slot) async {
    switch (slot) {
      case 'topwear':
        await _showSingleSlotPicker(
          title: 'Select Topwear',
          items: _tops,
          selectedIndex: _topIndex,
          onSelect: (index) => setState(() {
            if (_topIndex != index) {
              _topIndex = index;
              _markAiRatingStale();
            }
          }),
        );
        break;
      case 'bottomwear':
        await _showSingleSlotPicker(
          title: 'Select Bottomwear',
          items: _bottoms,
          selectedIndex: _bottomIndex,
          onSelect: (index) => setState(() {
            if (_bottomIndex != index) {
              _bottomIndex = index;
              _markAiRatingStale();
            }
          }),
        );
        break;
      case 'shoes':
        await _showSingleSlotPicker(
          title: 'Select Shoes',
          items: _shoes,
          selectedIndex: _shoesIndex,
          onSelect: (index) => setState(() {
            if (_shoesIndex != index) {
              _shoesIndex = index;
              _markAiRatingStale();
            }
          }),
        );
        break;
      case 'outerwear':
        await _showSingleSlotPicker(
          title: 'Select Outerwear',
          items: _outerwear,
          selectedIndex: _outerwearIndex,
          optionalNone: true,
          onSelect: (index) => setState(() {
            if (_outerwearIndex != index) {
              _outerwearIndex = index;
              _markAiRatingStale();
            }
          }),
        );
        break;
      case 'accessories':
        await _showAccessoryPicker();
        break;
    }
  }

  Future<void> _showSingleSlotPicker({
    required String title,
    required List<Map<String, dynamic>> items,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    bool optionalNone = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OutfitTokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final pickerHeight = (MediaQuery.of(context).size.height * 0.55)
            .clamp(260.0, 460.0)
            .toDouble();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openAddAndRefresh();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: WidgetTokens.accent,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'No items found in this category yet.',
                      style: TextStyle(color: OutfitTokens.muted),
                    ),
                  )
                else
                  SizedBox(
                    height: pickerHeight,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.74,
                          ),
                      itemCount: items.length + (optionalNone ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (optionalNone && index == 0) {
                          final isSelected = selectedIndex == -1;
                          return GestureDetector(
                            onTap: () {
                              onSelect(-1);
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? OutfitTokens.tagBg
                                    : OutfitTokens.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? OutfitTokens.ink
                                      : OutfitTokens.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 20,
                                    color: OutfitTokens.muted,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'None',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final itemIndex = optionalNone ? index - 1 : index;
                        return _ItemTile(
                          item: items[itemIndex],
                          selected: selectedIndex == itemIndex,
                          onTap: () {
                            onSelect(itemIndex);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAccessoryPicker() async {
    final working = Set<int>.from(_accessoryIndices);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OutfitTokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pickerHeight = (MediaQuery.of(context).size.height * 0.55)
                .clamp(260.0, 460.0)
                .toDouble();
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Select Accessories',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openAddAndRefresh();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: WidgetTokens.accent,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_accessories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'No accessories found yet.',
                          style: TextStyle(color: OutfitTokens.muted),
                        ),
                      )
                    else
                      SizedBox(
                        height: pickerHeight,
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.74,
                              ),
                          itemCount: _accessories.length,
                          itemBuilder: (context, index) => _ItemTile(
                            item: _accessories[index],
                            selected: working.contains(index),
                            multiSelect: true,
                            onTap: () {
                              setModalState(() {
                                if (working.contains(index)) {
                                  working.remove(index);
                                } else {
                                  working.add(index);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final previous = Set<int>.from(_accessoryIndices);
                          setState(() {
                            _accessoryIndices
                              ..clear()
                              ..addAll(working);
                            final changed =
                                previous.length != _accessoryIndices.length ||
                                previous.any(
                                  (item) => !_accessoryIndices.contains(item),
                                );
                            if (changed) {
                              _markAiRatingStale();
                            }
                          });
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: OutfitTokens.ink,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic>? _selected(List<Map<String, dynamic>> items, int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  Map<String, dynamic>? _slotMap(Map<String, dynamic> outfit, String key) {
    final raw = outfit[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  int _indexById(List<Map<String, dynamic>> items, int id) {
    for (int i = 0; i < items.length; i++) {
      if (_asInt(items[i]['id']) == id) return i;
    }
    return -1;
  }

  double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatAiRatedAt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value < 10 ? '0$value' : '$value';

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _imageOf(Map<String, dynamic> item) {
    final raw = (item['image'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiClient.host}$raw';
    return '${ApiClient.host}/$raw';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline strip components for the builder panel
// ─────────────────────────────────────────────────────────────────────────────

class OutfitDetailPage extends StatefulWidget {
  final Map<String, dynamic> initialOutfit;

  const OutfitDetailPage({super.key, required this.initialOutfit});

  @override
  State<OutfitDetailPage> createState() => _OutfitDetailPageState();
}

class _OutfitDetailPageState extends State<OutfitDetailPage> {
  final OutfitService _outfitService = ServiceRegistry.instance.outfitService;

  Map<String, dynamic>? _outfit;
  bool _loading = true;
  bool _updatingFav = false;
  bool _savingRating = false;
  bool _markingWorn = false;
  bool _aiRatingLoading = false;
  bool _ratingOutdated = false;
  double? _aiRatingDelta;

  bool _isWornToday(Map<String, dynamic>? outfit) {
    final raw = outfit?['last_worn_at'];
    if (raw == null) return false;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return false;
    final local = parsed.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  int? get _outfitId => _asInt(_outfit?['id']);

  @override
  void initState() {
    super.initState();
    _outfit = widget.initialOutfit;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = _asInt(widget.initialOutfit['id']);
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final latest = await _outfitService.getById(id);
    if (!mounted) return;
    setState(() {
      _outfit = latest ?? widget.initialOutfit;
      _aiRatingDelta = null;
      _loading = false;
      // If the backend cleared the AI score (e.g. items changed), clear
      // the outdated flag so the UI shows "No AI rating yet" instead of
      // a stale "Rating outdated" banner with nothing beneath it.
      if (_asDouble(_outfit?['ai_rating_score']) == null) {
        _ratingOutdated = false;
      }
    });
  }

  Future<void> _toggleFavourite() async {
    final id = _outfitId;
    if (id == null || _updatingFav) return;
    setState(() => _updatingFav = true);
    final result = await _outfitService.toggleFavourite(id);
    if (!mounted) return;
    setState(() {
      if (result != null) _outfit = result;
      _updatingFav = false;
    });
  }

  Future<void> _setRating(int value) async {
    final id = _outfitId;
    if (id == null || _savingRating) return;
    setState(() => _savingRating = true);
    final updated = await _outfitService.updatePartial(id, {'rating': value});
    if (!mounted) return;
    setState(() {
      if (updated != null) _outfit = updated;
      _savingRating = false;
    });
  }

  Future<void> _rateWithAi() async {
    final outfit = _outfit;
    final id = _outfitId;
    if (outfit == null || id == null || _aiRatingLoading) return;

    final topwearId = _slotId(outfit, 'topwear_item');
    final bottomwearId = _slotId(outfit, 'bottomwear_item');
    final shoesId = _slotId(outfit, 'shoes_item');
    if (topwearId == null || bottomwearId == null || shoesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select topwear, bottomwear, and shoes before AI rating.',
          ),
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'outfit_id': id,
      'topwear_id': topwearId,
      'bottomwear_id': bottomwearId,
      'shoes_id': shoesId,
      'outerwear_id': _slotId(outfit, 'outerwear_item'),
      'accessory_ids': _accessoryIds(outfit),
    };

    final previousScore = _asDouble(outfit['ai_rating_score']);
    final hadSnapshot = previousScore != null;

    try {
      setState(() => _aiRatingLoading = true);
      final result = await _outfitService.rateAi(payload);
      if (!mounted) return;

      final newScore = _asDouble(result['ai_rating_score']);
      final scoreDelta = hadSnapshot && newScore != null
          ? newScore - previousScore
          : null;
      final scoreUnchanged = scoreDelta != null && scoreDelta.abs() < 0.01;

      setState(() {
        _outfit = {
          ...outfit,
          'ai_rating_score': result['ai_rating_score'],
          'ai_rating_reasons': result['ai_rating_reasons'],
          'ai_rating_breakdown': result['ai_rating_breakdown'],
          'ai_rated_at': result['ai_rated_at'],
        };
        _ratingOutdated = false;
        _aiRatingDelta = scoreDelta;
      });

      final message = scoreUnchanged
          ? 'AI rating refreshed: ${newScore!.toStringAsFixed(1)}/5.'
          : 'AI rating updated${newScore == null ? '' : ': ${newScore.toStringAsFixed(1)}/5'}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _aiRatingLoading = false);
      }
    }
  }

  bool _hasAiSnapshot(Map<String, dynamic>? outfit) {
    return _asDouble(outfit?['ai_rating_score']) != null;
  }

  bool _itemsChanged(
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  ) {
    if (before == null || after == null) return false;
    if (_slotId(before, 'topwear_item') != _slotId(after, 'topwear_item')) {
      return true;
    }
    if (_slotId(before, 'bottomwear_item') !=
        _slotId(after, 'bottomwear_item')) {
      return true;
    }
    if (_slotId(before, 'shoes_item') != _slotId(after, 'shoes_item')) {
      return true;
    }
    if (_slotId(before, 'outerwear_item') != _slotId(after, 'outerwear_item')) {
      return true;
    }
    final beforeAccessories = _accessoryIds(before).toSet();
    final afterAccessories = _accessoryIds(after).toSet();
    if (beforeAccessories.length != afterAccessories.length) {
      return true;
    }
    return beforeAccessories.any((id) => !afterAccessories.contains(id));
  }

  int? _slotId(Map<String, dynamic>? outfit, String key) {
    final item = outfit == null ? null : _slot(outfit, key);
    return _asInt(item?['id']);
  }

  List<int> _accessoryIds(Map<String, dynamic>? outfit) {
    if (outfit == null) return const [];
    return _accessoryList(
      outfit,
    ).map((item) => _asInt(item['id'])).whereType<int>().toList();
  }

  Future<void> _markWorn() async {
    final id = _outfitId;
    if (id == null || _markingWorn) return;
    if (_isWornToday(_outfit)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This outfit is already marked worn today'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _markingWorn = true);
    final updated = await _outfitService.markWorn(id);
    if (!mounted) return;
    setState(() {
      if (updated != null) _outfit = updated;
      _markingWorn = false;
    });
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update wear count')),
      );
    } else if (_isWornToday(updated)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as worn for today'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editOutfit() async {
    final outfit = _outfit;
    if (outfit == null) return;
    final before = Map<String, dynamic>.from(outfit);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(existingOutfit: outfit),
      ),
    );
    if (changed == true) {
      await _loadDetail();
      if (!mounted) return;
      if (_hasAiSnapshot(before) && _itemsChanged(before, _outfit)) {
        setState(() {
          _ratingOutdated = true;
          _aiRatingDelta = null;
        });
      }
    }
  }

  Future<void> _deleteOutfit() async {
    final id = _outfitId;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete outfit?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: OutfitTokens.dangerStrong,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _outfitService.delete(id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete outfit')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfit = _outfit;
    final name = (outfit?['name'] ?? 'Outfit').toString();
    final occasion = (outfit?['occasion'] ?? 'Any Occasion').toString();
    final ratingValue = _asInt(outfit?['rating']) ?? 0;
    final aiRatingScore = _asDouble(outfit?['ai_rating_score']);
    final aiRatingReasons = _stringList(outfit?['ai_rating_reasons']);
    final rawBreakdown = outfit?['ai_rating_breakdown'];
    final aiRatingBreakdown = rawBreakdown is Map<String, dynamic>
        ? rawBreakdown
        : rawBreakdown is Map
            ? Map<String, dynamic>.from(rawBreakdown)
            : const <String, dynamic>{};
    final aiRatedAtText = _formatDate(outfit?['ai_rated_at']?.toString());
    final wearCount = _asInt(outfit?['wear_count']) ?? 0;
    final lastWornAt = _formatDate(outfit?['last_worn_at']?.toString());
    final alreadyWornToday = _isWornToday(outfit);
    final isFav = outfit?['is_favourite'] == true;
    final createdAt = _formatDate(outfit?['created_at']?.toString());
    final canRateAi =
        _slotId(outfit, 'topwear_item') != null &&
        _slotId(outfit, 'bottomwear_item') != null &&
        _slotId(outfit, 'shoes_item') != null;
    final detailAiActionLabel = _aiRatingLoading
        ? 'Rating...'
        : aiRatingScore == null
        ? 'Rate with AI'
        : _ratingOutdated
        ? 'Re-rate Outfit'
        : 'Refresh Rating';
    final previewItems = outfit == null
        ? const <EditableCanvasItem>[]
        : _previewItems(outfit);
    final previewTransforms = outfit == null
        ? const <String, EditableCanvasTransform>{}
        : _layoutToTransforms(_previewLayout(outfit));
    final storageRows = _clothingStorageRows(outfit);

    return Scaffold(
      backgroundColor: OutfitTokens.bg,
      appBar: AppBar(
        backgroundColor: OutfitTokens.surface,
        foregroundColor: OutfitTokens.ink,
        title: const Text('Outfit Detail'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : outfit == null
          ? const Center(child: Text('Outfit not found'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                previewItems.isNotEmpty
                    ? EditableOutfitCanvas(
                        items: previewItems,
                        initialTransforms: previewTransforms,
                        interactive: false,
                      )
                    : OutfitCanvas(
                        outerwear: _slot(outfit, 'outerwear_item'),
                        topwear: _slot(outfit, 'topwear_item'),
                        bottomwear: _slot(outfit, 'bottomwear_item'),
                        shoes: _slot(outfit, 'shoes_item'),
                        accessories: _accessoryList(outfit),
                      ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OutfitTokens.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OutfitTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Style Rating',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_aiRatingLoading || !canRateAi)
                              ? null
                              : _rateWithAi,
                          style: FilledButton.styleFrom(
                            backgroundColor: OutfitTokens.accent,
                            foregroundColor: OutfitTokens.white,
                          ),
                          icon: _aiRatingLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: OutfitTokens.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: Text(detailAiActionLabel),
                        ),
                      ),
                      if (!canRateAi) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'This outfit needs topwear, bottomwear, and shoes before AI rating.',
                          style: TextStyle(
                            fontSize: 11,
                            color: OutfitTokens.muted,
                          ),
                        ),
                      ],
                      if (aiRatingScore != null && !_ratingOutdated) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'No item changes detected since last rating.',
                          style: TextStyle(
                            fontSize: 11,
                            color: OutfitTokens.muted,
                          ),
                        ),
                      ],
                      if (_ratingOutdated) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: OutfitTokens.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: OutfitTokens.warning),
                          ),
                          child: const Text(
                            'Rating outdated. Re-rate for an updated AI score.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OutfitTokens.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (aiRatingScore != null) ...[
                        const SizedBox(height: 10),
                        _AiRatingCard(
                          score: aiRatingScore,
                          reasons: aiRatingReasons,
                          breakdown: aiRatingBreakdown,
                          ratedAtText: aiRatedAtText,
                          scoreDelta: _aiRatingDelta,
                          stale: _ratingOutdated,
                        ),
                      ],
                      if (aiRatingScore == null && !_ratingOutdated)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'No AI rating yet. Rate this outfit when you want evaluation feedback.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OutfitTokens.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OutfitTokens.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OutfitTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outfit Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow('Occasion', occasion),
                      _InfoRow(
                        'Worn',
                        wearCount == 0 ? 'Not yet' : '$wearCount times',
                      ),
                      _InfoRow(
                        'Last worn',
                        lastWornAt == '-' ? 'Not yet' : lastWornAt,
                      ),
                      _InfoRow('Created', createdAt),
                      if (storageRows.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Where to Find Pieces',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OutfitTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final row in storageRows)
                          _StorageInfoRow(
                            label: row.label,
                            value: row.value,
                            onTap: row.storageId == null
                                ? null
                                : () => _openStorageDetail(row.storageId!),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Rating: ',
                            style: TextStyle(
                              color: OutfitTokens.muted,
                              fontSize: 13,
                            ),
                          ),
                          _StarRatingBar(
                            rating: ratingValue,
                            onSelected: _setRating,
                          ),
                          if (_savingRating) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'Saving...',
                              style: TextStyle(
                                fontSize: 12,
                                color: OutfitTokens.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_markingWorn || alreadyWornToday)
                        ? null
                        : _markWorn,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _markingWorn
                          ? 'Updating...'
                          : (alreadyWornToday ? 'Worn today' : 'Mark as worn'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: OutfitTokens.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _updatingFav ? null : _toggleFavourite,
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? OutfitTokens.danger : null,
                    ),
                    label: Text(isFav ? 'Unfavourite' : 'Favourite'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _editOutfit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleteOutfit,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OutfitTokens.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Map<String, dynamic>? _slot(Map<String, dynamic> outfit, String key) {
    final raw = outfit[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  List<Map<String, dynamic>> _accessoryList(Map<String, dynamic> outfit) {
    final raw = outfit['accessory_items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<void> _openStorageDetail(int storageId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorageDetailScreen(storageId: storageId),
      ),
    );
  }

  List<_StorageLocationRow> _clothingStorageRows(
    Map<String, dynamic>? outfit,
  ) {
    if (outfit == null) return [];

    final rows = <_StorageLocationRow>[];

    void addRow(String label, String key, {bool optional = false}) {
      final item = _slot(outfit, key);
      if (item == null) {
        if (!optional) {
          rows.add(_StorageLocationRow(label: label, value: 'Not selected'));
        }
        return;
      }
      final itemName = _clothingDisplayName(item);
      final storage = _storageUnitMap(item['storage_unit']);
      final storagePath = _storagePath(storage);
      final storageId = _asInt(storage?['id']);
      rows.add(
        _StorageLocationRow(
          label: label,
          value: '$itemName - $storagePath',
          storageId: storageId,
        ),
      );
    }

    addRow('Topwear', 'topwear_item');
    addRow('Bottomwear', 'bottomwear_item');
    addRow('Shoes', 'shoes_item');
    addRow('Outerwear', 'outerwear_item', optional: true);

    return rows;
  }

  String _clothingDisplayName(Map<String, dynamic> item) {
    final subcategory = (item['subcategory'] ?? '').toString().trim();
    if (subcategory.isNotEmpty) return subcategory;
    final category = (item['category'] ?? '').toString().trim();
    if (category.isNotEmpty) return category;
    return 'Item';
  }

  Map<String, dynamic>? _storageUnitMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _storagePath(Map<String, dynamic>? storage) {
    if (storage == null) return 'Storage unknown';

    final parts = <String>[];
    final seenIds = <int>{};
    Map<String, dynamic>? current = storage;

    while (current != null) {
      final id = _asInt(current['id']);
      if (id != null && !seenIds.add(id)) break;
      final label = _storageNodeLabel(current);
      if (label.isNotEmpty) {
        parts.add(label);
      }
      current = _storageUnitMap(current['parent_storage']);
    }

    if (parts.isEmpty) return 'Storage unknown';
    return parts.reversed.join(' > ');
  }

  String _storageNodeLabel(Map<String, dynamic> storage) {
    final name = (storage['name'] ?? '').toString().trim();
    final type = _humanizeStorageType((storage['type'] ?? '').toString());
    if (name.isEmpty) return type;
    if (type.isEmpty) return name;
    return '$name ($type)';
  }

  String _humanizeStorageType(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Map<String, dynamic> _previewLayout(Map<String, dynamic> outfit) {
    final raw = outfit['preview_layout'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<EditableCanvasItem> _previewItems(Map<String, dynamic> outfit) {
    final top = _slot(outfit, 'topwear_item');
    final bottom = _slot(outfit, 'bottomwear_item');
    final shoes = _slot(outfit, 'shoes_item');
    final outerwear = _slot(outfit, 'outerwear_item');
    final accs = _accessoryList(outfit);
    final items = <EditableCanvasItem>[];
    if (bottom != null) {
      items.add(
        EditableCanvasItem(
          id: 'bottom-${_asInt(bottom['id']) ?? 0}',
          label: 'Bottomwear',
          imageUrl: _imageOf(bottom),
          widthFactor: 0.5,
          heightFactor: 0.27,
          defaultOffset: const Offset(0, 0.23),
        ),
      );
    }
    if (top != null) {
      items.add(
        EditableCanvasItem(
          id: 'top-${_asInt(top['id']) ?? 0}',
          label: 'Topwear',
          imageUrl: _imageOf(top),
          widthFactor: 0.62,
          heightFactor: 0.28,
          defaultOffset: const Offset(0, -0.03),
        ),
      );
    }
    if (outerwear != null) {
      items.add(
        EditableCanvasItem(
          id: 'outerwear-${_asInt(outerwear['id']) ?? 0}',
          label: 'Outerwear',
          imageUrl: _imageOf(outerwear),
          widthFactor: 0.64,
          heightFactor: 0.24,
          defaultOffset: const Offset(0, -0.23),
        ),
      );
    }
    if (shoes != null) {
      items.add(
        EditableCanvasItem(
          id: 'shoes-${_asInt(shoes['id']) ?? 0}',
          label: 'Shoes',
          imageUrl: _imageOf(shoes),
          widthFactor: 0.46,
          heightFactor: 0.17,
          defaultOffset: const Offset(0, 0.41),
        ),
      );
    }
    for (var i = 0; i < accs.length; i++) {
      final acc = accs[i];
      final col = i % 4;
      final row = i ~/ 4;
      items.add(
        EditableCanvasItem(
          id: 'acc-${_asInt(acc['id']) ?? i}',
          label: 'Accessory',
          imageUrl: _imageOf(acc),
          widthFactor: 0.17,
          heightFactor: 0.11,
          defaultOffset: Offset(-0.225 + (col * 0.15), 0.5 - (row * 0.09)),
        ),
      );
    }
    return items.where((item) => item.imageUrl.isNotEmpty).toList();
  }

  Map<String, EditableCanvasTransform> _layoutToTransforms(
    Map<String, dynamic> layout,
  ) {
    final out = <String, EditableCanvasTransform>{};
    layout.forEach((key, value) {
      if (value is! Map) return;
      final x = (value['offset_x'] is num)
          ? (value['offset_x'] as num).toDouble()
          : double.tryParse('${value['offset_x']}');
      final y = (value['offset_y'] is num)
          ? (value['offset_y'] as num).toDouble()
          : double.tryParse('${value['offset_y']}');
      final s = (value['scale'] is num)
          ? (value['scale'] as num).toDouble()
          : double.tryParse('${value['scale']}');
      if (x == null || y == null || s == null) return;
      out[key] = EditableCanvasTransform(offset: Offset(x, y), scale: s);
    });
    return out;
  }

  String _imageOf(Map<String, dynamic> item) {
    final raw = (item['image'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiClient.host}$raw';
    return '${ApiClient.host}/$raw';
  }

  double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final date = '${months[local.month - 1]} ${local.day}, ${local.year}';
    final time = '${_two(local.hour)}:${_two(local.minute)}';
    return '$date · $time';
  }

  String _two(int value) => value < 10 ? '0$value' : '$value';
}

class _AiRatingCard extends StatelessWidget {
  final double score;
  final List<String> reasons;
  final Map<String, dynamic> breakdown;
  final String ratedAtText;
  final double? scoreDelta;
  final bool stale;

  const _AiRatingCard({
    required this.score,
    required this.reasons,
    this.breakdown = const {},
    required this.ratedAtText,
    this.scoreDelta,
    this.stale = false,
  });

  double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  List<String> _fallbackFromBreakdown() {
    final clip = _asDouble(breakdown['clip']);
    final color = _asDouble(breakdown['color_harmony']);
    final dressLevel = _asDouble(
      breakdown['dress_level_consistency'] ??
          breakdown['formality_consistency'] ??
          breakdown['neutral_weather_fit'],
    );

    // Thresholds match the backend _strength_reason / _improvement_reason logic.
    final cohesionLine = clip == null
        ? 'Style cohesion is moderate with room to refine.'
        : clip >= 0.80
            ? 'Strong style cohesion — the pieces read as one intentional look.'
            : clip >= 0.65
                ? 'Style cohesion is decent; one swap could tighten it further.'
                : 'Style cohesion is weak — align silhouettes and vibe more closely.';

    final colorLine = color == null
        ? 'Color balance is fairly consistent.'
        : color >= 0.80
            ? 'Color harmony is a clear strength of this outfit.'
            : color >= 0.65
                ? 'Color balance works, though the palette could be simplified.'
                : 'Color pairing feels crowded — simplify to one accent tone.';

    String improvementLine;
    if (clip != null && color != null && dressLevel != null) {
      if (clip <= color && clip <= dressLevel) {
        improvementLine =
            'Biggest gain: tighten cohesion by swapping one piece to match the styling direction.';
      } else if (color <= clip && color <= dressLevel) {
        improvementLine =
            'Biggest gain: simplify the palette — one dominant accent with neutrals supporting it.';
      } else {
        improvementLine =
            'Biggest gain: align the dress level — keep all pieces in the same occasion register.';
      }
    } else {
      improvementLine = 'Try one focused swap to improve the overall balance.';
    }

    return [cohesionLine, colorLine, improvementLine];
  }

  List<String> _feedbackLines() {
    final cleaned = <String>[];
    final seen = <String>{};
    for (final raw in reasons) {
      final reason = raw.trim();
      if (reason.isEmpty) continue;
      final key = reason.toLowerCase();
      if (seen.add(key)) {
        cleaned.add(reason);
      }
    }

    for (final line in _fallbackFromBreakdown()) {
      if (cleaned.length >= 3) break;
      final key = line.toLowerCase();
      if (seen.add(key)) {
        cleaned.add(line);
      }
    }

    const fallback = [
      'Balanced overall composition.',
      'Color pairing is generally coherent.',
      'Try swapping one item for stronger contrast.',
    ];
    for (final line in fallback) {
      if (cleaned.length >= 3) break;
      final key = line.toLowerCase();
      if (seen.add(key)) {
        cleaned.add(line);
      }
    }

    return cleaned.take(3).toList();
  }

  bool get _hasScoreDelta => scoreDelta != null;

  bool get _scoreUnchanged => _hasScoreDelta && scoreDelta!.abs() < 0.01;

  String get _scoreDeltaLabel {
    if (!_hasScoreDelta) return '';
    if (_scoreUnchanged) return 'no change';
    final sign = scoreDelta! > 0 ? '+' : '';
    return '$sign${scoreDelta!.toStringAsFixed(1)}';
  }

  IconData get _scoreDeltaIcon {
    if (!_hasScoreDelta || _scoreUnchanged) return Icons.remove_rounded;
    return scoreDelta! > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
  }

  Color get _scoreDeltaColor {
    if (!_hasScoreDelta || _scoreUnchanged) return OutfitTokens.muted;
    return scoreDelta! > 0 ? OutfitTokens.accent : OutfitTokens.danger;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _feedbackLines();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OutfitTokens.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stale ? OutfitTokens.warning : OutfitTokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Style Score',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OutfitTokens.muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${score.toStringAsFixed(1)} / 5',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: OutfitTokens.ink,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: OutfitTokens.warning,
              ),
              if (_hasScoreDelta) ...[
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final deltaColor = _scoreDeltaColor;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: deltaColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: deltaColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_scoreDeltaIcon, size: 12, color: deltaColor),
                          const SizedBox(width: 3),
                          Text(
                            _scoreDeltaLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: deltaColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          if (ratedAtText.trim().isNotEmpty && ratedAtText != '-') ...[
            const SizedBox(height: 4),
            Text(
              'Rated $ratedAtText',
              style: const TextStyle(fontSize: 11, color: OutfitTokens.muted),
            ),
          ],
          const SizedBox(height: 8),
          Text('- ${lines[0]}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text('- ${lines[1]}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text('- ${lines[2]}', style: const TextStyle(fontSize: 12)),
          if (stale)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Rating outdated. Re-rate to refresh this score.',
                style: TextStyle(
                  fontSize: 11,
                  color: OutfitTokens.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StorageLocationRow {
  final String label;
  final String value;
  final int? storageId;

  const _StorageLocationRow({
    required this.label,
    required this.value,
    this.storageId,
  });
}

class _StorageInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StorageInfoRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: onTap == null ? OutfitTokens.ink : OutfitTokens.accent,
      decoration: onTap == null
          ? TextDecoration.none
          : TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(
                '$label: ',
                style: const TextStyle(
                  color: OutfitTokens.muted,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: valueStyle,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: OutfitTokens.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: OutfitTokens.muted, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRatingBar extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onSelected;

  const _StarRatingBar({required this.rating, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        final isActive = value <= rating;
        return IconButton(
          onPressed: () => onSelected(value),
          icon: Icon(
            isActive ? Icons.star_rounded : Icons.star_border_rounded,
            color: isActive ? OutfitTokens.warning : OutfitTokens.mutedSoft,
          ),
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: '$value stars',
        );
      }),
    );
  }
}
