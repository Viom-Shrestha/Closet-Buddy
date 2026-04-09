import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';

import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/services/recommendation_service.dart';
import 'package:frontend/services/outfit_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/features/outfit/screens/outfit_screen.dart';
import 'package:frontend/widgets/outfit_canvas.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/utils/outfit_slot_rules.dart';

enum _CardMenuAction { swap, compare, why }

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
  final RecommendationService _service =
      ServiceRegistry.instance.recommendationService;
  final ClothingService _clothingService =
      ServiceRegistry.instance.clothingService;
  final OutfitService _outfitService = ServiceRegistry.instance.outfitService;

  final TextEditingController _occasionCtrl = TextEditingController();
  final TextEditingController _promptCtrl = TextEditingController();

  // Input state
  final List<String> _temperatureOptions = const [
    'any',
    'freezing',
    'cold',
    'cool',
    'warm',
    'hot',
  ];
  final List<String> _weatherOptions = const [
    'any',
    'rainy',
    'snowy',
    'windy',
    'humid',
    'dry',
  ];
  static const List<String> _occasionClasses = [
    'casual',
    'formal',
    'office',
    'party',
    'date',
    'traditional',
    'sport',
    'home',
    'travel',
    'beach',
    'street',
    'outdoor',
    'workout',
  ];
  static const Map<String, String> _occasionAliases = {
    'date night': 'date',
    'night out': 'party',
    'streetwear': 'street',
    'sporty': 'sport',
    'active': 'sport',
    'athletic': 'sport',
    'gym': 'sport',
    'fitness': 'sport',
    'any': '',
    'any occasion': '',
    'none': '',
  };
  static const List<String> _occasionOptions = [
    '',
    ..._occasionClasses,
  ];

  String _temperature = 'cool';
  String _weather = 'dry';
  String _occasionValue = '';

  // Results state
  bool _showResults = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  String? _processingWarning;
  String? _processedTemperature;
  String? _processedWeather;
  bool _occasionFallbackUsed = false;

  // Interaction state
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
    _rebuildOccasionOptions();
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
    setState(() {
      _clothingById = map;
      _rebuildOccasionOptions();
    });
  }

  Future<void> _generate() async {
    final selectedOccasion = _occasionCtrl.text.trim();
    if (selectedOccasion.isNotEmpty &&
        !_occasionOptions.contains(selectedOccasion)) {
      setState(() {
        _occasionValue = '';
        _occasionCtrl.clear();
      });
      _showSnack(
        'No clothing found for ${_occasionDisplayLabel(selectedOccasion)} yet. Showing best available outfits instead.',
      );
    }

    setState(() {
      _loading = true;
      _error = null;
      _showResults = true;
      _occasionFallbackUsed = false;
    });

    try {
      if (_clothingById.isEmpty) {
        await _loadClothing();
      }
      if (_occasionCtrl.text.trim().isNotEmpty &&
          !_occasionOptions.contains(_occasionCtrl.text.trim())) {
        if (!mounted) return;
        setState(() {
          _occasionValue = '';
          _occasionCtrl.clear();
        });
        _showSnack(
          'Not enough items for that occasion right now. Showing best available outfits instead.',
        );
      }
      final data = await _service.recommend(
        temperature: _temperature,
        weather: _weather,
        occasion: _occasionCtrl.text,
        prompt: _promptCtrl.text,
      );
      final outfitsRaw = data['outfits'];
      final results = outfitsRaw is List
          ? List<Map<String, dynamic>>.from(outfitsRaw)
          : <Map<String, dynamic>>[];
      final metadataRaw = data['metadata'];
      final metadata = metadataRaw is Map<String, dynamic>
          ? metadataRaw
          : metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _results = results;
        _saved.clear();
        _savedOutfits.clear();
        _compare.clear();
        _overrides.clear();
        _processingWarning = data['warning']?.toString();
        _occasionFallbackUsed = data['occasion_fallback_used'] == true;
        _processedTemperature = _coerceOption(
          metadata['temperature'],
          _temperatureOptions,
          fallback: _temperature,
        );
        _processedWeather = _coerceOption(
          metadata['weather'],
          _weatherOptions,
          fallback: _weather,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processingWarning = null;
        _occasionFallbackUsed = false;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _enterInputMode() {
    setState(() => _showResults = false);
  }

  String _coerceOption(
    dynamic raw,
    List<String> allowed, {
    required String fallback,
  }) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (value.isEmpty) return 'any';
    if (allowed.contains(value)) return value;
    return fallback;
  }

  String _normalizeToken(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value.isEmpty) return '';
    return value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _canonicalOccasion(dynamic raw) {
    final normalized = _normalizeToken(raw);
    if (normalized.isEmpty) return '';
    final aliasMapped = _occasionAliases[normalized] ?? normalized;
    if (_occasionClasses.contains(aliasMapped)) return aliasMapped;
    return '';
  }

  List<String> _attributeTokens(dynamic raw) {
    final queue = <String>[];
    if (raw is List) {
      queue.addAll(raw.map((e) => e.toString()));
    } else if (raw is String) {
      queue.addAll(raw.split(RegExp(r'[,\n;]+')));
    }

    final seen = <String>{};
    final tokens = <String>[];
    for (final entry in queue) {
      final token = _normalizeToken(entry);
      if (token.isEmpty || !seen.add(token)) continue;
      tokens.add(token);
    }
    return tokens;
  }

  Set<String> _occasionSignalsForItem(Map<String, dynamic> item) {
    final signals = <String>{};

    final direct = _canonicalOccasion(item['occasion']);
    if (direct.isNotEmpty) {
      signals.add(direct);
    }

    for (final attr in _attributeTokens(item['attributes'])) {
      final mapped = _canonicalOccasion(attr);
      if (mapped.isNotEmpty) {
        signals.add(mapped);
      }
    }

    return signals;
  }

  String _occasionDisplayLabel(String occasion) {
    final token = _normalizeToken(occasion);
    if (token.isEmpty) return 'Any Occasion';
    final canonical = _canonicalOccasion(token);
    if (canonical.isEmpty) {
      return token
          .split(' ')
          .map(
            (part) =>
                part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' ');
    }
    return canonical
        .split(' ')
        .map(
          (part) =>
              part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  void _rebuildOccasionOptions() {
    if (!_occasionOptions.contains(_occasionValue)) {
      _occasionValue = '';
      _occasionCtrl.clear();
      return;
    }
    _occasionCtrl.text = _occasionValue;
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
    setState(() => _saving.add(index));
    final created = await _outfitService.create(payload);
    if (!mounted) return;
    setState(() {
      _saving.remove(index);
      if (created != null) {
        _saved.add(index);
        _savedOutfits[index] = created;
      }
    });

    if (created == null) {
      _showSnack('Failed to save outfit.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailPage(initialOutfit: created),
      ),
    );
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

  void _openEditOutfit(int index, Map<String, dynamic> rec) {
    final topId = _resolvedSlotId(index, rec, 'topwear');
    final bottomId = _resolvedSlotId(index, rec, 'bottomwear');
    final shoesId = _resolvedSlotId(index, rec, 'shoes');
    final outerwearId = _resolvedSlotId(index, rec, 'outerwear');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitBuilderPage(
          initialTopId: topId,
          initialBottomId: bottomId,
          initialShoesId: shoesId,
          initialOuterwearId: outerwearId,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _buildOutfitName(Map<String, dynamic> rec) {
    final temp = _temperature == 'any' ? 'Any Temp' : _temperature.toUpperCase();
    final cond = _weather == 'any' ? 'Any Weather' : _weather.toUpperCase();
    return 'AI Outfit $temp $cond';
  }

  Map<String, dynamic>? _buildSavePayload(int index, Map<String, dynamic> rec) {
    final topId = _resolvedSlotId(index, rec, 'topwear');
    final bottomId = _resolvedSlotId(index, rec, 'bottomwear');
    final shoesId = _resolvedSlotId(index, rec, 'shoes');
    if (topId == null || bottomId == null || shoesId == null) {
      return null;
    }

    final selectedOccasion = _occasionCtrl.text.trim();
    final payload = <String, dynamic>{
      'name': _buildOutfitName(rec),
      'occasion': selectedOccasion.isEmpty
          ? null
          : _occasionDisplayLabel(selectedOccasion),
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

  void _showOutfitItems(int index, Map<String, dynamic> rec) {
    final items = _mapOutfitItems(index, rec);
    showModalBottomSheet(
      context: context,
      backgroundColor: RecommendationTokens.surface,
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
                _itemTile(
                  title: entry['label'] as String,
                  subtitle: _itemTitle(entry['item'] as Map<String, dynamic>?),
                  item: entry['item'] as Map<String, dynamic>?,
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

  void _openSwapMenu(int index, Map<String, dynamic> rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RecommendationTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Swap items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _swapSlotTile(
                  label: 'Topwear',
                  onTap: () {
                    Navigator.pop(context);
                    _openSwapSheet(index, 'topwear');
                  },
                ),
                _swapSlotTile(
                  label: 'Bottomwear',
                  onTap: () {
                    Navigator.pop(context);
                    _openSwapSheet(index, 'bottomwear');
                  },
                ),
                _swapSlotTile(
                  label: 'Footwear',
                  onTap: () {
                    Navigator.pop(context);
                    _openSwapSheet(index, 'shoes');
                  },
                ),
                _swapSlotTile(
                  label: 'Outerwear',
                  onTap: () {
                    Navigator.pop(context);
                    _openSwapSheet(index, 'outerwear');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _swapSlotTile({required String label, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.swap_horiz),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
      backgroundColor: RecommendationTokens.surface,
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
        border: Border.all(color: RecommendationTokens.line),
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
      backgroundColor: RecommendationTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
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
                            color: RecommendationTokens.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(reason)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _whyDetails(int index, Map<String, dynamic> rec) {
    final reasons = <String>[];
    final top = _resolvedItem(index, rec, 'topwear');
    final bottom = _resolvedItem(index, rec, 'bottomwear');
    final shoes = _resolvedItem(index, rec, 'shoes');
    final outer = _resolvedItem(index, rec, 'outerwear');
    final displayTemp = _processedTemperature ?? _temperature;
    final displayWeather = _processedWeather ?? _weather;
    final items = <Map<String, dynamic>>[
      if (top != null) top,
      if (bottom != null) bottom,
      if (shoes != null) shoes,
      if (outer != null) outer,
    ];

    if (displayTemp == 'any') {
      reasons.add('Selected for versatility across different temperatures.');
    } else if (displayTemp == 'freezing' || displayTemp == 'cold') {
      reasons.add(
        outer != null
            ? 'Layered with outerwear for colder conditions.'
            : 'Lightweight layers keep it flexible if temps rise.',
      );
    } else if (displayTemp == 'hot' || displayTemp == 'warm') {
      reasons.add(
        outer == null
            ? 'No outerwear keeps the look breathable in warm weather.'
            : 'Outerwear adds structure while staying lightweight.',
      );
    } else {
      reasons.add('Balanced layers suit moderate temperatures.');
    }

    if (displayWeather == 'any') {
      reasons.add('This combination can adapt across different weather conditions.');
    } else if (displayWeather == 'rainy') {
      reasons.add(
        outer != null
            ? 'Outer layer adds protection for rainy conditions.'
            : 'Lightweight pieces keep you comfortable if rain passes quickly.',
      );
    } else if (displayWeather == 'snowy') {
      reasons.add(
        outer != null
            ? 'Winter-ready with an outer layer for snowy weather.'
            : 'Add outerwear if the temperature drops further.',
      );
    } else if (displayWeather == 'windy') {
      reasons.add(
        outer != null
            ? 'Layering helps block wind while keeping the outfit cohesive.'
            : 'Clean silhouette stays comfortable for breezy conditions.',
      );
    } else if (displayWeather == 'humid') {
      reasons.add(
        'Breathable styling choices help in humid weather.',
      );
    } else {
      reasons.add('Versatile combination works well for dry conditions.');
    }

    final palette = _paletteTone(items);
    if (palette == 'neutral') {
      reasons.add('Neutral tones make this outfit easy to style and repeat.');
    } else if (palette == 'bold') {
      reasons.add('Bold color mix creates visual energy without losing balance.');
    } else {
      reasons.add('Color balance keeps the look polished and wearable.');
    }

    final selectedOccasion = _canonicalOccasion(_occasionCtrl.text.trim());
    if (selectedOccasion.isNotEmpty && items.isNotEmpty) {
      final matched = items.any(
        (item) => _occasionSignalsForItem(item).contains(selectedOccasion),
      );
      reasons.add(
        matched
            ? 'Pieces align with your selected ${_occasionDisplayLabel(selectedOccasion)} occasion.'
            : 'Styling still works even when strict occasion matches are limited.',
      );
    }

    final tags = _tagsForOutfit(index, rec);
    if (tags.isNotEmpty) {
      reasons.add('Style tags: ${tags.join(', ')}.');
    }

    final unique = <String>[];
    for (final reason in reasons) {
      if (!unique.contains(reason)) {
        unique.add(reason);
      }
    }
    if (unique.length < 3) {
      unique.addAll([
        'Top, bottom, and footwear create a complete silhouette.',
        'The outfit balances practicality with style for day-to-day wear.',
      ]);
    }
    return unique.take(5).toList();
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
      backgroundColor: RecommendationTokens.surface,
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
                        color: RecommendationTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (currentItem != null) ...[
                  _itemTile(
                    title: _itemTitle(currentItem),
                    subtitle: 'Current ${_titleCase(slot)}',
                    item: currentItem,
                    trailing: slot == 'outerwear'
                        ? TextButton(
                            onPressed: () {
                              setState(() {
                                _overrides[index] ??= {};
                                _overrides[index]![slot] = null;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Remove'),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
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
                    height: 320,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final itemId = _asInt(item['id']);
                        final isSelected =
                            itemId != null && itemId == currentId;
                        return _itemTile(
                          title: _itemTitle(item),
                          subtitle: _titleCase(slot),
                          item: item,
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: RecommendationTokens.success,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _overrides[index] ??= {};
                              _overrides[index]![slot] = itemId;
                            });
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

  Widget _itemTile({
    required String title,
    required String subtitle,
    required Map<String, dynamic>? item,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _itemThumb(item),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
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
        color: RecommendationTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RecommendationTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Icon(
              Icons.image_outlined,
              color: RecommendationTokens.mutedSoft,
            )
          : Image.network(imageUrl, fit: BoxFit.contain),
    );
  }

  String _itemTitle(Map<String, dynamic>? item) {
    if (item == null) return 'Unknown item';
    final sub = item['subcategory']?.toString() ?? '';
    final cat = item['category']?.toString() ?? '';
    return sub.isNotEmpty ? sub : cat;
  }

  List<Map<String, dynamic>> _mapOutfitItems(
    int index,
    Map<String, dynamic> rec,
  ) {
    return [
      {
        'label': 'Topwear',
        'item': _resolvedItem(index, rec, 'topwear'),
      },
      {
        'label': 'Bottomwear',
        'item': _resolvedItem(index, rec, 'bottomwear'),
      },
      {
        'label': 'Footwear',
        'item': _resolvedItem(index, rec, 'shoes'),
      },
      if (_resolvedSlotId(index, rec, 'outerwear') != null)
        {
          'label': 'Outerwear',
          'item': _resolvedItem(index, rec, 'outerwear'),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecommendationTokens.pageBg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: RecommendationTokens.surface,
        foregroundColor: RecommendationTokens.ink,
        elevation: 1,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _showResults
                  ? _ResultsSection(
                      key: const ValueKey('results'),
                      header: _buildResultsHeader(),
                      error: _error,
                      warning: _processingWarning,
                      occasionFallbackUsed: _occasionFallbackUsed,
                      loading: _loading,
                      emptyState: _buildEmptyState(),
                      children: _buildResultCards(),
                    )
                  : _InputSection(
                      key: const ValueKey('input'),
                      header: _buildHeroHeader(),
                      inputCard: _buildInputCard(),
                      error: _error,
                    ),
            ),
            if (_compare.length == 2)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: _CompareBar(
                    onClear: () => setState(() => _compare.clear()),
                    onCompare: _openCompareSheet,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RecommendationTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RecommendationTokens.line),
        boxShadow: [
          BoxShadow(
            color: RecommendationTokens.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outfit Generation',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: RecommendationTokens.inkStrong,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'AI-styled recommendations with a clean, modern edge.',
            style: TextStyle(color: RecommendationTokens.muted),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: _summaryChips()),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RecommendationTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RecommendationTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recommended Outfits',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _Pressable(
                onTap: _enterInputMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: RecommendationTokens.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Edit inputs',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: RecommendationTokens.inkStrong,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pressable(
                onTap: _loading ? null : _generate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: RecommendationTokens.inkStrong,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              RecommendationTokens.surface,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.refresh,
                          size: 16,
                          color: RecommendationTokens.surface,
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'Regenerate',
                        style: TextStyle(
                          color: RecommendationTokens.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _summaryChips()),
        ],
      ),
    );
  }

  List<Widget> _summaryChips() {
    final displayTemp = _processedTemperature ?? _temperature;
    final displayWeather = _processedWeather ?? _weather;
    final chips = <Widget>[
      _chip('Temp: ${_titleCase(displayTemp)}'),
      _chip('Weather: ${_titleCase(displayWeather)}'),
    ];
    if (_occasionCtrl.text.trim().isNotEmpty) {
      chips.add(
        _chip('Occasion: ${_occasionDisplayLabel(_occasionCtrl.text.trim())}'),
      );
    }
    if (_promptCtrl.text.trim().isNotEmpty) {
      chips.add(_chip('Prompt: ${_promptCtrl.text.trim()}'));
    }
    if ((_processingWarning ?? '').isNotEmpty || _occasionFallbackUsed) {
      chips.add(_chip('Fallback mode'));
    }
    return chips;
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RecommendationTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RecommendationTokens.line),
        boxShadow: [
          BoxShadow(
            color: RecommendationTokens.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
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
          _buildOccasionDropdown(),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _promptCtrl,
            label: 'Style prompt (optional)',
            hint: 'e.g. minimal black, bright summer',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _Pressable(
            onTap: _loading ? null : _generate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: RecommendationTokens.inkStrong,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            RecommendationTokens.surface,
                          ),
                        ),
                      )
                    : const Text(
                        'Generate outfits',
                        style: TextStyle(
                          color: RecommendationTokens.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Occasion',
            labelStyle: const TextStyle(
              color: RecommendationTokens.muted,
              fontWeight: FontWeight.w600,
            ),
            floatingLabelStyle: const TextStyle(
              color: RecommendationTokens.slateSoft,
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: const Icon(
              Icons.theater_comedy_outlined,
              color: RecommendationTokens.slateSoft,
              size: 18,
            ),
            filled: true,
            fillColor: RecommendationTokens.surfaceSoft.withValues(alpha: 0.65),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: RecommendationTokens.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: RecommendationTokens.slateSoft,
                width: 1.4,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _occasionValue,
              isExpanded: true,
              style: const TextStyle(
                color: RecommendationTokens.inkStrong,
                fontWeight: FontWeight.w600,
              ),
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: RecommendationTokens.muted,
              ),
              items: _occasionOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(_occasionDisplayLabel(option)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _occasionValue = value;
                  _occasionCtrl.text = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    IconData icon = Icons.tune_rounded;
    if (label.toLowerCase() == 'temperature') {
      icon = Icons.thermostat_rounded;
    } else if (label.toLowerCase() == 'weather') {
      icon = Icons.wb_cloudy_rounded;
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: RecommendationTokens.muted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: RecommendationTokens.slateSoft,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(
          icon,
          color: RecommendationTokens.slateSoft,
          size: 18,
        ),
        filled: true,
        fillColor: RecommendationTokens.surfaceSoft.withValues(alpha: 0.65),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RecommendationTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: RecommendationTokens.slateSoft,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
            color: RecommendationTokens.inkStrong,
            fontWeight: FontWeight.w600,
          ),
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: RecommendationTokens.muted,
          ),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: RecommendationTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RecommendationTokens.line),
      ),
      child: Column(
        children: const [
          Icon(
            Icons.auto_awesome_outlined,
            size: 36,
            color: RecommendationTokens.mutedSoft,
          ),
          SizedBox(height: 12),
          Text(
            'Ready to style your day',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Set your preferences and generate outfits.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RecommendationTokens.muted),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResultCards() {
    if (_loading) {
      return [const Center(child: CircularProgressIndicator())];
    }

    if (_results.isEmpty) {
      return [_buildEmptyState()];
    }

    return List.generate(_results.length, (index) {
      final rec = _results[index];
      final top = _resolvedItem(index, rec, 'topwear');
      final bottom = _resolvedItem(index, rec, 'bottomwear');
      final shoes = _resolvedItem(index, rec, 'shoes');
      final outer = _resolvedItem(index, rec, 'outerwear');
      final accent = _paletteDots([top, bottom, shoes, outer]);
      final isSaving = _saving.contains(index);
      final isSaved = _saved.contains(index);
      final comparing = _compare.contains(index);

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
        child: _OutfitCard(
          label: 'Recommendation ${index + 1}',
          title: _titleForOutfit(top, bottom, shoes),
          paletteDots: accent,
          canvas: OutfitCanvas(
            outerwear: outer,
            topwear: top,
            bottomwear: bottom,
            shoes: shoes,
            accessories: const [],
            compact: false,
            slotScale: 0.85,
          ),
          isSaving: isSaving,
          isSaved: isSaved,
          isComparing: comparing,
          onEdit: () => _openEditOutfit(index, rec),
          onSave: isSaving ? null : () => _saveOutfit(index, rec),
          onViewItems: () => _showOutfitItems(index, rec),
          onMenuSelected: (action) {
            switch (action) {
              case _CardMenuAction.swap:
                _openSwapMenu(index, rec);
                break;
              case _CardMenuAction.compare:
                _toggleCompare(index);
                break;
              case _CardMenuAction.why:
                _openWhySheet(index, rec);
                break;
            }
          },
        ),
      );
    });
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
      return [
        _dot(RecommendationTokens.line),
        _dot(RecommendationTokens.surfaceSoft),
      ];
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
        border: Border.all(color: RecommendationTokens.surface, width: 1),
      ),
    );
  }

  Color? _colorFromName(String raw) {
    return matchNamedColor(NamedColors.outfit, raw);
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RecommendationTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RecommendationTokens.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: RecommendationTokens.slateSoft,
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
    final displayTemp = _processedTemperature ?? _temperature;
    final displayWeather = _processedWeather ?? _weather;
    final items = [top, bottom, shoes, outer].whereType<Map<String, dynamic>>();

    if (displayTemp == 'any') {
      tags.add('All-temp');
    } else if (displayTemp == 'freezing' || displayTemp == 'cold') {
      tags.add(outer != null ? 'Cold-ready' : 'Light layers');
    }
    if (displayTemp == 'hot' || displayTemp == 'warm') {
      tags.add(outer == null ? 'Breathable' : 'Layered');
    }
    if (displayWeather == 'any') {
      tags.add('Any weather');
    } else if (displayWeather == 'rainy' && outer != null) {
      tags.add('Rain-friendly');
    } else if (displayWeather == 'snowy' && outer != null) {
      tags.add('Winter-ready');
    }

    final occasion = _canonicalOccasion(_occasionCtrl.text.trim());
    if (occasion.isNotEmpty) {
      final matches = items.any((item) {
        return _occasionSignalsForItem(item).contains(occasion);
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
        color: RecommendationTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RecommendationTokens.line),
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

class _InputSection extends StatelessWidget {
  final Widget header;
  final Widget inputCard;
  final String? error;

  const _InputSection({
    super.key,
    required this.header,
    required this.inputCard,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        header,
        const SizedBox(height: 16),
        if (error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RecommendationTokens.alertBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RecommendationTokens.alertSoft),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: RecommendationTokens.dangerDeep),
            ),
          ),
        if (error != null) const SizedBox(height: 12),
        inputCard,
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  final Widget header;
  final String? error;
  final String? warning;
  final bool occasionFallbackUsed;
  final bool loading;
  final Widget emptyState;
  final List<Widget> children;

  const _ResultsSection({
    super.key,
    required this.header,
    required this.error,
    required this.warning,
    required this.occasionFallbackUsed,
    required this.loading,
    required this.emptyState,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        header,
        const SizedBox(height: 16),
        if (error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RecommendationTokens.alertBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RecommendationTokens.alertSoft),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: RecommendationTokens.dangerDeep),
            ),
          ),
        if (error != null) const SizedBox(height: 12),
        if (occasionFallbackUsed)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RecommendationTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: RecommendationTokens.line,
              ),
            ),
            child: const Text(
              'Limited items matched your selected occasion, so these results include the best available alternatives.',
              style: TextStyle(
                color: RecommendationTokens.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (occasionFallbackUsed) const SizedBox(height: 12),
        if (warning != null && warning!.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RecommendationTokens.warning.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: RecommendationTokens.warning.withValues(alpha: 0.42),
              ),
            ),
            child: Text(
              warning!,
              style: const TextStyle(
                color: RecommendationTokens.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (warning != null && warning!.trim().isNotEmpty)
          const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (children.isEmpty)
          emptyState
        else
          ...children.expand((child) => [child, const SizedBox(height: 14)]),
        const SizedBox(height: 90),
      ],
    );
  }
}

class _OutfitCard extends StatelessWidget {
  final String label;
  final String title;
  final List<Widget> paletteDots;
  final Widget canvas;
  final bool isSaving;
  final bool isSaved;
  final bool isComparing;
  final VoidCallback onEdit;
  final VoidCallback? onSave;
  final VoidCallback onViewItems;
  final ValueChanged<_CardMenuAction> onMenuSelected;

  const _OutfitCard({
    required this.label,
    required this.title,
    required this.paletteDots,
    required this.canvas,
    required this.isSaving,
    required this.isSaved,
    required this.isComparing,
    required this.onEdit,
    required this.onSave,
    required this.onViewItems,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RecommendationTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RecommendationTokens.line),
        boxShadow: [
          BoxShadow(
            color: RecommendationTokens.black.withValues(alpha: 0.04),
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
                  color: RecommendationTokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: RecommendationTokens.slateSoft,
                  ),
                ),
              ),
              const Spacer(),
              Row(children: paletteDots),
              const SizedBox(width: 6),
              PopupMenuButton<_CardMenuAction>(
                onSelected: onMenuSelected,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _CardMenuAction.swap,
                    child: Text('Swap items'),
                  ),
                  PopupMenuItem(
                    value: _CardMenuAction.compare,
                    child: Text(
                      isComparing ? 'Remove from compare' : 'Add to compare',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CardMenuAction.why,
                    child: Text('Why this works'),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert,
                  color: RecommendationTokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          canvas,
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: RecommendationTokens.inkStrong,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                  filled: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: isSaved ? 'Saved' : 'Save outfit',
                  icon: isSaved
                      ? Icons.check_circle_outline
                      : Icons.bookmark_border,
                  onTap: onSave,
                  filled: true,
                  enabled: !isSaving,
                  success: isSaved,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'View items',
                  icon: Icons.list_alt_outlined,
                  onTap: onViewItems,
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareBar extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onCompare;

  const _CompareBar({required this.onClear, required this.onCompare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RecommendationTokens.inkStrong,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: RecommendationTokens.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, color: RecommendationTokens.surface),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Compare selected outfits',
              style: TextStyle(
                color: RecommendationTokens.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Clear')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onCompare,
            style: FilledButton.styleFrom(
              backgroundColor: RecommendationTokens.warning,
            ),
            child: const Text('Compare'),
          ),
        ],
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Pressable({required this.child, this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;
  final bool success;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    this.enabled = true,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = success
        ? RecommendationTokens.success
        : filled
        ? RecommendationTokens.inkStrong
        : RecommendationTokens.surface;
    final fg = filled
        ? RecommendationTokens.surface
        : RecommendationTokens.inkStrong;

    return _Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? bg : RecommendationTokens.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
