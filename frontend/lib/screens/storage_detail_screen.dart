import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../services/clothing_service.dart';
import '../services/misc_service.dart';
import '../services/clothing_query_service.dart';
import '../services/api_client.dart';
import 'clothing_detail_screen.dart';
import 'upload_clothing_screen.dart';

class StorageDetailScreen extends StatefulWidget {
  final int storageId;

  const StorageDetailScreen({super.key, required this.storageId});

  @override
  State<StorageDetailScreen> createState() => _StorageDetailScreenState();
}

class _StorageDetailScreenState extends State<StorageDetailScreen> {
  final StorageService storageService = StorageService();
  final ClothingService clothingService = ClothingService();
  final MiscService miscService = MiscService();

  Map<String, dynamic>? data;
  bool loading = true;
  bool hasChanges = false;
  bool _movingItem = false;
  String _searchQuery = '';
  String _storageFilterColor = 'All';
  String _storageFilterSubcategory = 'All';
  String _storageFilterOccasion = 'All';
  String _storageFilterTag = 'All';
  bool _storageFavoritesOnly = false;
  String _storageSortBy = 'Category (A-Z)';
  bool _selectionMode = false;
  final Set<int> _selectedClothingIds = <int>{};
  List<Map<String, dynamic>> _breadcrumbChain = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await storageService.getDetail(widget.storageId);
      final allStorages = await storageService.getAll();
      final chain = _buildBreadcrumbChain(
        res['storage'] as Map<String, dynamic>,
        allStorages,
      );

