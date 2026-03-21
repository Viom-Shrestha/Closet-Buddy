import 'package:flutter/material.dart';

import '../services/clothing_service.dart';
import '../services/recommendation_service.dart';
import '../services/outfit_service.dart';
import 'clothing_detail_screen.dart';
import 'outfit_screen.dart';
import '../widgets/outfit_canvas.dart';
import '../services/api_client.dart';
import '../utils/outfit_slot_rules.dart';

class RecommendationScreen extends StatefulWidget {
  final Map<String, dynamic>? weatherData;
  final String title;

  const RecommendationScreen({
    super.key,
    this.weatherData,
    this.title = 'Outfit Generation',
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final RecommendationService _service = RecommendationService();
  final ClothingService _clothingService = ClothingService();
  final OutfitService _outfitService = OutfitService();
  final TextEditingController _occasionCtrl = TextEditingController();
  final TextEditingController _promptCtrl = TextEditingController();

  final List<String> _temperatureOptions = const [
    'freezing',
    'cold',
    'cool',
    'warm',
    'hot',
  ];
  final List<String> _weatherOptions = const [
    'rainy',
    'snowy',
    'windy',
    'humid',
    'dry',
  ];

  String _temperature = 'cool';
  String _weather = 'dry';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  Map<int, Map<String, dynamic>> _clothingById = {};
  final Set<int> _saving = {};
  final Set<int> _saved = {};
  final Map<int, Map<String, dynamic>> _savedOutfits = {};
  final Map<int, Map<String, int?>> _overrides = {};
  final List<int> _compare = [];

  @override
  void initState() {
    super.initState();
    _seedWeatherLabels();
    _loadClothing();
  }

  @override
  void dispose() {
    _occasionCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _seedWeatherLabels() {
    final tempRaw = widget.weatherData?['temp'];
    final condition = (widget.weatherData?['main'] ?? '').toString();
    if (tempRaw is num) {
      _temperature = _labelFromTemp(tempRaw.toDouble());
    }
    if (condition.isNotEmpty) {
      _weather = _labelFromCondition(condition);
    }
  }

  String _labelFromTemp(double tempC) {
    if (tempC <= 0) return 'freezing';
    if (tempC <= 10) return 'cold';
    if (tempC <= 18) return 'cool';
    if (tempC <= 26) return 'warm';
    return 'hot';
  }

  String _labelFromCondition(String condition) {
    final text = condition.toLowerCase();
    if (text.contains('rain') ||
        text.contains('drizzle') ||
        text.contains('shower')) {
      return 'rainy';
    }
    if (text.contains('snow') ||
        text.contains('sleet') ||
        text.contains('blizzard')) {
      return 'snowy';
    }
    if (text.contains('wind')) return 'windy';
    if (text.contains('humid') ||
        text.contains('mist') ||
        text.contains('fog') ||
        text.contains('haze')) {
      return 'humid';
    }
    return 'dry';
  }

  Future<void> _loadClothing() async {
    final items = await _clothingService.getAllClothes();
    final map = <int, Map<String, dynamic>>{};
    for (final item in items) {
      final id = _asInt(item['id']);
      if (id != null) {
        final cloned = Map<String, dynamic>.from(item);
        cloned['color'] = cloned['color'] ?? cloned['dominant_color'];
        map[id] = cloned;
      }
    }
    if (!mounted) return;
    setState(() => _clothingById = map);
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_clothingById.isEmpty) {
        await _loadClothing();
      }
      final results = await _service.recommend(
        temperature: _temperature,
        weather: _weather,
        occasion: _occasionCtrl.text,
        prompt: _promptCtrl.text,
      );
      final trimmed = results.take(3).toList();
      if (!mounted) return;
      setState(() {
        _results = trimmed;
        _saved.clear();
        _savedOutfits.clear();
        _compare.clear();
        _overrides.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveOutfit(int index, Map<String, dynamic> rec) async {
    if (_saving.contains(index)) return;
    if (_saved.contains(index)) {
      _openSavedOutfit(index);
      return;
    }
    final payload = _buildSavePayload(index, rec);
    if (payload == null) {
      _showSnack('Missing required items for this outfit.');
      return;
    }
    _openRatingSheet(index, payload);
  }

  void _openSavedOutfit(int index) {
    final saved = _savedOutfits[index];
    if (saved == null) {
      _showSnack('Outfit already saved.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OutfitDetailPage(initialOutfit: saved)),
    );
  }

  void _openRatingSheet(int index, Map<String, dynamic> payload) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        int currentRating = 0;
        bool savingRating = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate this outfit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pick a quick rating before saving.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your rating',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _starRatingRow(
                          rating: currentRating,
                          size: 26,
                          onSelected: (value) {
                            setModalState(() => currentRating = value);
                          },
                        ),
                        if (currentRating == 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Choose at least 1 star to continue.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: savingRating || currentRating == 0
                          ? null
                          : () async {
                              setModalState(() => savingRating = true);
                              final payloadWithRating =
                                  Map<String, dynamic>.from(payload)
                                    ..['rating'] = currentRating;
                              setState(() => _saving.add(index));
                              final created = await _outfitService.create(
                                payloadWithRating,
                              );
                              if (!mounted) return;
                              setState(() {
                                _saving.remove(index);
                                if (created != null) {
                                  _saved.add(index);
                                  _savedOutfits[index] = created;
                                }
                              });
                              if (created == null) {
                                if (mounted) {
                                  setModalState(() => savingRating = false);
                                }
                                _showSnack('Failed to save outfit.');
                                return;
                              }
                              if (mounted) Navigator.pop(context);
                              if (created != null) {
                                Navigator.pushReplacement(
                                  this.context,
                                  MaterialPageRoute(
                                    builder: (_) => OutfitBuilderPage(
                                      existingOutfit: created,
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Save outfit'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _starRatingRow({
    required int rating,
    required ValueChanged<int> onSelected,
    double size = 22,
  }) {
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
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: '$value stars',
        );
      }),
    );
  }

  String _buildOutfitName(Map<String, dynamic> rec) {
    final temp = _temperature.toUpperCase();
    final cond = _weather.toUpperCase();
    return 'AI Outfit $temp $cond';
  }

  Map<String, dynamic>? _buildSavePayload(int index, Map<String, dynamic> rec) {
    final topId = _resolvedSlotId(index, rec, 'topwear');
    final bottomId = _resolvedSlotId(index, rec, 'bottomwear');
    final shoesId = _resolvedSlotId(index, rec, 'shoes');
    if (topId == null || bottomId == null || shoesId == null) {
      return null;
    }

    final payload = <String, dynamic>{
      'name': _buildOutfitName(rec),
      'occasion': _occasionCtrl.text.trim().isEmpty
          ? null
          : _occasionCtrl.text.trim(),
      'topwear_id': topId,
      'bottomwear_id': bottomId,
      'shoes_id': shoesId,
    };

    final outerwearId = _resolvedSlotId(index, rec, 'outerwear');
    if (outerwearId != null) {
      payload['outerwear_id'] = outerwearId;
    }

    return payload;
  }

  void _openItemDetail(int? id) {
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClothingDetailScreen(clothingId: id)),
    );
  }

  void _showOutfitItems(int index, Map<String, dynamic> rec) {
    final items = _mapOutfitItems(index, rec);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Outfit items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final entry in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _itemThumb(entry['item'] as Map<String, dynamic>?),
                  title: Text(entry['label'] as String),
                  subtitle: Text(
                    _itemTitle(entry['item'] as Map<String, dynamic>?),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openItemDetail(_asInt(entry['item']?['id']));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _toggleCompare(int index) {
    setState(() {
      if (_compare.contains(index)) {
        _compare.remove(index);
      } else {
        if (_compare.length >= 2) {
          _compare.removeAt(0);
        }
        _compare.add(index);
      }
    });
  }

  Widget _buildCompareBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
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
          const Icon(Icons.compare_arrows, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Compare selected outfits',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _compare.clear()),
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _compare.length == 2 ? _openCompareSheet : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            child: const Text('Compare'),
          ),
        ],
      ),
    );
  }

  void _openCompareSheet() {
    if (_compare.length != 2) return;
    final first = _compare[0];
    final second = _compare[1];
    final firstRec = _results[first];
    final secondRec = _results[second];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Outfit comparison',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _compareCard(first, firstRec, label: 'Option A'),
                  const SizedBox(height: 16),
                  _compareCard(second, secondRec, label: 'Option B'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compareCard(
    int index,
    Map<String, dynamic> rec, {
    required String label,
  }) {
    final top = _resolvedItem(index, rec, 'topwear');
    final bottom = _resolvedItem(index, rec, 'bottomwear');
    final shoes = _resolvedItem(index, rec, 'shoes');
    final outer = _resolvedItem(index, rec, 'outerwear');
    final tags = _tagsForOutfit(index, rec);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          OutfitCanvas(
            outerwear: outer,
            topwear: top,
            bottomwear: bottom,
            shoes: shoes,
            accessories: const [],
            compact: false,
            slotScale: 0.85,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map(_tagChip).toList(),
          ),
        ],
      ),
    );
  }

