import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/api_client.dart';
import '../services/clothing_service.dart';
import '../services/clothing_query_service.dart';
import 'clothing_detail_screen.dart';

class WardrobeScreen extends StatefulWidget {
  final bool embedded;

  const WardrobeScreen({super.key, this.embedded = false});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final ClothingService _clothingService = ClothingService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _loading = true;

  String _search = '';
  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  String _selectedTag = 'All';
  String _selectedColor = 'All';
  String _selectedOccasion = 'All';
  bool _favoritesOnly = false;
  String _sortBy = 'Date added (newest)';

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
    final items = await _clothingService.getAllClothes();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _loading = false;
    });
    _applyFilters();
  }

  Future<void> _toggleFavourite(Map<String, dynamic> item) async {
    final itemId = _itemId(item);
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

    final ok = await _clothingService.toggleFavourite(itemId);
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
      backgroundColor: Colors.transparent,
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
                        color: Color(0xFF6B7280),
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
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF111827)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF111827),
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
                color: Colors.white,
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
                              backgroundColor: const Color(0xFFF3F4F6),
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
                                  color: Color(0xFF6B7280),
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
                                                ? const Color(0xFF111827)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF111827)
                                                  : const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: Text(
                                            option,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF111827),
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
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: Color(0xFFDC2626),
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
                                      activeThumbColor: const Color(0xFFDC2626),
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
                                backgroundColor: const Color(0xFF111827),
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
    final name = colorName.toLowerCase().trim();

    // Common color mappings
    final colorMap = {
      // Basic colors
      'black': const Color(0xFF000000),
      'white': const Color(0xFFFFFFFF),
      'gray': const Color(0xFF9CA3AF),
      'grey': const Color(0xFF9CA3AF),

      // Reds
      'red': const Color(0xFFEF4444),
      'maroon': const Color(0xFF7F1D1D),
      'burgundy': const Color(0xFF7C2D12),
      'crimson': const Color(0xFFDC143C),
      'pink': const Color(0xFFEC4899),
      'rose': const Color(0xFFF43F5E),

      // Blues
      'blue': const Color(0xFF3B82F6),
      'navy': const Color(0xFF1E3A8A),
      'royal blue': const Color(0xFF2563EB),
      'sky blue': const Color(0xFF0EA5E9),
      'light blue': const Color(0xFF7DD3FC),
      'turquoise': const Color(0xFF06B6D4),
      'teal': const Color(0xFF14B8A6),
      'cyan': const Color(0xFF06B6D4),

      // Greens
      'green': const Color(0xFF22C55E),
      'forest green': const Color(0xFF15803D),
      'lime': const Color(0xFF84CC16),
      'olive': const Color(0xFF65A30D),
      'mint': const Color(0xFF6EE7B7),

      // Yellows/Oranges
      'yellow': const Color(0xFFEAB308),
      'gold': const Color(0xFFD97706),
      'orange': const Color(0xFFF97316),
      'coral': const Color(0xFFFB923C),
      'peach': const Color(0xFFFDBA74),

      // Purples
      'purple': const Color(0xFFA855F7),
      'violet': const Color(0xFF8B5CF6),
      'lavender': const Color(0xFFC084FC),
      'indigo': const Color(0xFF6366F1),

      // Browns
      'brown': const Color(0xFF92400E),
      'tan': const Color(0xFFD2691E),
      'beige': const Color(0xFFD4B896),
      'cream': const Color(0xFFFFFDD0),
      'khaki': const Color(0xFFC3B091),

      // Others
      'silver': const Color(0xFFC0C0C0),
      'bronze': const Color(0xFFCD7F32),
    };

    // Try exact match first
    final direct = colorMap[name];
    if (direct != null) return direct;

    // Try partial match
    for (var entry in colorMap.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        return entry.value;
      }
    }

    // Default fallback
    return const Color(0xFF6B7280);
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
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
            Colors.white,
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _statItem(
            Icons.favorite_rounded,
            '$favoriteCount',
            'Favorites',
            Colors.red.shade300,
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          _statItem(
            Icons.category_rounded,
            _topCategory(),
            'Top Category',
            Colors.blue.shade300,
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
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  color: const Color(0xFFF3F4F6),
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
                            color: actualColor == const Color(0xFFFFFFFF)
                                ? const Color(0xFFE5E7EB)
                                : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
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
                          color: Color(0xFF6B7280),
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
                      backgroundColor: const Color(0xFFF3F4F6),
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
      const Color(0xFF111827),
      const Color(0xFF2563EB),
      const Color(0xFF16A34A),
      const Color(0xFFF59E0B),
      const Color(0xFFDC2626),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
                        color: Colors.white,
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

  Widget _gridView() {
    if (_filteredItems.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.checkroom_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No items found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final item = _filteredItems[i];
          final image = _resolveImage(item['image']);

          return GestureDetector(
            onTap: () async {
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
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
                                  color: const Color(0xFFF3F4F6),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 48,
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFF9FAFB),
                                  padding: const EdgeInsets.all(10),
                                  child: Image.network(
                                    image,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      color: const Color(0xFFF3F4F6),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: Color(0xFFD1D5DB),
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
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
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
                                    ? Colors.red
                                    : const Color(0xFF6B7280),
                                size: 18,
                              ),
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
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
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
                                  color: Color(0xFF6B7280),
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
        }, childCount: _filteredItems.length),
      ),
    );
  }

  Widget _searchBar() {
    final activeCount = _activeFilterCount();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _search = v;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Search wardrobe...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF6B7280),
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
                            color: Color(0xFF6B7280),
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
                color: activeCount > 0 ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activeCount > 0
                      ? const Color(0xFF111827)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune,
                    color: activeCount > 0
                        ? Colors.white
                        : const Color(0xFF111827),
                  ),
                  if (activeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
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
                            color: Colors.white,
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
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _gridView(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _content();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'My Wardrobe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: _content(),
    );
  }
}