      if (!mounted) return;
      setState(() {
        data = res;
        _breadcrumbChain = chain;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load storage details')),
      );
    }
  }

  String _img(dynamic url) {
    if (url == null) return '';
    if (url.toString().startsWith('http')) return url;
    return '${ApiClient.host}$url';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _buildBreadcrumbChain(
    Map<String, dynamic> currentStorage,
    List<Map<String, dynamic>> allStorages,
  ) {
    final byId = <int, Map<String, dynamic>>{};
    for (final s in allStorages) {
      final id = _asInt(s['id']);
      if (id > 0) byId[id] = s;
    }

    final chain = <Map<String, dynamic>>[];
    final visited = <int>{};

    Map<String, dynamic>? cursor = currentStorage;
    while (cursor != null) {
      final id = _asInt(cursor['id']);
      if (id <= 0 || visited.contains(id)) break;
      visited.add(id);
      chain.add(cursor);

      final parent = cursor['parent_storage'] as Map<String, dynamic>?;
      if (parent == null) break;

      final parentId = _asInt(parent['id']);
      if (parentId <= 0) break;
      cursor = byId[parentId] ?? parent;
    }

    return chain.reversed.toList();
  }

  IconData _storageTypeIcon(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'closet':
        return Icons.door_front_door_outlined;
      case 'wardrobe':
        return Icons.checkroom_outlined;
      case 'cupboard':
        return Icons.kitchen_outlined;
      case 'drawer':
        return Icons.dashboard_outlined;
      case 'box':
        return Icons.inventory_2_outlined;
      case 'shelf':
        return Icons.shelves;
      default:
        return Icons.storage_outlined;
    }
  }

  String _mostCommonColor(List clothes) {
    final counts = <String, int>{};

    for (final c in clothes) {
      final raw = (c['dominant_color'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final color = raw.toLowerCase();
      counts[color] = (counts[color] ?? 0) + 1;
    }

    if (counts.isEmpty) return '-';

    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return '${top.key[0].toUpperCase()}${top.key.substring(1)} (${top.value})';
  }

  Map<String, int> _categoryDistribution(List clothes) {
    final result = <String, int>{};

    for (final c in clothes) {
      final raw = (c['category'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final key = raw.toLowerCase();
      result[key] = (result[key] ?? 0) + 1;
    }

    return result;
  }

  Map<String, int> _itemDistribution(List clothes, List nonClothes) {
    final result = <String, int>{};

    final nonClothingCount = nonClothes.length;
    if (nonClothingCount > 0) {
      result['Non-clothing'] = nonClothingCount;
    }

    for (final c in clothes) {
      final raw = (c['subcategory'] ?? c['category'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final label = _toTitleCase(raw);
      result[label] = (result[label] ?? 0) + 1;
    }

    return result;
  }

  String _toTitleCase(String input) {
    final clean = input.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (clean.isEmpty) return clean;
    return clean
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Widget _buildDistributionChart(Map<String, int> distribution) {
    final entries = distribution.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text('No items yet for analytics'),
      );
    }

    final colors = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFF64748B),
    ];

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final percent = ((e.value / total) * 100).round();
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: e.value.toDouble(),
          radius: 74,
          title: '$percent%',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Distribution',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 34,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < entries.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors[i % colors.length].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${entries[i].key}: ${entries[i].value}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _togglePutAway(bool value) async {
    final storage = data!['storage'] as Map<String, dynamic>;
    final bool oldValue = (storage['is_put_away'] ?? false) == true;

    setState(() => storage['is_put_away'] = value);

    try {
      await storageService.togglePutAway(storage['id'], value);
      hasChanges = true;
    } catch (_) {
      if (!mounted) return;
      setState(() => storage['is_put_away'] = oldValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update put away status')),
      );
    }
  }

  Future<void> _openStorage(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StorageDetailScreen(storageId: id)),
    );

    if (result == true && mounted) {
      hasChanges = true;
      _load();
    }
  }

  Future<void> _openClothingDetail(int clothingId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClothingDetailScreen(clothingId: clothingId),
      ),
    );

    if (result == true && mounted) {
      hasChanges = true;
      _load();
    }
  }

  Future<void> _moveClothing(Map<String, dynamic> item) async {
    final all = await storageService.getAll();
    if (!mounted) return;

    final storages = List<Map<String, dynamic>>.from(all)
      ..sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ),
      );

    if (storages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No storage spaces available')),
      );
      return;
    }

    final target = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Move to Storage',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Choose destination storage'),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: storages.length,
                itemBuilder: (context, i) {
                  final s = storages[i];
                  final id = _asInt(s['id']);
                  final currentId = _asInt(item['storage_unit']?['id']);
                  final isCurrent = id == currentId;

                  return ListTile(
                    enabled: !isCurrent,
                    leading: Icon(_storageTypeIcon(s['type']?.toString())),
                    title: Text((s['name'] ?? 'Storage').toString()),
                    subtitle: Text((s['type'] ?? 'other').toString()),
                    trailing: isCurrent
                        ? const Text('Current')
                        : const Icon(Icons.chevron_right),
                    onTap: isCurrent ? null : () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (target == null) return;

    setState(() => _movingItem = true);
    final ok = await clothingService.moveToStorage(
      _asInt(item['id']),
      _asInt(target['id']),
    );

    if (!mounted) return;
    setState(() => _movingItem = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to move clothing item')),
      );
      return;
    }

    hasChanges = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved to ${(target['name'] ?? 'storage')}')),
    );
    _load();
  }

  void _toggleSelectionMode(bool enabled) {
    setState(() {
      _selectionMode = enabled;
      if (!enabled) _selectedClothingIds.clear();
    });
  }

  void _toggleClothingSelection(int id) {
    setState(() {
      if (_selectedClothingIds.contains(id)) {
        _selectedClothingIds.remove(id);
      } else {
        _selectedClothingIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedClothing() async {
    if (_selectedClothingIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Selected Items?'),
        content: Text(
          'Delete ${_selectedClothingIds.length} selected clothing items? This cannot be undone.',
        ),
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

    setState(() => _movingItem = true);

    int successCount = 0;
    for (final id in _selectedClothingIds) {
      final ok = await clothingService.deleteClothing(id);
      if (ok) successCount++;
    }

    if (!mounted) return;

    setState(() {
      _movingItem = false;
      _selectionMode = false;
      _selectedClothingIds.clear();
    });

    if (successCount > 0) {
      hasChanges = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted $successCount item(s)')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete selected items')),
      );
    }
  }

  Future<void> _editNonClothingItem(Map<String, dynamic> item) async {
    final nameController = TextEditingController(
      text: (item['name'] ?? '').toString(),
    );
    final descriptionController = TextEditingController(
      text: (item['description'] ?? '').toString(),
    );

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Non-Clothing Item',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Update item details',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1A1A1A),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                labelText: 'Description',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1A1A1A),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    final ok = await miscService.updateNonClothing(_asInt(item['id']), {
      'name': name,
      'description': descriptionController.text.trim(),
    });

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update item')));
      return;
    }

    hasChanges = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item updated'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    _load();
  }

  Future<void> _deleteNonClothingItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
          'Delete "${(item['name'] ?? 'item').toString()}"? This action cannot be undone.',
        ),
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

    final ok = await miscService.deleteNonClothing(_asInt(item['id']));
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete item')));
      return;
    }

    hasChanges = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item deleted'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    _load();
  }

  Future<void> _showEditStorageDialog() async {
    final storage = data!['storage'] as Map<String, dynamic>;
    final nameController = TextEditingController(text: storage['name'] ?? '');

    final save = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Storage'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Storage name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) return;
    final newName = nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      await storageService.update(
        id: _asInt(storage['id']),
        name: newName,
        type: (storage['type'] ?? '').toString(),
      );

      if (!mounted) return;
      hasChanges = true;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update storage')));
    }
  }

  Future<void> _deleteStorage() async {
    final storage = data!['storage'] as Map<String, dynamic>;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Storage?'),
        content: Text('Are you sure you want to delete "${storage['name']}"?'),
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

    try {
      await storageService.delete(_asInt(storage['id']));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete. Remove items/sub-storages first.'),
        ),
      );
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  List<String> _storageOptionsFor(List clothes, String field) {
    final mapped = clothes
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    return ClothingQueryService.optionsForField(mapped, field);
  }

  List<String> _storageTagOptions(List clothes) {
    final mapped = clothes
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    return ClothingQueryService.tagOptions(mapped);
  }

  int _storageActiveFilterCount() {
    int count = 0;
    if (_storageFilterColor != 'All') count++;
    if (_storageFilterSubcategory != 'All') count++;
    if (_storageFilterOccasion != 'All') count++;
    if (_storageFilterTag != 'All') count++;
    if (_storageFavoritesOnly) count++;
    if (_storageSortBy != 'Category (A-Z)') count++;
    return count;
  }

  Future<void> _openStorageFilterSheet(List clothes) async {
    String color = _storageFilterColor;
    String subcategory = _storageFilterSubcategory;
    String occasion = _storageFilterOccasion;
    String tag = _storageFilterTag;
    bool favoritesOnly = _storageFavoritesOnly;
    String sortBy = _storageSortBy;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          Widget dd(
            String label,
            String value,
            List<String> options,
            ValueChanged<String?> onChanged,
          ) {
            return DropdownButtonFormField<String>(
              initialValue: options.contains(value) ? value : 'All',
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChanged,
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    dd(
                      'Subcategory',
                      subcategory,
                      _storageOptionsFor(clothes, 'subcategory'),
                      (v) {
                        setModalState(() => subcategory = v ?? 'All');
                      },
                    ),
                    const SizedBox(height: 10),
                    dd(
                      'Occasion',
                      occasion,
                      _storageOptionsFor(clothes, 'occasion'),
                      (v) {
                        setModalState(() => occasion = v ?? 'All');
                      },
                    ),
                    const SizedBox(height: 10),
                    dd(
                      'Color',
                      color,
                      _storageOptionsFor(clothes, 'dominant_color'),
                      (v) {
                        setModalState(() => color = v ?? 'All');
                      },
                    ),
                    const SizedBox(height: 10),
                    dd('Tag', tag, _storageTagOptions(clothes), (v) {
                      setModalState(() => tag = v ?? 'All');
                    }),
                    const SizedBox(height: 10),
                    dd(
                      'Sort',
                      sortBy,
                      const [
                        'Category (A-Z)',
                        'Subcategory (A-Z)',
                        'Favorites first',
                      ],
                      (v) {
                        setModalState(() => sortBy = v ?? 'Category (A-Z)');
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Favorites only'),
                      value: favoritesOnly,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setModalState(() => favoritesOnly = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                color = 'All';
                                subcategory = 'All';
                                occasion = 'All';
                                tag = 'All';
                                favoritesOnly = false;
                                sortBy = 'Category (A-Z)';
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _storageFilterColor = color;
                                _storageFilterSubcategory = subcategory;
                                _storageFilterOccasion = occasion;
                                _storageFilterTag = tag;
                                _storageFavoritesOnly = favoritesOnly;
                                _storageSortBy = sortBy;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Apply'),
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
      ),
    );
  }

  Future<void> _toggleStorageFavourite(Map<String, dynamic> item) async {
    final oldValue = item['is_favourite'] == true;
    setState(() => item['is_favourite'] = !oldValue);

    final ok = await clothingService.toggleFavourite(_asInt(item['id']));
    if (!mounted) return;

    if (!ok) {
      setState(() => item['is_favourite'] = oldValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update favourite')),
      );
      return;
    }

    hasChanges = true;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Storage Details')),
        body: Center(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() => loading = true);
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    final storage = data!['storage'] as Map<String, dynamic>;
    final clothes = data!['clothes'] as List;
    final nonClothes = data!['non_clothing_items'] as List;
    final subStorages = storage['sub_storages'] as List;
    final counts = data!['counts'] as Map<String, dynamic>;
    final query = _searchQuery.trim().toLowerCase();
    final filteredClothes = ClothingQueryService.filterAndSort(
      items: clothes.map((c) => Map<String, dynamic>.from(c as Map)).toList(),
      query: query,
      selectedSubcategory: _storageFilterSubcategory,
      selectedOccasion: _storageFilterOccasion,
      selectedColor: _storageFilterColor,
      selectedTag: _storageFilterTag,
      favoritesOnly: _storageFavoritesOnly,
      sortBy: _storageSortBy,
    );

    final colorStat = _mostCommonColor(clothes);
    final categoryDist = _categoryDistribution(clothes);
    final itemDist = _itemDistribution(clothes, nonClothes);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, hasChanges);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text((storage['name'] ?? 'Storage').toString()),
          actions: [
            PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) {
                if (v == 'edit') _showEditStorageDialog();
                if (v == 'delete') _deleteStorage();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  if (_breadcrumbChain.length > 1) ...[
                    _sectionCard(
                      child: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.account_tree_outlined, size: 18),
                          for (int i = 0; i < _breadcrumbChain.length; i++) ...[
                            if (i > 0)
                              const Icon(Icons.chevron_right, size: 18),
                            if (i == _breadcrumbChain.length - 1)
                              Text(
                                (_breadcrumbChain[i]['name'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              InkWell(
                                onTap: () => _openStorage(
                                  _asInt(_breadcrumbChain[i]['id']),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    (_breadcrumbChain[i]['name'] ?? '')
                                        .toString(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _sectionCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _count('Clothes', _asInt(counts['clothing'])),
                            _count('Other', _asInt(counts['non_clothing'])),
                            _count('Total', _asInt(counts['total'])),
                          ],
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Put Away'),
                          subtitle: const Text('Mark this storage as put away'),
                          value: storage['is_put_away'] == true,
                          onChanged: _togglePutAway,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatChip('Top color', colorStat),
                              ...categoryDist.entries.map(
                                (e) => _buildStatChip(
                                  e.key[0].toUpperCase() + e.key.substring(1),
                                  e.value.toString(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDistributionChart(itemDist),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sub Storages',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (subStorages.isEmpty)
                          const Center(child: Text('No sub storages yet'))
                        else
                          SizedBox(
                            height: 118,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: subStorages.length,
                              itemBuilder: (context, i) {
                                final s =
                                    subStorages[i] as Map<String, dynamic>;
                                return GestureDetector(
                                  onTap: () => _openStorage(_asInt(s['id'])),
                                  child: Container(
                                    width: 168,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      color: Colors.grey.shade50,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                _storageTypeIcon(
                                                  s['type']?.toString(),
                                                ),
                                                size: 16,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (s['is_put_away'] == true)
                                              const Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          (s['name'] ?? 'Storage').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${_asInt(s['item_count'])} items',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Clothing',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_selectionMode) ...[
                              TextButton(
                                onPressed: () => _toggleSelectionMode(false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 4),
                              FilledButton.icon(
                                onPressed: _selectedClothingIds.isEmpty
                                    ? null
                                    : _deleteSelectedClothing,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: Text(
                                  'Delete (${_selectedClothingIds.length})',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ] else
                              OutlinedButton.icon(
                                onPressed: () => _toggleSelectionMode(true),
                                icon: const Icon(Icons.checklist, size: 18),
                                label: const Text('Select'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText:
                                      'Smart search: "black casual shirt", "winter jacket"',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openStorageFilterSheet(clothes),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.tune, size: 20),
                                    if (_storageActiveFilterCount() > 0) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF111827),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '${_storageActiveFilterCount()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (filteredClothes.isEmpty)
                          Center(
                            child: Text(
                              query.isEmpty
                                  ? 'No clothes here yet'
                                  : 'No clothes match your search',
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 0.74,
                                ),
                            itemCount: filteredClothes.length,
                            itemBuilder: (context, i) {
                              final item = filteredClothes[i];
                              final itemId = _asInt(item['id']);
                              final isSelected = _selectedClothingIds.contains(
                                itemId,
                              );

                              return GestureDetector(
                                onTap: () {
                                  if (_selectionMode) {
                                    _toggleClothingSelection(itemId);
                                    return;
                                  }
                                  _openClothingDetail(itemId);
                                },
                                onLongPress: () {
                                  if (_selectionMode) {
                                    _toggleClothingSelection(itemId);
                                    return;
                                  }
                                  _moveClothing(item);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(6),
                                          child: item['image'] == null
                                              ? const Icon(
                                                  Icons.image_not_supported,
                                                )
                                              : Image.network(
                                                  _img(item['image']),
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) =>
                                                      const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                      ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            if (_selectionMode) ...[
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked,
                                                size: 14,
                                                color: isSelected
                                                    ? Colors.blue
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                (item['subcategory'] ??
                                                        item['category'] ??
                                                        'Item')
                                                    .toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            if (!_selectionMode)
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  iconSize: 16,
                                                  onPressed: () =>
                                                      _toggleStorageFavourite(
                                                        item,
                                                      ),
                                                  icon: Icon(
                                                    item['is_favourite'] == true
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color:
                                                        item['is_favourite'] ==
                                                            true
                                                        ? Colors.red
                                                        : Colors.grey,
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
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Other Items',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (nonClothes.isEmpty)
                          const Center(
                            child: Text('No non-clothing items here yet'),
                          )
                        else
                          ...nonClothes.map(
                            (n) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.inventory),
                              title: Text((n['name'] ?? 'Item').toString()),
                              subtitle: Text(
                                (n['description'] ?? '').toString(),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editNonClothingItem(
                                      Map<String, dynamic>.from(n as Map),
                                    );
                                  }
                                  if (value == 'delete') {
                                    _deleteNonClothingItem(
                                      Map<String, dynamic>.from(n as Map),
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_movingItem)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final addType = await showModalBottomSheet<String>(
              context: context,
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(
                      title: Text(
                        'Add Item',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.checkroom_outlined),
                      title: const Text('Clothing'),
                      onTap: () => Navigator.pop(context, 'clothing'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.hiking_outlined),
                      title: const Text('Shoes'),
                      onTap: () => Navigator.pop(context, 'shoes'),
                    ),
                  ],
                ),
              ),
            );

            if (addType == null) return;

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UploadClothingScreen(
                  storageId: widget.storageId,
                  isShoe: addType == 'shoes',
                ),
              ),
            );

            if (result == true || result == null) {
              hasChanges = true;
              _load();
            }
          },
          label: const Text('Add Item'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _count(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }
}