  void _openWhySheet(int index, Map<String, dynamic> rec) {
    final reasons = _whyDetails(index, rec);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why this outfit works',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final reason in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 14, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<String> _whyDetails(int index, Map<String, dynamic> rec) {
    final reasons = <String>[];
    final outer = _resolvedItem(index, rec, 'outerwear');
    if (_temperature == 'freezing' || _temperature == 'cold') {
      reasons.add(
        outer != null
            ? 'Includes outerwear to keep you warm in cold weather.'
            : 'Lightweight layers keep you comfortable while avoiding bulk.',
      );
    }
    if (_temperature == 'hot' || _temperature == 'warm') {
      reasons.add(
        outer == null
            ? 'No outerwear keeps the look breathable in warm weather.'
            : 'Outerwear adds structure while staying lightweight.',
      );
    }
    if (_weather == 'rainy') {
      reasons.add(
        outer != null
            ? 'Outer layer adds protection for rainy conditions.'
            : 'Lightweight pieces keep you comfortable if rain passes quickly.',
      );
    }
    if (_weather == 'snowy') {
      reasons.add(
        outer != null
            ? 'Winter-ready with an outer layer for snowy weather.'
            : 'Add outerwear if the temperature drops further.',
      );
    }

    final tags = _tagsForOutfit(index, rec);
    if (tags.isNotEmpty) {
      reasons.add('Style tags: ${tags.join(', ')}.');
    }

    return reasons;
  }

