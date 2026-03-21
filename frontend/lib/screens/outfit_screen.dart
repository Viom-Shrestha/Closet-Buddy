import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/accessory_service.dart';
import '../services/clothing_service.dart';
import '../services/outfit_service.dart';
import '../widgets/editable_outfit_canvas.dart';
import '../widgets/outfit_canvas.dart';
import 'add_item_screen.dart';
import 'recommendation_screen.dart';
import '../utils/outfit_slot_rules.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens shared across the page
// ─────────────────────────────────────────────────────────────────────────────

const _kBg = Color(0xFFF7F5F2);
const _kWhite = Colors.white;
const _kInk = Color(0xFF0F0F0F);
const _kMuted = Color(0xFF9A8F7F);
const _kBorder = Color(0xFFE8E3DB);
const _kAccent = Color(0xFFC9A96E);
const _kTagBg = Color(0xFFF0ECE5);

// ═════════════════════════════════════════════════════════════════════════════
// OutfitsPage — gallery of saved outfits
// ═════════════════════════════════════════════════════════════════════════════

class OutfitsPage extends StatefulWidget {
  final bool embedded;

  const OutfitsPage({super.key, this.embedded = false});

  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> {
  final OutfitService _outfitService = OutfitService();

  List<Map<String, dynamic>> _outfits = [];
  bool _loading = true;
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    setState(() => _loading = true);
    final outfits = await _outfitService.getAll();
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
        builder: (_) => const RecommendationScreen(
          title: 'Outfit Generation',
        ),
      ),
    );
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

  Future<void> _openEditFromCard(Map<String, dynamic> outfit) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(existingOutfit: outfit),
      ),
    );
    if (changed == true) _loadOutfits();
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                    '$total Saved ${total == 1 ? 'Outfit' : 'Outfits'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
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
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final crossAxisCount = width > 900
                          ? 4
                          : width > 700
                          ? 3
                          : 2;
                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final outfit = _outfits[index];
                            final id = outfit['id'] is int
                                ? outfit['id'] as int
                                : int.tryParse('${outfit['id']}');
                            final selected = id != null && _selectedIds.contains(id);
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
                          },
                          childCount: _outfits.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.45,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_selectMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
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
                        color: Colors.white,
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
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Outfits'),
        backgroundColor: _kWhite,
        foregroundColor: _kInk,
      ),
      body: page,
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.checkroom_outlined, size: 34, color: _kMuted),
          SizedBox(height: 10),
          Text('No outfits yet'),
          SizedBox(height: 4),
          Text(
            'Build your first look and it will appear here.',
            style: TextStyle(fontSize: 12, color: _kMuted),
            textAlign: TextAlign.center,
          ),
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
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Build and review your saved looks.',
            style: TextStyle(color: Color(0xFFD1D5DB)),
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
                    backgroundColor: Colors.white,
                    foregroundColor: _kInk,
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
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF9CA3AF)),
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
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                selectMode
                    ? 'Exit selection ($selectedCount)'
                    : 'Select outfits',
                style: const TextStyle(color: Colors.white),
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
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
    final rating = outfit['rating']?.toString() ?? '-';
    final wearCount = _asInt(outfit['wear_count']) ?? 0;
    final isFav = outfit['is_favourite'] == true;
    final previewItems = _previewItems(outfit);
    final previewTransforms = _layoutToTransforms(_previewLayout(outfit));

    return GestureDetector(
      onTap: () => onTap(outfit),
      onLongPress: () => onLongPress(outfit),
      child: Container(
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAccent : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.55,
              child: Padding(
                padding: const EdgeInsets.all(8),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    occasion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 13,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 3),
                      Text(rating, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECE5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${wearCount}x worn',
                          style: const TextStyle(fontSize: 10, color: _kMuted),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 15,
                        color: isFav ? const Color(0xFFDC2626) : _kMuted,
                      ),
                      if (selectionMode) ...[
                        const SizedBox(width: 8),
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: selected ? _kAccent : _kMuted,
                        ),
                      ],
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
  final AccessoryService _accessoryService = AccessoryService();
  final ClothingService _clothingService = ClothingService();

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
      _clothingService.getAllClothes(),
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
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kWhite,
        foregroundColor: _kInk,
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
                    backgroundColor: _kInk,
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
        Expanded(child: Divider(color: _kBorder)),
        const SizedBox(width: 12),
        Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kInk,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: _kMuted),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: _kBorder)),
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
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
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
                    color: _kTagBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 10, color: _kMuted),
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
              style: const TextStyle(fontSize: 12, color: _kMuted),
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
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
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
                    color: _kTagBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 10, color: _kMuted),
                  ),
                ),
              const Spacer(),
              if (selectedIndices.isNotEmpty)
                Text(
                  '${selectedIndices.length} selected',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty) ...[
            const Text(
              'No accessories found. Add watches, belts, bags, etc.',
              style: TextStyle(fontSize: 12, color: _kMuted),
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
          color: selected ? const Color(0xFFF5F2EE) : _kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kInk : _kBorder,
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
                            color: _kMuted,
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
                          color: _kInk,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
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
  final AccessoryService _accessoryService = AccessoryService();
  final ClothingService _clothingService = ClothingService();
  final OutfitService _outfitService = OutfitService();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _occasionCtrl = TextEditingController();
  int _ratingValue = 0;

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
  String _silhouette = 'male';
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
    final rating = e['rating'];
    if (rating != null) {
      _ratingValue = _asInt(rating) ?? 0;
    }
    _silhouette =
        (e['silhouette'] ?? 'male').toString().toLowerCase() == 'female'
        ? 'female'
        : 'male';
    final rawPreview = e['preview_layout'];
    if (rawPreview is Map<String, dynamic>) {
      _previewLayout = rawPreview;
    } else if (rawPreview is Map) {
      _previewLayout = Map<String, dynamic>.from(rawPreview);
    }
  }

  Future<void> _loadClothes() async {
    final results = await Future.wait([
      _clothingService.getAllClothes(),
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

    final rating = _ratingValue > 0 ? _ratingValue : null;

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'name': name,
      'occasion': _occasionCtrl.text.trim().isEmpty
          ? null
          : _occasionCtrl.text.trim(),
      'rating': rating,
      'silhouette': _silhouette,
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final previewItems = _canvasPreviewItems();
    final previewTransforms = _layoutToTransforms(_previewLayout);
    final builderCanvasHeight = (MediaQuery.of(context).size.width * 1.7)
        .clamp(620.0, 820.0)
        .toDouble();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kWhite,
        foregroundColor: _kInk,
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
                              color: _kMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (previewItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _kWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kBorder),
                              ),
                              child: const Text(
                                'Select items to enable freeform canvas.',
                                style: TextStyle(fontSize: 12, color: _kMuted),
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
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Static Slot Preview',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
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
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                          const SizedBox(height: 10),
                          _buildInlineDetailsPanel(),
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
                              backgroundColor: _kInk,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
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

  Widget _buildInlineDetailsPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Outfit name *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _occasionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Occasion',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Rating',
                          style: TextStyle(fontSize: 12, color: _kMuted),
                        ),
                        const SizedBox(width: 10),
                        _StarRatingBar(
                          rating: _ratingValue,
                          onSelected: (value) {
                            setState(() => _ratingValue = value);
                          },
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Male')),
              ButtonSegment(value: 'female', label: Text('Female')),
            ],
            selected: {_silhouette},
            onSelectionChanged: (s) => setState(() => _silhouette = s.first),
          ),
        ],
      ),
    );
  }

  // ── Utility helpers ──────────────────────────────────────────────────────

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
          onSelect: (index) => setState(() => _topIndex = index),
        );
        break;
      case 'bottomwear':
        await _showSingleSlotPicker(
          title: 'Select Bottomwear',
          items: _bottoms,
          selectedIndex: _bottomIndex,
          onSelect: (index) => setState(() => _bottomIndex = index),
        );
        break;
      case 'shoes':
        await _showSingleSlotPicker(
          title: 'Select Shoes',
          items: _shoes,
          selectedIndex: _shoesIndex,
          onSelect: (index) => setState(() => _shoesIndex = index),
        );
        break;
      case 'outerwear':
        await _showSingleSlotPicker(
          title: 'Select Outerwear',
          items: _outerwear,
          selectedIndex: _outerwearIndex,
          optionalNone: true,
          onSelect: (index) => setState(() => _outerwearIndex = index),
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
      backgroundColor: _kBg,
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
                      style: TextStyle(color: _kMuted),
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
                                color: isSelected ? _kTagBg : _kWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? _kInk : _kBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.block, size: 20, color: _kMuted),
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
      backgroundColor: _kBg,
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
                          style: TextStyle(color: _kMuted),
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
                          setState(() {
                            _accessoryIndices
                              ..clear()
                              ..addAll(working);
                          });
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(backgroundColor: _kInk),
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
  final OutfitService _outfitService = OutfitService();

  Map<String, dynamic>? _outfit;
  bool _loading = true;
  bool _updatingFav = false;
  bool _savingRating = false;
  bool _markingWorn = false;

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
      _loading = false;
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
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(existingOutfit: outfit),
      ),
    );
    if (changed == true) {
      _loadDetail();
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete outfit')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfit = _outfit;
    final name = (outfit?['name'] ?? 'Outfit').toString();
    final occasion = (outfit?['occasion'] ?? 'Any Occasion').toString();
    final ratingValue = _asInt(outfit?['rating']) ?? 0;
    final wearCount = _asInt(outfit?['wear_count']) ?? 0;
    final alreadyWornToday = _isWornToday(outfit);
    final isFav = outfit?['is_favourite'] == true;
    final createdAt = _formatDate(outfit?['created_at']?.toString());
    final previewItems = outfit == null
        ? const <EditableCanvasItem>[]
        : _previewItems(outfit);
    final previewTransforms = outfit == null
        ? const <String, EditableCanvasTransform>{}
        : _layoutToTransforms(_previewLayout(outfit));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kWhite,
          foregroundColor: _kInk,
          title: const Text('Outfit Detail'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : outfit == null
            ? const Center(child: Text('Outfit not found'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _PreviewCard(
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
                        ),
                  occasion: occasion,
                  wearCount: wearCount,
                  isFav: isFav,
                ),
                const SizedBox(height: 16),
                _DetailsCard(
                  name: name,
                  occasion: occasion,
                  wearCount: wearCount,
                  createdAt: createdAt,
                  rating: ratingValue,
                  savingRating: _savingRating,
                  onRatingSelected: _setRating,
                  isFav: isFav,
                ),
                const SizedBox(height: 16),
                _ActionsCard(
                  markingWorn: _markingWorn,
                  alreadyWornToday: alreadyWornToday,
                  onMarkWorn: _markWorn,
                  updatingFav: _updatingFav,
                  isFav: isFav,
                  onToggleFavourite: _toggleFavourite,
                  onEdit: _editOutfit,
                  onDelete: _deleteOutfit,
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

  String _imageOf(Map<String, dynamic> item) {
    final raw = (item['image'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiClient.host}$raw';
    return '${ApiClient.host}/$raw';
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

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SoftPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? bgColor;

  const _SoftPill({
    required this.icon,
    required this.label,
    this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim().isEmpty ? '-' : label;
    final iconColor = color ?? _kInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor ?? _kTagBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Widget child;
  final String occasion;
  final int wearCount;
  final bool isFav;

  const _PreviewCard({
    required this.child,
    required this.occasion,
    required this.wearCount,
    required this.isFav,
  });

  @override
  Widget build(BuildContext context) {
    final occasionLabel =
        occasion.trim().isEmpty ? 'Any occasion' : occasion;
    final wearLabel = wearCount == 0 ? 'Not worn yet' : '$wearCount wears';

    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              if (isFav)
                const _SoftPill(
                  icon: Icons.favorite,
                  label: 'Favourite',
                  color: Color(0xFFDC2626),
                  bgColor: Color(0xFFFDECEC),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SoftPill(icon: Icons.event_outlined, label: occasionLabel),
              _SoftPill(icon: Icons.repeat, label: wearLabel),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: _kTagBg,
              padding: const EdgeInsets.all(10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final String name;
  final String occasion;
  final int wearCount;
  final String createdAt;
  final int rating;
  final bool savingRating;
  final ValueChanged<int> onRatingSelected;
  final bool isFav;

  const _DetailsCard({
    required this.name,
    required this.occasion,
    required this.wearCount,
    required this.createdAt,
    required this.rating,
    required this.savingRating,
    required this.onRatingSelected,
    required this.isFav,
  });

  @override
  Widget build(BuildContext context) {
    final wearLabel = wearCount == 0 ? 'Not yet' : '$wearCount times';
    final occasionLabel =
        occasion.trim().isEmpty ? 'Any occasion' : occasion;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isFav)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SoftPill(icon: Icons.event_outlined, label: occasionLabel),
              _SoftPill(icon: Icons.repeat, label: wearLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: createdAt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.checkroom_outlined,
                  label: 'Worn',
                  value: wearLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Rating',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _StarRatingBar(
                rating: rating,
                onSelected: onRatingSelected,
                size: 20,
              ),
              if (savingRating) ...[
                const SizedBox(width: 8),
                const Text(
                  'Saving...',
                  style: TextStyle(fontSize: 12, color: _kMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kTagBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Icon(icon, size: 16, color: _kMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final bool markingWorn;
  final bool alreadyWornToday;
  final VoidCallback onMarkWorn;
  final bool updatingFav;
  final bool isFav;
  final VoidCallback onToggleFavourite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionsCard({
    required this.markingWorn,
    required this.alreadyWornToday,
    required this.onMarkWorn,
    required this.updatingFav,
    required this.isFav,
    required this.onToggleFavourite,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (markingWorn || alreadyWornToday) ? null : onMarkWorn,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                markingWorn
                    ? 'Updating...'
                    : (alreadyWornToday ? 'Worn today' : 'Mark as worn'),
              ),
              style: FilledButton.styleFrom(backgroundColor: _kInk),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: updatingFav ? null : onToggleFavourite,
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? const Color(0xFFDC2626) : null,
                  ),
                  label: Text(isFav ? 'Unfavourite' : 'Favourite'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete outfit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
              ),
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
  final double size;

  const _StarRatingBar({
    required this.rating,
    required this.onSelected,
    this.size = 22,
  });

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
            color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
          ),
          iconSize: size,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: '$value stars',
        );
      }),
    );
  }
}
