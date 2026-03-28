import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:frontend/services/accessory_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/services/clothing_query_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/features/wardrobe/screens/accessory_detail_screen.dart';
import 'package:frontend/features/wardrobe/screens/clothing_detail_screen.dart';

class WardrobeScreen extends StatefulWidget {
  final bool embedded;
  final ValueChanged<bool>? onSelectionChanged;

  const WardrobeScreen({
    super.key,
    this.embedded = false,
    this.onSelectionChanged,
  });

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final ClothingService _clothingService =
      ServiceRegistry.instance.clothingService;
  final AccessoryService _accessoryService =
      ServiceRegistry.instance.accessoryService;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _loading = true;
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  String _search = '';
  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  String _selectedTag = 'All';
  String _selectedColor = 'All';
  String _selectedOccasion = 'All';
  bool _favoritesOnly = false;
  String _sortBy = 'Date added (newest)';

  static const List<_WardrobeDomainMeta> _domainOrder = [
    _WardrobeDomainMeta(
      key: 'topwear',
      label: 'Topwear',
      icon: Icons.checkroom_outlined,
      emptyHint: 'No topwear items yet.',
    ),
    _WardrobeDomainMeta(
      key: 'bottomwear',
      label: 'Bottomwear',
      icon: Icons.accessibility_outlined,
      emptyHint: 'No bottomwear items yet.',
    ),
    _WardrobeDomainMeta(
      key: 'shoes',
      label: 'Shoes',
      icon: Icons.hiking_outlined,
      emptyHint: 'No shoes yet.',
    ),
    _WardrobeDomainMeta(
      key: 'accessories',
      label: 'Accessories',
      icon: Icons.watch_outlined,
      emptyHint: 'No accessories yet.',
    ),
    _WardrobeDomainMeta(
      key: 'outerwear',
      label: 'Outerwear',
      icon: Icons.layers_outlined,
      emptyHint: 'No outerwear items yet.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWardrobe() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _clothingService.getAllClothes(),
      _accessoryService.getAll(),
    ]);
    final clothes = List<Map<String, dynamic>>.from(results[0]);
    final accessories = List<Map<String, dynamic>>.from(
      results[1],
    ).map(_normalizeAccessoryItem).toList();
    if (!mounted) return;
    setState(() {
      _allItems = [...clothes, ...accessories];
      _loading = false;
    });
    _applyFilters();
  }

  Map<String, dynamic> _normalizeAccessoryItem(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString().trim();
    return {
      ...item,
      'category': 'Accessory',
      'subcategory': name.isEmpty ? 'Accessory' : name,
      'occasion': '',
      'attributes': const <String>[],
      '_item_kind': 'accessory',
    };
  }

  Future<void> _toggleFavourite(Map<String, dynamic> item) async {
    final itemId = _itemId(item);
    final isAccessory = _itemKind(item) == 'accessory';
    if (itemId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update favourite for this item'),
          ),
        );
      }
      return;
    }

    final oldValue = item['is_favourite'] == true;
    setState(() => item['is_favourite'] = !oldValue);

    final ok = isAccessory
        ? await _accessoryService.toggleFavourite(itemId)
        : await _clothingService.toggleFavourite(itemId);
    if (!mounted) return;

    if (!ok) {
      setState(() => item['is_favourite'] = oldValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update favourite'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    _applyFilters();
  }

  void _applyFilters() {
    final list = ClothingQueryService.filterAndSort(
      items: _allItems,
      query: _search.trim().toLowerCase(),
      selectedCategory: _selectedCategory,
      selectedSubcategory: _selectedSubcategory,
      selectedOccasion: _selectedOccasion,
      selectedColor: _selectedColor,
      selectedTag: _selectedTag,
      favoritesOnly: _favoritesOnly,
      sortBy: _sortBy,
    );
    setState(() => _filteredItems = list);
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
    widget.onSelectionChanged?.call(_selectMode);
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
        title: const Text('Delete selected items?'),
        content: Text('This will delete ${_selectedIds.length} item(s).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: WardrobeTokens.dangerStrong,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final selectedItems = _allItems.where((item) {
      final key = _selectionId(item);
      return key != null && _selectedIds.contains(key);
    }).toList();

    await Future.wait(
      selectedItems.map((item) async {
        final rawId = _itemId(item);
        if (rawId == null) return;
        if (_itemKind(item) == 'accessory') {
          await _accessoryService.delete(rawId);
        } else {
          await _clothingService.deleteClothing(rawId);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    widget.onSelectionChanged?.call(false);
    _loadWardrobe();
  }

  String _resolveImage(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }

  int? _itemId(Map<String, dynamic> item) {
    final raw = item['id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _itemKind(Map<String, dynamic> item) {
    return (item['_item_kind'] ?? 'clothing').toString();
  }

  int? _selectionId(Map<String, dynamic> item) {
    final id = _itemId(item);
    if (id == null) return null;
    return _itemKind(item) == 'accessory' ? -id : id;
  }

  List<String> _optionsFor(String field) {
    return ClothingQueryService.optionsForField(_allItems, field);
  }

  List<String> _tagOptions() {
    return ClothingQueryService.tagOptions(_allItems);
  }

  int _activeFilterCount() {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_selectedSubcategory != 'All') count++;
    if (_selectedTag != 'All') count++;
    if (_selectedColor != 'All') count++;
    if (_selectedOccasion != 'All') count++;
    if (_favoritesOnly) count++;
    if (_sortBy != 'Date added (newest)') count++;
    return count;
  }

  Future<void> _openFilterSheet() async {
    String category = _selectedCategory;
    String subcategory = _selectedSubcategory;
    String occasion = _selectedOccasion;
    String color = _selectedColor;
    String tag = _selectedTag;
    bool favoritesOnly = _favoritesOnly;
    String sortBy = _sortBy;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WardrobeTokens.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget filterChip(
              String label,
              String value,
              List<String> options,
              ValueChanged<String?> onChanged,
            ) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WardrobeTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((option) {
                        final isSelected = value == option;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => onChanged(option));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? WardrobeTokens.inkStrong
                                  : WardrobeTokens.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? WardrobeTokens.inkStrong
                                    : WardrobeTokens.line,
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? WardrobeTokens.surface
                                    : WardrobeTokens.inkStrong,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: WardrobeTokens.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Filters & Sort',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: WardrobeTokens.surfaceSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.55,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              filterChip(
                                'Category',
                                category,
                                _optionsFor('category'),
                                (v) => category = v ?? 'All',
                              ),
                              filterChip(
                                'Subcategory',
                                subcategory,
                                _optionsFor('subcategory'),
                                (v) => subcategory = v ?? 'All',
                              ),
                              filterChip(
                                'Occasion',
                                occasion,
                                _optionsFor('occasion'),
                                (v) => occasion = v ?? 'All',
                              ),
                              filterChip(
                                'Color',
                                color,
                                _optionsFor('dominant_color'),
                                (v) => color = v ?? 'All',
                              ),
                              filterChip(
                                'Tag',
                                tag,
                                _tagOptions(),
                                (v) => tag = v ?? 'All',
                              ),

                              const SizedBox(height: 8),
                              const Text(
                                'Sort By',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WardrobeTokens.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    [
                                      'Date added (newest)',
                                      'Date added (oldest)',
                                      'Category (A-Z)',
                                      'Favorites first',
                                    ].map((option) {
                                      final isSelected = sortBy == option;
                                      return GestureDetector(
                                        onTap: () => setModalState(
                                          () => sortBy = option,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? WardrobeTokens.inkStrong
                                                : WardrobeTokens.surface,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? WardrobeTokens.inkStrong
                                                  : WardrobeTokens.line,
                                            ),
                                          ),
                                          child: Text(
                                            option,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? WardrobeTokens.surface
                                                  : WardrobeTokens.inkStrong,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: WardrobeTokens.dangerBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: WardrobeTokens.dangerPale,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: WardrobeTokens.danger,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Show favorites only',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: favoritesOnly,
                                      onChanged: (v) => setModalState(
                                        () => favoritesOnly = v,
                                      ),
                                      activeThumbColor: WardrobeTokens.danger,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  category = 'All';
                                  subcategory = 'All';
                                  occasion = 'All';
                                  color = 'All';
                                  tag = 'All';
                                  favoritesOnly = false;
                                  sortBy = 'Date added (newest)';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Reset All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = category;
                                  _selectedSubcategory = subcategory;
                                  _selectedOccasion = occasion;
                                  _selectedColor = color;
                                  _selectedTag = tag;
                                  _favoritesOnly = favoritesOnly;
                                  _sortBy = sortBy;
                                });
                                _applyFilters();
                                Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: WardrobeTokens.inkStrong,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Apply Filters'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _topCategory() {
    if (_allItems.isEmpty) return '-';
    final counts = <String, int>{};
    for (final item in _allItems) {
      final c = (item['category'] ?? '').toString().trim();
      if (c.isEmpty) continue;
      counts[c] = (counts[c] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.key;
  }

  Map<String, int> _dominantColorCounts() {
    return ClothingQueryService.dominantColorCounts(_allItems);
  }

  Map<String, int> _categoryCounts() {
    final counts = <String, int>{};
    for (final item in _allItems) {
      final key = (item['category'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Color _getActualColor(String colorName) {
    final found = matchNamedColor(NamedColors.wardrobe, colorName);
    return found ?? WardrobeTokens.muted;
  }

  String _domainForItem(Map<String, dynamic> item) {
    final blob = '${item['category'] ?? ''} ${item['subcategory'] ?? ''}'
        .toString()
        .toLowerCase();

    bool containsAny(List<String> keys) => keys.any(blob.contains);

    if (containsAny(['outerwear', 'outer', 'jacket', 'coat', 'blazer'])) {
      return 'outerwear';
    }
    if (containsAny([
      'topwear',
      'top',
      'shirt',
      't-shirt',
      'tee',
      'blouse',
      'sweater',
      'hoodie',
      'polo',
      'crop',
    ])) {
      return 'topwear';
    }
    if (containsAny([
      'bottomwear',
      'bottom',
      'pant',
      'jean',
      'trouser',
      'short',
      'skirt',
      'legging',
    ])) {
      return 'bottomwear';
    }
    if (containsAny([
      'shoe',
      'shoes',
      'sneaker',
      'boot',
      'sandal',
      'footwear',
      'heel',
      'loafer',
      'slipper',
    ])) {
      return 'shoes';
    }
    if (containsAny([
      'accessory',
      'accessories',
      'watch',
      'belt',
      'bag',
      'hat',
      'jewel',
      'scarf',
      'cap',
      'sunglass',
      'glass',
    ])) {
      return 'accessories';
    }
    return 'accessories';
  }

  Map<String, List<Map<String, dynamic>>> _groupedByDomain() {
    final grouped = <String, List<Map<String, dynamic>>>{
      for (final domain in _domainOrder) domain.key: <Map<String, dynamic>>[],
    };
    for (final item in _filteredItems) {
      final key = _domainForItem(item);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return grouped;
  }

  Widget _statsOverview() {
    final favoriteCount = _allItems
        .where((e) => e['is_favourite'] == true)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WardrobeTokens.analyticsStart, WardrobeTokens.analyticsEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WardrobeTokens.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(
            Icons.checkroom_rounded,
            '${_allItems.length}',
            'Total Items',
            WardrobeTokens.onAnalytics,
          ),
          Container(
            width: 1,
            height: 40,
            color: WardrobeTokens.onAnalytics.withValues(alpha: 0.24),
          ),
          _statItem(
            Icons.favorite_rounded,
            '$favoriteCount',
            'Favorites',
            WardrobeTokens.redSoft,
          ),
          Container(
            width: 1,
            height: 40,
            color: WardrobeTokens.onAnalytics.withValues(alpha: 0.24),
          ),
          _statItem(
            Icons.category_rounded,
            _topCategory(),
            'Top Category',
            WardrobeTokens.blueSoft,
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: WardrobeTokens.onAnalytics,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: WardrobeTokens.onAnalytics.withValues(alpha: 0.7),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _colorPalette() {
    final counts = _dominantColorCounts();
    final total = counts.values.fold<int>(0, (sum, c) => sum + c);
    if (total == 0) return const SizedBox.shrink();

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.take(6).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WardrobeTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WardrobeTokens.line),
        boxShadow: [
          BoxShadow(
            color: WardrobeTokens.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WardrobeTokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Color Distribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...top.map((entry) {
            final percent = (entry.value * 100 / total);
            final actualColor = _getActualColor(entry.key);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: actualColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: actualColor == WardrobeTokens.surface
                                ? WardrobeTokens.line
                                : WardrobeTokens.transparent,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WardrobeTokens.black.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: WardrobeTokens.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 8,
                      backgroundColor: WardrobeTokens.surfaceSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(actualColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryPieChart() {
    final counts = _categoryCounts();
    if (counts.isEmpty) return const SizedBox.shrink();

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    final total = top.fold<int>(0, (sum, e) => sum + e.value);

    final colors = <Color>[
      WardrobeTokens.analyticsStart,
      WardrobeTokens.blue,
      WardrobeTokens.success,
      WardrobeTokens.warning,
      WardrobeTokens.danger,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WardrobeTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WardrobeTokens.line),
        boxShadow: [
          BoxShadow(
            color: WardrobeTokens.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Analytics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Top categories in your wardrobe',
            style: TextStyle(fontSize: 12, color: WardrobeTokens.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 44,
                sectionsSpace: 2,
                sections: [
                  for (int i = 0; i < top.length; i++)
                    PieChartSectionData(
                      value: top[i].value.toDouble(),
                      color: colors[i % colors.length],
                      title: '${((top[i].value * 100) / total).round()}%',
                      titleStyle: const TextStyle(
                        color: WardrobeTokens.onAnalytics,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      radius: 66,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (int i = 0; i < top.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors[i % colors.length].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${top[i].key}: ${top[i].value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _domainGridView() {
    if (_filteredItems.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.checkroom_outlined,
                size: 64,
                color: WardrobeTokens.lineLight,
              ),
              const SizedBox(height: 16),
              Text(
                'No items found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: WardrobeTokens.grayMid,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(fontSize: 14, color: WardrobeTokens.gray),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupedByDomain();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            for (final domain in _domainOrder)
              _buildDomainSection(domain, grouped[domain.key] ?? const []),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainSection(
    _WardrobeDomainMeta domain,
    List<Map<String, dynamic>> items,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(domain.icon, color: WardrobeTokens.inkStrong, size: 18),
              const SizedBox(width: 8),
              Text(
                domain.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WardrobeTokens.inkStrong,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: WardrobeTokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: WardrobeTokens.line),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WardrobeTokens.inkStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WardrobeTokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WardrobeTokens.line),
              ),
              child: Text(
                domain.emptyHint,
                style: const TextStyle(
                  fontSize: 13,
                  color: WardrobeTokens.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) =>
                  _buildWardrobeItemCard(items[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildWardrobeItemCard(Map<String, dynamic> item) {
    final image = _resolveImage(item['image']);
    final selectionId = _selectionId(item);
    final selected = selectionId != null && _selectedIds.contains(selectionId);
    final isAccessory = _itemKind(item) == 'accessory';

    return GestureDetector(
      onTap: () async {
        if (_selectMode) {
          _toggleSelected(selectionId);
          return;
        }
        if (isAccessory) {
          final accessoryId = _itemId(item);
          if (accessoryId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to open this accessory')),
            );
            return;
          }
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AccessoryDetailScreen(
                accessoryId: accessoryId,
                initialData: item,
              ),
            ),
          );
          if (changed == true) {
            _loadWardrobe();
          }
          return;
        }
        final itemId = _itemId(item);
        if (itemId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open this item')),
          );
          return;
        }
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClothingDetailScreen(clothingId: itemId),
          ),
        );
        if (changed == true) {
          _loadWardrobe();
        }
      },
      onLongPress: () {
        if (!_selectMode) {
          _toggleSelectMode();
        }
        _toggleSelected(selectionId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: WardrobeTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? WardrobeTokens.inkStrong
                : WardrobeTokens.transparent,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: WardrobeTokens.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: image.isEmpty
                        ? Container(
                            color: WardrobeTokens.surfaceSoft,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 48,
                                color: WardrobeTokens.lineQuiet,
                              ),
                            ),
                          )
                        : Container(
                            color: WardrobeTokens.surfaceAlt,
                            padding: const EdgeInsets.all(10),
                            child: Image.network(
                              image,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: WardrobeTokens.surfaceSoft,
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: WardrobeTokens.lineQuiet,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleFavourite(item),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: WardrobeTokens.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: WardrobeTokens.black.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          item['is_favourite'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: item['is_favourite'] == true
                              ? WardrobeTokens.dangerStrong
                              : WardrobeTokens.muted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (_selectMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selected
                              ? WardrobeTokens.inkStrong
                              : WardrobeTokens.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: WardrobeTokens.black.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: selected
                                ? WardrobeTokens.inkStrong
                                : WardrobeTokens.line,
                          ),
                        ),
                        child: Icon(
                          selected ? Icons.check : Icons.radio_button_unchecked,
                          size: 16,
                          color: selected
                              ? WardrobeTokens.surface
                              : WardrobeTokens.mutedSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['subcategory'] ?? item['category'] ?? 'Item')
                        .toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item['dominant_color'] != null) ...[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getActualColor(
                              item['dominant_color'].toString(),
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: WardrobeTokens.line),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          (item['category'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WardrobeTokens.muted,
                          ),
                        ),
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

  Widget _searchBar() {
    final activeCount = _activeFilterCount();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: WardrobeTokens.surface,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: WardrobeTokens.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WardrobeTokens.line),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _search = v;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Search wardrobe...',
                  hintStyle: const TextStyle(color: WardrobeTokens.mutedSoft),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: WardrobeTokens.muted,
                  ),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _search = '';
                            _applyFilters();
                          },
                          icon: const Icon(
                            Icons.clear,
                            color: WardrobeTokens.muted,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? WardrobeTokens.inkStrong
                    : WardrobeTokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activeCount > 0
                      ? WardrobeTokens.inkStrong
                      : WardrobeTokens.line,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune,
                    color: activeCount > 0
                        ? WardrobeTokens.surface
                        : WardrobeTokens.inkStrong,
                  ),
                  if (activeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: WardrobeTokens.dangerSoft,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$activeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: WardrobeTokens.surface,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleSelectMode,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectMode
                    ? WardrobeTokens.inkStrong
                    : WardrobeTokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectMode
                      ? WardrobeTokens.inkStrong
                      : WardrobeTokens.line,
                ),
              ),
              child: Icon(
                _selectMode ? Icons.close : Icons.checklist_rtl,
                color: _selectMode
                    ? WardrobeTokens.surface
                    : WardrobeTokens.inkStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadWardrobe,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _statsOverview()),
          SliverToBoxAdapter(child: _categoryPieChart()),
          SliverToBoxAdapter(child: _colorPalette()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _searchBar()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '${_filteredItems.length} ${_filteredItems.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: WardrobeTokens.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _domainGridView(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomClearance =
        (widget.embedded ? kBottomNavigationBarHeight : 0) + bottomInset + 12;

    final page = Stack(
      children: [
        _content(),
        if (_selectMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomClearance),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: WardrobeTokens.inkStrong,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: WardrobeTokens.black.withValues(alpha: 0.2),
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
                        color: WardrobeTokens.surface,
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
                        backgroundColor: WardrobeTokens.dangerStrong,
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

    if (widget.embedded) {
      return page;
    }
    return Scaffold(
      backgroundColor: WardrobeTokens.surfaceAlt,
      appBar: AppBar(
        title: const Text(
          'My Wardrobe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: WardrobeTokens.surface,
        elevation: 0,
        surfaceTintColor: WardrobeTokens.surface,
        actions: [
          IconButton(
            onPressed: _toggleSelectMode,
            icon: Icon(_selectMode ? Icons.close : Icons.checklist_rtl),
            tooltip: _selectMode ? 'Exit selection' : 'Select items',
          ),
        ],
      ),
      body: page,
    );
  }
}

class _WardrobeDomainMeta {
  final String key;
  final String label;
  final IconData icon;
  final String emptyHint;

  const _WardrobeDomainMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.emptyHint,
  });
}
