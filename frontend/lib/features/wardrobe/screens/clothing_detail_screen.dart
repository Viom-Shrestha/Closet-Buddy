import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ClothingDetailScreen — Luxury Dark Edition
// ─────────────────────────────────────────────────────────────────────────────

class ClothingDetailScreen extends StatefulWidget {
  final int clothingId;
  const ClothingDetailScreen({super.key, required this.clothingId});

  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

class _ClothingDetailScreenState extends State<ClothingDetailScreen>
    with TickerProviderStateMixin {
  final ClothingService _svc = ServiceRegistry.instance.clothingService;

  Map<String, dynamic>? item;
  bool loading = true;
  bool hasChanges = false;
  List<String> _categoryOptions = [];
  List<String> _occasionOptions = [];
  List<String> _temperatureOptions = [];
  List<String> _weatherOptions = [];

  static const List<String> _defaultTemperatureValues = [
    'freezing',
    'cold',
    'cool',
    'warm',
    'hot',
  ];
  static const List<String> _defaultWeatherValues = [
    'rainy',
    'snowy',
    'windy',
    'humid',
    'dry',
  ];
  static const String _shoeCategory = 'Shoes';

  static const List<String> _kCategoryValues = [
    'Topwear',
    'Outerwear',
    'Bottomwear',
    'Footwear',
    'Dress',
    'Accessories',
  ];

  static const List<String> _kOccasionValues = [
    'Casual',
    'Formal',
    'Office',
    'Party',
    'Date',
    'Traditional',
    'Sport',
    'Home',
    'Travel',
    'Beach',
    'Street',
    'Outdoor',
    'Workout',
  ];

  late AnimationController _enterCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _load();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _svc.getById(widget.clothingId);
    List<Map<String, dynamic>> allItems = [];
    try {
      allItems = await _svc.getAllClothes();
    } catch (_) {
      allItems = const [];
    }
    final isShoeItem = _looksLikeShoeMetadata(
      category: _safe(data?['category']),
      subcategory: _safe(data?['subcategory']),
    );
    if (mounted) {
      setState(() {
        item = data;
        if (isShoeItem) {
          _categoryOptions = const [_shoeCategory];
          _occasionOptions = _normalizeOptions([
            ..._kOccasionValues,
            _safe(data?['occasion']),
          ]);
          if (_safe(item?['category']).isEmpty ||
              _safe(item?['category']) != _shoeCategory) {
            item?['category'] = _shoeCategory;
          }
        } else {
          _categoryOptions = _normalizeOptions([
            ..._kCategoryValues,
            _safe(data?['category']),
          ]);
          _occasionOptions = _normalizeOptions([
            ..._kOccasionValues,
            _safe(data?['occasion']),
          ]);
        }
        _temperatureOptions = _collectOptions(
          allItems,
          'detected_temp',
          extras: [
            _safe(data?['detected_temp']),
            ..._defaultTemperatureValues,
          ],
        );
        _weatherOptions = _collectOptions(
          allItems,
          'detected_weather',
          extras: [
            _safe(data?['detected_weather']),
            ..._defaultWeatherValues,
          ],
        );
        loading = false;
      });
      _enterCtrl.forward();
    }
  }

  String _img(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    return s.startsWith('http') ? s : '${ApiClient.host}$s';
  }

