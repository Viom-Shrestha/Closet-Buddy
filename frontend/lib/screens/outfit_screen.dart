import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/clothing_service.dart';
import '../services/outfit_service.dart';
import '../widgets/outfit_canvas.dart';
import 'add_item_screen.dart';

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

  Future<void> _openBuilder({Map<String, dynamic>? outfit}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(existingOutfit: outfit),
      ),
    );
    if (changed == true) {
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

  @override
  Widget build(BuildContext context) {
    final page = RefreshIndicator(
      onRefresh: _loadOutfits,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outfit Studio',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Build outfits, save them, and reuse the same layered display for AI results.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : () => _openBuilder(),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                icon: const Icon(Icons.add),
                label: const Text('Build'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _flowCard(
            icon: Icons.construction_outlined,
            title: 'Manual Outfit Builder',
            subtitle: 'Select topwear, bottomwear, shoes, and silhouette.',
            actionLabel: 'Open',
            onTap: () => _openBuilder(),
          ),
          const SizedBox(height: 10),
          _flowCard(
            icon: Icons.auto_awesome_outlined,
            title: 'AI Generated Outfit',
            subtitle: 'Uses the same layered renderer. Hook recommendation engine next.',
            actionLabel: 'Soon',
          ),
          const SizedBox(height: 20),
          const Text(
            'Outfit Gallery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_outfits.isEmpty)
            _emptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 900
                    ? 4
                    : width > 700
                        ? 3
                        : 2;
                return GridView.builder(
                  itemCount: _outfits.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final outfit = _outfits[index];
                    return _galleryCard(outfit);
                  },
                );
              },
            ),
          const SizedBox(height: 28),
        ],
      ),
    );

    if (widget.embedded) return page;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Outfits'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
      ),
      body: page,
    );
  }

  Widget _flowCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4B5563)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.checkroom_outlined, size: 34, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text('No outfits yet'),
          SizedBox(height: 4),
          Text(
            'Build your first look and it will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _galleryCard(Map<String, dynamic> outfit) {
    final name = (outfit['name'] ?? 'Untitled Outfit').toString();
    final occasion = (outfit['occasion'] ?? 'Any Occasion').toString();
    final rating = outfit['rating']?.toString() ?? '-';
    final isFavourite = outfit['is_favourite'] == true;
    final silhouette = (outfit['silhouette'] ?? 'male').toString();

    return GestureDetector(
      onTap: () => _openDetail(outfit),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutfitCanvas(
                topwear: _slot(outfit, 'topwear_item'),
                bottomwear: _slot(outfit, 'bottomwear_item'),
                shoes: _slot(outfit, 'shoes_item'),
                silhouette: silhouette,
                height: 190,
                compact: true,
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    occasion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(rating, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Icon(
                        isFavourite ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFavourite ? const Color(0xFFDC2626) : const Color(0xFF9CA3AF),
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
}

class OutfitBuilderPage extends StatefulWidget {
  final Map<String, dynamic>? existingOutfit;

  const OutfitBuilderPage({super.key, this.existingOutfit});

  @override
  State<OutfitBuilderPage> createState() => _OutfitBuilderPageState();
}

class _OutfitBuilderPageState extends State<OutfitBuilderPage> {
  final ClothingService _clothingService = ClothingService();
  final OutfitService _outfitService = OutfitService();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _occasionCtrl = TextEditingController();
  final TextEditingController _ratingCtrl = TextEditingController();

  final PageController _topCtrl = PageController(viewportFraction: 0.38);
  final PageController _bottomCtrl = PageController(viewportFraction: 0.38);
  final PageController _shoesCtrl = PageController(viewportFraction: 0.38);

  List<Map<String, dynamic>> _tops = [];
  List<Map<String, dynamic>> _bottoms = [];
  List<Map<String, dynamic>> _shoes = [];

  int _topIndex = -1;
  int _bottomIndex = -1;
  int _shoesIndex = -1;
  String _silhouette = 'male';
  bool _loading = true;
  bool _saving = false;

  int? get _editingOutfitId => _asInt(widget.existingOutfit?['id']);

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
    _ratingCtrl.dispose();
    _topCtrl.dispose();
    _bottomCtrl.dispose();
    _shoesCtrl.dispose();
    super.dispose();
  }

  void _prefillMetadata() {
    final existing = widget.existingOutfit;
    if (existing == null) return;
    _nameCtrl.text = (existing['name'] ?? '').toString();
    _occasionCtrl.text = (existing['occasion'] ?? '').toString();
    final rating = existing['rating'];
    if (rating != null) _ratingCtrl.text = rating.toString();
    _silhouette = (existing['silhouette'] ?? 'male').toString().toLowerCase() == 'female'
        ? 'female'
        : 'male';
  }

  Future<void> _loadClothes() async {
    final items = await _clothingService.getAllClothes();
    if (!mounted) return;

    final tops = <Map<String, dynamic>>[];
    final bottoms = <Map<String, dynamic>>[];
    final shoes = <Map<String, dynamic>>[];

    for (final item in items) {
      if (OutfitSlotRules.isShoe(item)) {
        shoes.add(item);
      } else if (OutfitSlotRules.isBottom(item)) {
        bottoms.add(item);
      } else {
        tops.add(item);
      }
    }

    setState(() {
      _tops = tops;
      _bottoms = bottoms;
      _shoes = shoes;
      _topIndex = tops.isEmpty ? -1 : 0;
      _bottomIndex = bottoms.isEmpty ? -1 : 0;
      _shoesIndex = shoes.isEmpty ? -1 : 0;
      _loading = false;
    });

    _applyExistingSelection();
  }

  void _applyExistingSelection() {
    final existing = widget.existingOutfit;
    if (existing == null) return;

    final topId = _asInt(_slot(existing, 'topwear_item')?['id']);
    final bottomId = _asInt(_slot(existing, 'bottomwear_item')?['id']);
    final shoesId = _asInt(_slot(existing, 'shoes_item')?['id']);

    if (topId != null && _tops.isNotEmpty) {
      final idx = _indexById(_tops, topId);
      if (idx >= 0) {
        setState(() => _topIndex = idx);
        _jumpToPageSafe(_topCtrl, idx);
      }
    }
    if (bottomId != null && _bottoms.isNotEmpty) {
      final idx = _indexById(_bottoms, bottomId);
      if (idx >= 0) {
        setState(() => _bottomIndex = idx);
        _jumpToPageSafe(_bottomCtrl, idx);
      }
    }
    if (shoesId != null && _shoes.isNotEmpty) {
      final idx = _indexById(_shoes, shoesId);
      if (idx >= 0) {
        setState(() => _shoesIndex = idx);
        _jumpToPageSafe(_shoesCtrl, idx);
      }
    }
  }

  Future<void> _saveOutfit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outfit name is required')),
      );
      return;
    }

    final top = _selected(_tops, _topIndex);
    final bottom = _selected(_bottoms, _bottomIndex);
    final shoes = _selected(_shoes, _shoesIndex);

    if (top == null && bottom == null && shoes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to save outfit')),
      );
      return;
    }

    final rating = int.tryParse(_ratingCtrl.text.trim());
    if (rating != null && (rating < 1 || rating > 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating must be between 1 and 5')),
      );
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': name,
      'occasion': _occasionCtrl.text.trim().isEmpty ? null : _occasionCtrl.text.trim(),
      'rating': rating,
      'silhouette': _silhouette,
      'topwear_id': _asInt(top?['id']),
      'bottomwear_id': _asInt(bottom?['id']),
      'shoes_id': _asInt(shoes?['id']),
    };

    Map<String, dynamic>? result;
    final id = _editingOutfitId;
    if (id == null) {
      result = await _outfitService.create(payload);
    } else {
      result = await _outfitService.update(id, payload);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save outfit')),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTop = _selected(_tops, _topIndex);
    final selectedBottom = _selected(_bottoms, _bottomIndex);
    final selectedShoes = _selected(_shoes, _shoesIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: Text(_editingOutfitId == null ? 'Outfit Builder' : 'Edit Outfit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                OutfitCanvas(
                  topwear: selectedTop,
                  bottomwear: selectedBottom,
                  shoes: selectedShoes,
                  silhouette: _silhouette,
                  height: 430,
                ),
                const SizedBox(height: 14),
                _metaForm(),
                const SizedBox(height: 14),
                _silhouetteSelector(),
                const SizedBox(height: 14),
                _sliderSection(
                  title: 'Topwear',
                  items: _tops,
                  controller: _topCtrl,
                  selectedIndex: _topIndex,
                  onChanged: (i) => setState(() => _topIndex = i),
                ),
                const SizedBox(height: 12),
                _sliderSection(
                  title: 'Bottomwear',
                  items: _bottoms,
                  controller: _bottomCtrl,
                  selectedIndex: _bottomIndex,
                  onChanged: (i) => setState(() => _bottomIndex = i),
                ),
                const SizedBox(height: 12),
                _sliderSection(
                  title: 'Shoes',
                  items: _shoes,
                  controller: _shoesCtrl,
                  selectedIndex: _shoesIndex,
                  onChanged: (i) => setState(() => _shoesIndex = i),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveOutfit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_editingOutfitId == null ? 'Save Outfit' : 'Update Outfit'),
                ),
              ],
            ),
    );
  }

  Widget _metaForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Outfit name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _occasionCtrl,
            decoration: const InputDecoration(
              labelText: 'Occasion (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ratingCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Rating 1-5 (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _silhouetteSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Silhouette', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'male', label: Text('Male')),
              ButtonSegment<String>(value: 'female', label: Text('Female')),
            ],
            selected: {_silhouette},
            onSelectionChanged: (selection) {
              final value = selection.first;
              setState(() => _silhouette = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required PageController controller,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No items found in this section.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddItemSelectionPage()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            )
          else
            SizedBox(
              height: 130,
              child: PageView.builder(
                controller: controller,
                itemCount: items.length,
                onPageChanged: onChanged,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final image = _resolveImage(item['image']);
                  final title = (item['subcategory'] ?? item['category'] ?? 'Item').toString();
                  final selected = selectedIndex == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.symmetric(horizontal: 6, vertical: selected ? 0 : 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: image.isEmpty
                              ? const Icon(Icons.image_not_supported_outlined)
                              : Image.network(
                                  image,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _selected(List<Map<String, dynamic>> items, int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  Map<String, dynamic>? _slot(Map<String, dynamic> outfit, String key) {
    final raw = outfit[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  int _indexById(List<Map<String, dynamic>> items, int id) {
    for (int i = 0; i < items.length; i++) {
      final itemId = _asInt(items[i]['id']);
      if (itemId == id) return i;
    }
    return -1;
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  void _jumpToPageSafe(PageController controller, int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      controller.jumpToPage(page);
    });
  }

  String _resolveImage(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) {
      return '${ApiClient.host}$url';
    }
    return '${ApiClient.host}/$url';
  }
}

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
      if (result != null) {
        _outfit = result;
      }
      _updatingFav = false;
    });
  }

  Future<void> _editOutfit() async {
    if (_outfit == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(existingOutfit: _outfit),
      ),
    );

    if (changed == true) {
      await _loadDetail();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteOutfit() async {
    final id = _outfitId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete outfit?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await _outfitService.delete(id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete outfit')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outfit = _outfit;
    final silhouette = (outfit?['silhouette'] ?? 'male').toString();
    final name = (outfit?['name'] ?? 'Outfit').toString();
    final occasion = (outfit?['occasion'] ?? 'Any Occasion').toString();
    final rating = outfit?['rating']?.toString() ?? '-';
    final isFavourite = outfit?['is_favourite'] == true;
    final createdAt = (outfit?['created_at'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text('Outfit Detail'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : outfit == null
              ? const Center(child: Text('Outfit not found'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    OutfitCanvas(
                      topwear: _slot(outfit, 'topwear_item'),
                      bottomwear: _slot(outfit, 'bottomwear_item'),
                      shoes: _slot(outfit, 'shoes_item'),
                      silhouette: silhouette,
                      height: 430,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('Occasion: $occasion'),
                          const SizedBox(height: 4),
                          Text('Rating: $rating'),
                          const SizedBox(height: 4),
                          Text('Created: ${createdAt.isEmpty ? '-' : createdAt}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                            onPressed: _updatingFav ? null : _toggleFavourite,
                            icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
                            label: Text(isFavourite ? 'Unfavourite' : 'Favourite'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _deleteOutfit,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Outfit'),
                      ),
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

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}

class OutfitSlotRules {
  static bool isShoe(Map<String, dynamic> item) {
    final text = _normalized(item);
    const keys = ['shoe', 'sneaker', 'boot', 'heel', 'footwear', 'slipper', 'sandal', 'loafer'];
    return keys.any(text.contains);
  }

  static bool isBottom(Map<String, dynamic> item) {
    final text = _normalized(item);
    const keys = [
      'pant',
      'trouser',
      'jean',
      'short',
      'skirt',
      'bottom',
      'jogger',
      'legging',
      'cargo',
    ];
    return keys.any(text.contains);
  }

  static String _normalized(Map<String, dynamic> item) {
    final c = (item['category'] ?? '').toString().toLowerCase();
    final s = (item['subcategory'] ?? '').toString().toLowerCase();
    return '$c $s';
  }
}