  void _openSwapSheet(int index, String slot) {
    if (index < 0 || index >= _results.length) return;
    final rec = _results[index];
    final items = _clothingById.values
        .where((item) => OutfitSlotRules.slotFor(item) == slot)
        .toList();
    final currentItem = _resolvedItem(index, rec, slot);
    final currentId = _resolvedSlotId(index, rec, slot);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Swap ${_titleCase(slot)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} options',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (currentItem != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        _itemThumb(currentItem),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _itemTitle(currentItem),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (slot == 'outerwear')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _overrides[index] ??= {};
                                _overrides[index]![slot] = null;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else if (slot == 'outerwear') ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block),
                    title: const Text('No outerwear'),
                    onTap: () {
                      setState(() {
                        _overrides[index] ??= {};
                        _overrides[index]![slot] = null;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No items available for this slot.'),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final itemId = _asInt(item['id']);
                        final isSelected =
                            itemId != null && itemId == currentId;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _overrides[index] ??= {};
                              _overrides[index]![slot] = itemId;
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF111827)
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? const Color(0xFFF3F4F6)
                                  : Colors.white,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    Expanded(child: _itemThumb(item)),
                                    Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Text(
                                        _itemTitle(item),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  const Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: Color(0xFF10B981),
                                    ),
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
        );
      },
    );
  }

  Widget _swapChip(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A1A1A),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Map<String, dynamic>? _itemById(int? id) {
    if (id == null) return null;
    return _clothingById[id];
  }

  int? _resolvedSlotId(int index, Map<String, dynamic> rec, String slot) {
    final overrides = _overrides[index];
    if (overrides != null && overrides.containsKey(slot)) {
      return overrides[slot];
    }
    switch (slot) {
      case 'topwear':
        return _asInt(rec['topwear_id']);
      case 'bottomwear':
        return _asInt(rec['bottomwear_id']);
      case 'shoes':
        return _asInt(rec['shoes_id']);
      case 'outerwear':
        return _asInt(rec['outerwear_id']);
    }
    return null;
  }

  Map<String, dynamic>? _resolvedItem(
    int index,
    Map<String, dynamic> rec,
    String slot,
  ) {
    return _itemById(_resolvedSlotId(index, rec, slot));
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _resolveImage(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }

  Widget _itemThumb(Map<String, dynamic>? item) {
    final imageUrl = _resolveImage(item?['image']);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Icon(Icons.image_outlined, color: Color(0xFF9CA3AF))
          : Image.network(imageUrl, fit: BoxFit.contain),
    );
  }

  String _itemTitle(Map<String, dynamic>? item) {
    if (item == null) return 'Unknown';
    final sub = item['subcategory']?.toString() ?? '';
    final cat = item['category']?.toString() ?? '';
    return sub.isNotEmpty ? sub : cat;
  }

  List<Map<String, dynamic>> _mapOutfitItems(
    int index,
    Map<String, dynamic> rec,
  ) {
    return [
      {'label': 'Topwear', 'item': _resolvedItem(index, rec, 'topwear')},
      {'label': 'Bottomwear', 'item': _resolvedItem(index, rec, 'bottomwear')},
      {'label': 'Footwear', 'item': _resolvedItem(index, rec, 'shoes')},
      if (_resolvedSlotId(index, rec, 'outerwear') != null)
        {'label': 'Outerwear', 'item': _resolvedItem(index, rec, 'outerwear')},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 1,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 16),
                _buildInputCard(),
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF991B1B)),
                    ),
                  ),
                if (_error != null) const SizedBox(height: 12),
                _buildResults(),
                const SizedBox(height: 90),
              ],
            ),
            if (_compare.length == 2)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: _buildCompareBar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Tell the stylist what you want',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Temperature',
                  value: _temperature,
                  options: _temperatureOptions,
                  onChanged: (value) => setState(() => _temperature = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Weather',
                  value: _weather,
                  options: _weatherOptions,
                  onChanged: (value) => setState(() => _weather = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _occasionCtrl,
            label: 'Occasion (optional)',
            hint: 'e.g. casual, formal, office',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _promptCtrl,
            label: 'Style prompt (optional)',
            hint: 'e.g. minimal black, bright summer',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'Generating...' : 'Generate outfits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        _occasionCtrl.clear();
                        _promptCtrl.clear();
                        setState(() {
                          _results = [];
                          _saved.clear();
                        });
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A1A1A),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Temp: ${_titleCase(_temperature)}'),
              _chip('Weather: ${_titleCase(_weather)}'),
              if (_occasionCtrl.text.trim().isNotEmpty)
                _chip('Occasion: ${_occasionCtrl.text.trim()}'),
              if (_promptCtrl.text.trim().isNotEmpty)
                _chip('Prompt: ${_promptCtrl.text.trim()}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outfit Generation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fine-tuned for $_temperature / $_weather',
            style: const TextStyle(color: Color(0xFFD1D5DB)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(Icons.thermostat_rounded, _titleCase(_temperature)),
              _heroChip(Icons.cloud_outlined, _titleCase(_weather)),
              if (_occasionCtrl.text.trim().isNotEmpty)
                _heroChip(Icons.event_outlined, _occasionCtrl.text.trim()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            label,
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(_titleCase(option)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Center(
              child: Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF9CA3AF),
                size: 32,
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Ready to style your day',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 4),
            Center(
              child: Text(
                'Adjust the weather labels or add a prompt, then generate outfits.',
                style: TextStyle(color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 14),
            Text('Quick tips', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('• Add at least one shoe and bottomwear item.'),
            Text('• Try a clearer occasion like “formal” or “casual”.'),
            Text('• Use a short style prompt like “minimal black”.'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recommended Outfits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            Text(
              '${_results.length} results',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap the compare icon to select two outfits.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _results.length; i++) ...[
          _buildOutfitCard(i, _results[i]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildOutfitCard(int index, Map<String, dynamic> rec) {
    final top = _resolvedItem(index, rec, 'topwear');
    final bottom = _resolvedItem(index, rec, 'bottomwear');
    final shoes = _resolvedItem(index, rec, 'shoes');
    final outer = _resolvedItem(index, rec, 'outerwear');
    final accent = _paletteDots([top, bottom, shoes, outer]);
    final isSaving = _saving.contains(index);
    final isSaved = _saved.contains(index);
    final tags = _tagsForOutfit(index, rec);
    final comparing = _compare.contains(index);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Recommendation ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              const Spacer(),
              Row(children: accent),
            ],
          ),
          const SizedBox(height: 10),
          OutfitCanvas(
            outerwear: outer,
            topwear: top,
            bottomwear: bottom,
            shoes: shoes,
            accessories: const [],
            compact: false,
            slotScale: 0.85,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.checkroom_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _titleForOutfit(top, bottom, shoes),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _toggleCompare(index),
                icon: Icon(
                  Icons.compare_arrows,
                  color: comparing
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map(_tagChip).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showOutfitItems(index, rec),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('View items'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : isSaved
                      ? () => _openSavedOutfit(index)
                      : () => _saveOutfit(index, rec),
                  icon: isSaved
                      ? const Icon(Icons.check_circle_outline, size: 18)
                      : const Icon(Icons.star_border_rounded, size: 18),
                  label: Text(isSaved ? 'Saved' : 'Select & rate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSaved
                        ? const Color(0xFF10B981)
                        : const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openWhySheet(index, rec),
                  icon: const Icon(Icons.tips_and_updates_outlined, size: 18),
                  label: const Text('Why this works'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _swapChip(
                'Swap top',
                Icons.swap_vert,
                () => _openSwapSheet(index, 'topwear'),
              ),
              _swapChip(
                'Swap bottom',
                Icons.swap_vert,
                () => _openSwapSheet(index, 'bottomwear'),
              ),
              _swapChip(
                'Swap shoes',
                Icons.swap_horiz,
                () => _openSwapSheet(index, 'shoes'),
              ),
              _swapChip(
                'Swap outer',
                Icons.layers_outlined,
                () => _openSwapSheet(index, 'outerwear'),
              ),
            ],
          ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: card,
    );
  }

  String _titleForOutfit(
    Map<String, dynamic>? top,
    Map<String, dynamic>? bottom,
    Map<String, dynamic>? shoes,
  ) {
    final parts =
        [
              top?['subcategory'] ?? top?['category'],
              bottom?['subcategory'] ?? bottom?['category'],
              shoes?['subcategory'] ?? shoes?['category'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .toList();
    if (parts.isEmpty) return 'Recommended outfit';
    return parts.map((p) => p.toString()).join(' + ');
  }

  List<Widget> _paletteDots(List<Map<String, dynamic>?> items) {
    final colors = <Color>[];
    for (final item in items) {
      if (item == null) continue;
      final dominant = (item['dominant_color'] ?? item['color']).toString();
      final secondary = (item['secondary_color'] ?? '').toString();
      final c1 = _colorFromName(dominant);
      final c2 = _colorFromName(secondary);
      if (c1 != null) colors.add(c1);
      if (c2 != null) colors.add(c2);
    }
    final unique = <Color>[];
    for (final c in colors) {
      if (!unique.contains(c)) unique.add(c);
    }
    final display = unique.take(4).toList();
    if (display.isEmpty) {
      return [_dot(const Color(0xFFE5E7EB)), _dot(const Color(0xFFF3F4F6))];
    }
    return display.map(_dot).toList();
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }

  Color? _colorFromName(String raw) {
    final value = raw.toLowerCase();
    const colorMap = {
      'navy': Color(0xFF2C3E6B),
      'blue': Color(0xFF3B8BD4),
      'black': Color(0xFF222222),
      'white': Color(0xFFD0CCC6),
      'grey': Color(0xFF888888),
      'gray': Color(0xFF888888),
      'olive': Color(0xFF7A8C5A),
      'green': Color(0xFF2D7A4F),
      'red': Color(0xFFC94040),
      'brown': Color(0xFF8B6347),
      'tan': Color(0xFFC9A96E),
      'beige': Color(0xFFD4B896),
      'pink': Color(0xFFE8A0B0),
      'purple': Color(0xFF7B5EA7),
      'yellow': Color(0xFFE8C547),
      'orange': Color(0xFFE8843C),
      'cream': Color(0xFFEDE7DD),
    };
    for (final entry in colorMap.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<String> _tagsForOutfit(int index, Map<String, dynamic> rec) {
    final tags = <String>[];
    final top = _resolvedItem(index, rec, 'topwear');
    final bottom = _resolvedItem(index, rec, 'bottomwear');
    final shoes = _resolvedItem(index, rec, 'shoes');
    final outer = _resolvedItem(index, rec, 'outerwear');
    final items = [top, bottom, shoes, outer].whereType<Map<String, dynamic>>();

    if (_temperature == 'freezing' || _temperature == 'cold') {
      tags.add(outer != null ? 'Cold-ready' : 'Light layers');
    }
    if (_temperature == 'hot' || _temperature == 'warm') {
      tags.add(outer == null ? 'Breathable' : 'Layered');
    }
    if (_weather == 'rainy' && outer != null) {
      tags.add('Rain-friendly');
    }
    if (_weather == 'snowy' && outer != null) {
      tags.add('Winter-ready');
    }

    final occasion = _occasionCtrl.text.trim().toLowerCase();
    if (occasion.isNotEmpty) {
      final matches = items.any((item) {
        final itemOcc = (item['occasion'] ?? '').toString().toLowerCase();
        final attrs = (item['attributes'] is List)
            ? (item['attributes'] as List)
                  .map((e) => e.toString().toLowerCase())
                  .toList()
            : <String>[];
        return itemOcc == occasion || attrs.contains(occasion);
      });
      if (matches) tags.add('Occasion fit');
    }

    final palette = _paletteTone(items.toList());
    if (palette == 'neutral') {
      tags.add('Neutral palette');
    } else if (palette == 'bold') {
      tags.add('Bold mix');
    } else {
      tags.add('Balanced colors');
    }

    return tags.take(4).toList();
  }

  String _paletteTone(List<Map<String, dynamic>> items) {
    int neutral = 0;
    int total = 0;
    for (final item in items) {
      final colors = [
        item['dominant_color'],
        item['secondary_color'],
        item['color'],
      ];
      for (final color in colors) {
        final text = (color ?? '').toString().toLowerCase();
        if (text.isEmpty) continue;
        total += 1;
        if (_isNeutralColor(text)) neutral += 1;
      }
    }
    if (total == 0) return 'neutral';
    final ratio = neutral / total;
    if (ratio >= 0.7) return 'neutral';
    if (ratio <= 0.35) return 'bold';
    return 'balanced';
  }

  bool _isNeutralColor(String value) {
    const neutrals = [
      'black',
      'white',
      'gray',
      'grey',
      'beige',
      'tan',
      'cream',
      'navy',
    ];
    return neutrals.any(value.contains);
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