  String _tc(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty || s == 'null') return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _date(dynamic raw) {
    final dt = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (dt == null) return '';
    const mo = [
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
    return '${mo[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  List<String> _attrs() {
    final raw = item?['attributes'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  String _safe(dynamic value) => (value ?? '').toString().trim();

  bool _looksLikeShoeMetadata({
    required String category,
    required String subcategory,
  }) {
    final blob = '$category $subcategory'.toLowerCase();
    const keys = [
      'shoe',
      'shoes',
      'sneaker',
      'boot',
      'heel',
      'footwear',
      'slipper',
      'sandal',
      'loafer',
      'flip flop',
    ];
    return keys.any(blob.contains);
  }

  List<String> _normalizeOptions(Iterable<String> rawValues) {
    final set = <String>{};
    for (final value in rawValues) {
      final clean = _safe(value);
      if (clean.isEmpty) continue;
      set.add(clean);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _collectOptions(
    List<Map<String, dynamic>> items,
    String field, {
    List<String> extras = const [],
  }) {
    final values = <String>[
      ...extras,
      ...items.map((entry) => _safe(entry[field])),
    ];
    return _normalizeOptions(values);
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _toggleFav() async {
    HapticFeedback.mediumImpact();
    final was = item!['is_favourite'] ?? false;
    setState(() => item!['is_favourite'] = !was);
    final ok = await _svc.toggleFavourite(item!['id']);
    if (!ok && mounted) {
      setState(() => item!['is_favourite'] = was);
      _toast('Could not update favourite', err: true);
    } else {
      hasChanges = true;
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: ClothingDetailTokens.black.withValues(alpha: 0.26),
      builder: (_) => _ConfirmDialog(
        title: 'Remove this item?',
        body: 'This action cannot be undone.',
        confirmLabel: 'Remove',
        confirmColor: ClothingDetailTokens.danger,
        confirmBg: ClothingDetailTokens.dangerBg,
      ),
    );
    if (ok != true) return;
    final deleted = await _svc.deleteClothing(item!['id']);
    if (deleted && mounted) Navigator.pop(context, true);
  }

  Future<void> _edit() async {
    final isShoeItem = _looksLikeShoeMetadata(
      category: _safe(item?['category']),
      subcategory: _safe(item?['subcategory']),
    );
    final ctrls = {
      'category': TextEditingController(
        text: isShoeItem ? _shoeCategory : item!['category'],
      ),
      'subcategory': TextEditingController(text: item!['subcategory']),
      'dominant_color': TextEditingController(text: item!['dominant_color']),
      'secondary_color': TextEditingController(text: item!['secondary_color']),
      'occasion': TextEditingController(text: item!['occasion']),
      'detected_temp': TextEditingController(text: item!['detected_temp']),
      'detected_weather': TextEditingController(text: item!['detected_weather']),
      'attributes': TextEditingController(text: _attrs().join(', ')),
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClothingDetailTokens.transparent,
      barrierColor: ClothingDetailTokens.black.withValues(alpha: 0.26),
      builder: (_) => _EditSheet(
        ctrls: ctrls,
        isShoe: isShoeItem,
        dropdownOptions: {
          'category': _categoryOptions,
          'occasion': _occasionOptions,
          'detected_temp': _temperatureOptions,
          'detected_weather': _weatherOptions,
        },
      ),
    );

    if (saved != true) return;

    if (isShoeItem) {
      ctrls['category']!.text = _shoeCategory;
    }
    final payload = {
      'is_shoe': isShoeItem,
      'category': ctrls['category']!.text.trim(),
      'subcategory': ctrls['subcategory']!.text.trim(),
      'dominant_color': ctrls['dominant_color']!.text.trim(),
      'secondary_color': ctrls['secondary_color']!.text.trim(),
      'occasion': ctrls['occasion']!.text.trim(),
      'detected_temp': ctrls['detected_temp']!.text.trim(),
      'detected_weather': ctrls['detected_weather']!.text.trim(),
      'attributes': ctrls['attributes']!.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    final ok = await _svc.updateClothing(item!['id'], payload);
    if (ok && mounted) {
      final refreshed = await _svc.getById(item!['id']);
      if (!mounted) return;
      setState(() {
        if (refreshed != null) {
          item = refreshed;
        } else {
          item!.addAll(payload);
        }
      });
      hasChanges = true;
      _toast('Changes saved');
    }
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  void _toast(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                err
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: err
                    ? ClothingDetailTokens.danger
                    : ClothingDetailTokens.success,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                msg,
                style: const TextStyle(
                  color: ClothingDetailTokens.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: ClothingDetailTokens.card,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: ClothingDetailTokens.border),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) return _LoadingScreen();
    if (item == null) return _MissingItemScreen(hasChanges: hasChanges);

    final isFav = item!['is_favourite'] == true;
    final attrs = _attrs();
    final temp = _tc(item!['detected_temp']);
    final weather = _tc(item!['detected_weather']);
    final domCol = _tc(item!['dominant_color']);
    final secCol = _tc(item!['secondary_color']);
    final glowCol = _colorFromName(domCol);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, hasChanges);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: ClothingDetailTokens.bg,
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Hero Image ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildHero(isFav, domCol, glowCol),
                    ),

                    // ── Title + Meta ───────────────────────────────────────
                    SliverToBoxAdapter(child: _buildTitleBlock()),

                    // ── Colors ─────────────────────────────────────────────
                    if (domCol.isNotEmpty || secCol.isNotEmpty)
                      SliverToBoxAdapter(child: _buildColors(domCol, secCol)),

                    // ── Conditions ─────────────────────────────────────────
                    if (temp.isNotEmpty || weather.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildConditions(temp, weather),
                      ),

                    // ── Details Card ───────────────────────────────────────
                    SliverToBoxAdapter(child: _buildDetailsCard(temp, weather)),

                    // ── Attributes ─────────────────────────────────────────
                    SliverToBoxAdapter(child: _buildAttributes(attrs)),

                    // ── Description ────────────────────────────────────────
                    SliverToBoxAdapter(child: _buildDescription()),

                    // ── Actions ────────────────────────────────────────────
                    SliverToBoxAdapter(child: _buildActions()),

                    const SliverToBoxAdapter(child: SizedBox(height: 56)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section builders ─────────────────────────────────────────────────────────

  Widget _buildHero(bool isFav, String domCol, Color glowCol) {
    return Container(
      color: ClothingDetailTokens.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient glow layer
          if (domCol.isNotEmpty)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0.2),
                    radius: 0.9,
                    colors: [
                      glowCol.withValues(alpha: 0.14),
                      ClothingDetailTokens.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // Image container
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 68,
              left: 32,
              right: 32,
              bottom: 36,
            ),
            child: Hero(
              tag: 'clothing_${item!['id']}',
              child: SizedBox(
                height: 290,
                child: Center(
                  child: Image.network(
                    _img(item!['image']),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 56,
                        color: ClothingDetailTokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16,
            child: _NavBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context, hasChanges),
            ),
          ),

          // Favourite button
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 16,
            child: _NavBtn(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: isFav
                  ? ClothingDetailTokens.danger
                  : ClothingDetailTokens.textMuted,
              accentColor: isFav ? ClothingDetailTokens.danger : null,
              onTap: _toggleFav,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock() {
    final category = _tc(item!['category']);
    final subcategory = _tc(item!['subcategory']);
    final occasion = _tc(item!['occasion']);
    final dateStr = _date(item!['created_at']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty)
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: ClothingDetailTokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ClothingDetailTokens.accent,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  subcategory.isNotEmpty
                      ? subcategory
                      : category.isNotEmpty
                      ? category
                      : 'Clothing Item',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: ClothingDetailTokens.text,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
              ),
              if (occasion.isNotEmpty) ...[
                const SizedBox(width: 12),
                _OccasionBadge(occasion),
              ],
            ],
          ),
          if (dateStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: ClothingDetailTokens.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Added $dateStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ClothingDetailTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColors(String domCol, String secCol) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          if (domCol.isNotEmpty)
            Expanded(
              child: _ColorBadge(label: 'Primary', name: domCol),
            ),
          if (domCol.isNotEmpty && secCol.isNotEmpty) const SizedBox(width: 10),
          if (secCol.isNotEmpty)
            Expanded(
              child: _ColorBadge(label: 'Secondary', name: secCol),
            ),
        ],
      ),
    );
  }

  Widget _buildConditions(String temp, String weather) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          if (temp.isNotEmpty)
            Expanded(
              child: _ConditionChip(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                value: temp,
                color: ClothingDetailTokens.info,
              ),
            ),
          if (temp.isNotEmpty && weather.isNotEmpty) const SizedBox(width: 10),
          if (weather.isNotEmpty)
            Expanded(
              child: _ConditionChip(
                icon: Icons.wb_cloudy_rounded,
                label: 'Weather',
                value: weather,
                color: ClothingDetailTokens.success,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(String temp, String weather) {
    final dom = _tc(item!['dominant_color']);
    final sec = _tc(item!['secondary_color']);
    final storageRaw = item!['storage_unit'];
    final storageName = storageRaw is Map ? _tc(storageRaw['name']) : '';
    final added = _date(item!['created_at']);
    final rows = <Map<String, String>>[
      {'label': 'Category', 'value': _tc(item!['category'])},
      {'label': 'Subcategory', 'value': _tc(item!['subcategory'])},
      {'label': 'Occasion', 'value': _tc(item!['occasion'])},
      {'label': 'Primary Color', 'value': dom},
      {'label': 'Secondary Color', 'value': sec},
      {'label': 'Temperature', 'value': temp},
      {'label': 'Weather', 'value': weather},
      {'label': 'Storage', 'value': storageName},
      {'label': 'Added', 'value': added},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Details'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ClothingDetailTokens.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClothingDetailTokens.border),
            ),
            child: Column(
              children: rows
                  .asMap()
                  .entries
                  .map(
                    (entry) => _InfoRow(
                      label: entry.value['label'] ?? '',
                      value: entry.value['value'] ?? '',
                      isLast: entry.key == rows.length - 1,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributes(List<String> attrs) {
    final tags = attrs.map(_tc).where((entry) => entry.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Attributes'),
          const SizedBox(height: 12),
          if (tags.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClothingDetailTokens.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClothingDetailTokens.border),
              ),
              child: const Text(
                'No tags yet. Edit this item to add style attributes.',
                style: TextStyle(
                  fontSize: 13,
                  color: ClothingDetailTokens.textMuted,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => _AttrTag(tag)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final cat = _tc(item!['category']);
    final sub = _tc(item!['subcategory']);
    final dom = _tc(item!['dominant_color']);
    final sec = _tc(item!['secondary_color']);
    final occ = _tc(item!['occasion']);
    final tmp = _tc(item!['detected_temp']);
    final wth = _tc(item!['detected_weather']);
    final atrs = _attrs().map(_tc).where((entry) => entry.isNotEmpty).toList();
    final storageRaw = item!['storage_unit'];
    final storageName = storageRaw is Map ? _tc(storageRaw['name']) : '';
    final title = sub.isNotEmpty
        ? sub
        : cat.isNotEmpty
        ? cat
        : 'Clothing Item';
    final palette = dom.isNotEmpty
        ? sec.isNotEmpty
              ? '$dom with $sec accents'
              : dom
        : 'Unspecified palette';
    final metaRows = <Map<String, String>>[
      {'label': 'Best for', 'value': occ},
      {'label': 'Temperature', 'value': tmp},
      {'label': 'Weather', 'value': wth},
      {'label': 'Stored in', 'value': storageName},
      {'label': 'Tags', 'value': atrs.isEmpty ? 'No tags yet' : atrs.join(', ')},
    ].where((row) => (row['value'] ?? '').isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('About'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ClothingDetailTokens.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClothingDetailTokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ClothingDetailTokens.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  palette,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ClothingDetailTokens.textMuted,
                  ),
                ),
                if (metaRows.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...metaRows.asMap().entries.map(
                    (entry) => _buildAboutRow(
                      entry.value['label'] ?? '',
                      entry.value['value'] ?? '',
                      isLast: entry.key == metaRows.length - 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ClothingDetailTokens.border,
                  width: 1,
                ),
              ),
            ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ClothingDetailTokens.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ClothingDetailTokens.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Edit Item',
              icon: Icons.edit_rounded,
              onTap: _edit,
              primary: true,
            ),
          ),
          const SizedBox(width: 12),
          _ActionButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onTap: _delete,
            primary: false,
            fixedWidth: 112,
          ),
        ],
      ),
    );
  }

  static Color _colorFromName(String name) {
    final match = matchNamedColor(NamedColors.material, name);
    return match ?? ClothingDetailTokens.accent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Loading screen
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ClothingDetailTokens.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: ClothingDetailTokens.accent,
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading',
              style: TextStyle(
                fontSize: 13,
                color: ClothingDetailTokens.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingItemScreen extends StatelessWidget {
  final bool hasChanges;

  const _MissingItemScreen({required this.hasChanges});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClothingDetailTokens.bg,
      appBar: AppBar(
        backgroundColor: ClothingDetailTokens.surface,
        foregroundColor: ClothingDetailTokens.text,
        title: const Text('Item unavailable'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context, hasChanges),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This clothing item could not be loaded. It may have been removed or is temporarily unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ClothingDetailTokens.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: ClothingDetailTokens.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: ClothingDetailTokens.textMuted,
          letterSpacing: 1.8,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Nav button
// ─────────────────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? accentColor;

  const _NavBtn({
    required this.icon,
    required this.onTap,
    this.iconColor = ClothingDetailTokens.textSub,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ClothingDetailTokens.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor != null
              ? accentColor!.withValues(alpha: 0.4)
              : ClothingDetailTokens.border,
        ),
        boxShadow: [
          BoxShadow(
            color: ClothingDetailTokens.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 19, color: iconColor),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Occasion badge
// ─────────────────────────────────────────────────────────────────────────────

class _OccasionBadge extends StatelessWidget {
  final String label;
  const _OccasionBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [ClothingDetailTokens.accentDeep, ClothingDetailTokens.accent],
      ),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: ClothingDetailTokens.accentDeep.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: ClothingDetailTokens.white,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Color badge
// ─────────────────────────────────────────────────────────────────────────────

class _ColorBadge extends StatelessWidget {
  final String label;
  final String name;
  const _ColorBadge({required this.label, required this.name});

  @override
  Widget build(BuildContext context) {
    final color = _ClothingDetailScreenState._colorFromName(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ClothingDetailTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ClothingDetailTokens.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ClothingDetailTokens.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Condition chip
// ─────────────────────────────────────────────────────────────────────────────

class _ConditionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ConditionChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ClothingDetailTokens.text,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Info row
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ClothingDetailTokens.border,
                  width: 1,
                ),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: ClothingDetailTokens.textSub,
              ),
            ),
          ),
          Text(
            empty ? 'Not set' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: empty
                  ? ClothingDetailTokens.textMuted
                  : ClothingDetailTokens.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Attribute tag
// ─────────────────────────────────────────────────────────────────────────────

class _AttrTag extends StatelessWidget {
  final String label;
  const _AttrTag(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: ClothingDetailTokens.card,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: ClothingDetailTokens.borderBright),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ClothingDetailTokens.textSub,
        letterSpacing: 0.2,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final double? fixedWidth;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
    this.fixedWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? const LinearGradient(
            colors: [
              ClothingDetailTokens.accentDeep,
              ClothingDetailTokens.accent,
            ],
          )
        : LinearGradient(
            colors: [
              ClothingDetailTokens.dangerBg,
              ClothingDetailTokens.dangerBg,
            ],
          );

    final fg = primary ? ClothingDetailTokens.white : ClothingDetailTokens.danger;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fixedWidth,
        height: 54,
        decoration: BoxDecoration(
          gradient: bg,
          borderRadius: BorderRadius.circular(16),
          border: primary
              ? null
              : Border.all(
                  color: ClothingDetailTokens.danger.withValues(alpha: 0.3),
                ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: ClothingDetailTokens.accentDeep.withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Confirm dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  final Color confirmBg;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
    required this.confirmBg,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: ClothingDetailTokens.card,
    surfaceTintColor: ClothingDetailTokens.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: ClothingDetailTokens.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: confirmBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: confirmColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ClothingDetailTokens.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: ClothingDetailTokens.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ClothingDetailTokens.surfaceStrong,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ClothingDetailTokens.border),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ClothingDetailTokens.textSub,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: confirmBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: confirmColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: confirmColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditSheet extends StatelessWidget {
  final Map<String, TextEditingController> ctrls;
  final Map<String, List<String>> dropdownOptions;
  final bool isShoe;
  const _EditSheet({
    required this.ctrls,
    required this.dropdownOptions,
    this.isShoe = false,
  });

  static const _labels = <String, String>{
    'category': 'Category',
    'subcategory': 'Subcategory',
    'dominant_color': 'Primary Color',
    'secondary_color': 'Secondary Color',
    'occasion': 'Occasion',
    'detected_temp': 'Temperature',
    'detected_weather': 'Weather',
    'attributes': 'Attributes (comma-separated)',
  };

  String _safe(dynamic value) => (value ?? '').toString().trim();

  String _humanize(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (normalized.isEmpty) return '';
    return normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
  }

  List<String> _dropdownValues(String key) {
    final values = <String>{
      ...?dropdownOptions[key]?.map(_safe).where((entry) => entry.isNotEmpty),
      _safe(ctrls[key]?.text),
    }..remove('');

    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  InputDecoration _inputDecoration(String key) {
    return InputDecoration(
      labelText: _labels[key] ?? key,
      labelStyle: const TextStyle(
        fontSize: 14,
        color: ClothingDetailTokens.textMuted,
      ),
      filled: true,
      fillColor: ClothingDetailTokens.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ClothingDetailTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ClothingDetailTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: ClothingDetailTokens.accent,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  Widget _buildTextInput(String key) {
    final controller = ctrls[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15,
          color: ClothingDetailTokens.text,
          fontWeight: FontWeight.w500,
        ),
        decoration: _inputDecoration(key),
      ),
    );
  }

  Widget _buildDropdownInput(String key) {
    final controller = ctrls[key]!;
    final options = _dropdownValues(key);
    final current = _safe(controller.text);
    final selected = options.contains(current)
        ? current
        : (options.isNotEmpty ? options.first : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>('${key}_$selected'),
        initialValue: selected,
        isExpanded: true,
        style: const TextStyle(
          fontSize: 15,
          color: ClothingDetailTokens.text,
          fontWeight: FontWeight.w500,
        ),
        decoration: _inputDecoration(key),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  _humanize(option),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          controller.text = value ?? '';
        },
      ),
    );
  }

  Widget _buildLockedCategoryInput() {
    final controller = ctrls['category']!;
    controller.text = 'Shoes';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: true,
        enableInteractiveSelection: false,
        style: const TextStyle(
          fontSize: 15,
          color: ClothingDetailTokens.text,
          fontWeight: FontWeight.w600,
        ),
        decoration: _inputDecoration('category').copyWith(
          helperText: 'Shoes category is locked for shoe items.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: ClothingDetailTokens.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(top: BorderSide(color: ClothingDetailTokens.border)),
    ),
    padding: EdgeInsets.fromLTRB(
      24,
      14,
      24,
      MediaQuery.of(context).viewInsets.bottom + 32,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: ClothingDetailTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Edit Item',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: ClothingDetailTokens.text,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Adjust the details detected by AI',
            style: TextStyle(
              fontSize: 13,
              color: ClothingDetailTokens.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          isShoe ? _buildLockedCategoryInput() : _buildDropdownInput('category'),
          _buildTextInput('subcategory'),
          _buildTextInput('dominant_color'),
          _buildTextInput('secondary_color'),
          _buildDropdownInput('occasion'),
          _buildDropdownInput('detected_temp'),
          _buildDropdownInput('detected_weather'),
          _buildTextInput('attributes'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              width: double.infinity,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    ClothingDetailTokens.accentDeep,
                    ClothingDetailTokens.accent,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ClothingDetailTokens.accentDeep.withValues(
                      alpha: 0.4,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ClothingDetailTokens.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

