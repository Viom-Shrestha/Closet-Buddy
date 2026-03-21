import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/clothing_service.dart';
import '../services/api_client.dart';

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
  final ClothingService _svc = ClothingService();

  Map<String, dynamic>? item;
  bool loading = true;
  bool hasChanges = false;

  late AnimationController _enterCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  // ── Design Tokens ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF7F5F2); // warm off-white
  static const _surface = Color(0xFFFCFAF7); // elevated surface
  static const _surface2 = Colors.white; // card surface
  static const _surface3 = Color(0xFFF1EDE6); // deeper card
  static const _border = Color(0xFFE8E3DB); // subtle border
  static const _borderBright = Color(0xFFDED6C8); // highlighted border
  static const _text = Color(0xFF0F0F0F); // primary text
  static const _textSub = Color(0xFF6B7280); // secondary text
  static const _textMuted = Color(0xFF9A8F7F); // muted text
  static const _accent = Color(0xFFC9A96E); // warm accent
  static const _accentDeep = Color(0xFFB5854D); // deeper accent
  static const _danger = Color(0xFFDC2626); // soft red
  static const _dangerBg = Color(0xFFFDECEC);
  static const _success = Color(0xFF16A34A); // green

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
    if (mounted) {
      setState(() {
        item = data;
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
    if (raw is List)
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return [];
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
      barrierColor: Colors.black26,
      builder: (_) => _ConfirmDialog(
        title: 'Remove this item?',
        body: 'This action cannot be undone.',
        confirmLabel: 'Remove',
        confirmColor: _danger,
        confirmBg: _dangerBg,
      ),
    );
    if (ok != true) return;
    final deleted = await _svc.deleteClothing(item!['id']);
    if (deleted && mounted) Navigator.pop(context, true);
  }

  Future<void> _edit() async {
    final ctrls = {
      'category': TextEditingController(text: item!['category']),
      'subcategory': TextEditingController(text: item!['subcategory']),
      'dominant_color': TextEditingController(text: item!['dominant_color']),
      'secondary_color': TextEditingController(text: item!['secondary_color']),
      'occasion': TextEditingController(text: item!['occasion']),
      'attributes': TextEditingController(text: _attrs().join(', ')),
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => _EditSheet(ctrls: ctrls),
    );

    if (saved != true) return;

    final payload = {
      'category': ctrls['category']!.text,
      'subcategory': ctrls['subcategory']!.text,
      'dominant_color': ctrls['dominant_color']!.text,
      'secondary_color': ctrls['secondary_color']!.text,
      'occasion': ctrls['occasion']!.text,
      'attributes': ctrls['attributes']!.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    final ok = await _svc.updateClothing(item!['id'], payload);
    if (ok && mounted) {
      setState(() => item!.addAll(payload));
      hasChanges = true;
      _toast('Changes saved');
    }
    for (final c in ctrls.values) c.dispose();
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
                color: err ? _danger : _success,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                msg,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: _surface2,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _border),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) return _LoadingScreen();

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
          backgroundColor: _bg,
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
                    if (attrs.isNotEmpty)
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
      color: _surface,
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
                    colors: [glowCol.withOpacity(0.14), Colors.transparent],
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
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 56,
                        color: _textMuted,
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
              iconColor: isFav ? _danger : _textMuted,
              accentColor: isFav ? _danger : null,
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
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
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
                    color: _text,
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
                    color: _textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Added $dateStr',
                    style: const TextStyle(fontSize: 12, color: _textMuted),
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
                color: const Color(0xFF60A5FA),
              ),
            ),
          if (temp.isNotEmpty && weather.isNotEmpty) const SizedBox(width: 10),
          if (weather.isNotEmpty)
            Expanded(
              child: _ConditionChip(
                icon: Icons.wb_cloudy_rounded,
                label: 'Weather',
                value: weather,
                color: _success,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(String temp, String weather) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Details'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Category', value: _tc(item!['category'])),
                _InfoRow(
                  label: 'Subcategory',
                  value: _tc(item!['subcategory']),
                ),
                _InfoRow(label: 'Occasion', value: _tc(item!['occasion'])),
                _InfoRow(label: 'Temperature', value: temp),
                _InfoRow(label: 'Weather', value: weather, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributes(List<String> attrs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Attributes'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attrs.map((a) => _AttrTag(a)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final parts = <String>[];
    final cat = _tc(item!['category']);
    final sub = _tc(item!['subcategory']);
    final dom = _tc(item!['dominant_color']);
    final sec = _tc(item!['secondary_color']);
    final occ = _tc(item!['occasion']);
    final tmp = _tc(item!['detected_temp']);
    final wth = _tc(item!['detected_weather']);
    final atrs = _attrs();

    if (sub.isNotEmpty || cat.isNotEmpty)
      parts.add([sub, cat].where((e) => e.isNotEmpty).first);
    if (dom.isNotEmpty)
      parts.add(sec.isNotEmpty ? 'Colors: $dom & $sec' : 'Color: $dom');
    if (occ.isNotEmpty) parts.add('Occasion: $occ');
    if (tmp.isNotEmpty) parts.add('Temperature: $tmp');
    if (wth.isNotEmpty) parts.add('Weather: $wth');
    if (atrs.isNotEmpty) parts.add('Tags: ${atrs.join(', ')}');

    final desc = parts.isEmpty
        ? 'No description available.'
        : parts.join(' · ');

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
              color: _surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Text(
              desc,
              style: const TextStyle(
                fontSize: 14,
                color: _textSub,
                height: 1.8,
                letterSpacing: 0.1,
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
    final n = name.toLowerCase();
    const m = {
      'red': Color(0xFFEF4444),
      'blue': Color(0xFF3B82F6),
      'green': Color(0xFF22C55E),
      'yellow': Color(0xFFFACC15),
      'orange': Color(0xFFF97316),
      'purple': Color(0xFFA855F7),
      'pink': Color(0xFFEC4899),
      'brown': Color(0xFF92400E),
      'black': Color(0xFF6B7280),
      'white': Color(0xFFD1D5DB),
      'grey': Color(0xFF9CA3AF),
      'gray': Color(0xFF9CA3AF),
      'beige': Color(0xFFD4B896),
      'navy': Color(0xFF1E3A8A),
      'teal': Color(0xFF14B8A6),
      'maroon': Color(0xFF9B1C1C),
      'olive': Color(0xFF6B7280),
      'cream': Color(0xFFD4C5A9),
      'khaki': Color(0xFFC2B280),
      'indigo': Color(0xFF6366F1),
    };
    for (final e in m.entries) {
      if (n.contains(e.key)) return e.value;
    }
    return _accent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Loading screen
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _ClothingDetailScreenState._bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: _ClothingDetailScreenState._accent,
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading',
              style: TextStyle(
                fontSize: 13,
                color: _ClothingDetailScreenState._textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
          color: _ClothingDetailScreenState._accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _ClothingDetailScreenState._textMuted,
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
    this.iconColor = _ClothingDetailScreenState._textSub,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _ClothingDetailScreenState._surface2,
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor != null
              ? accentColor!.withOpacity(0.4)
              : _ClothingDetailScreenState._border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
        colors: [
          _ClothingDetailScreenState._accentDeep,
          _ClothingDetailScreenState._accent,
        ],
      ),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: _ClothingDetailScreenState._accentDeep.withOpacity(0.4),
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
        color: Colors.white,
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
        color: _ClothingDetailScreenState._surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
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
                  color: color.withOpacity(0.5),
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
                    color: _ClothingDetailScreenState._textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ClothingDetailScreenState._text,
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
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.2), width: 1.5),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
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
                color: color.withOpacity(0.7),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ClothingDetailScreenState._text,
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
                  color: _ClothingDetailScreenState._border,
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
                color: _ClothingDetailScreenState._textSub,
              ),
            ),
          ),
          Text(
            empty ? '—' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: empty
                  ? _ClothingDetailScreenState._textMuted
                  : _ClothingDetailScreenState._text,
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
      color: _ClothingDetailScreenState._surface2,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: _ClothingDetailScreenState._borderBright),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _ClothingDetailScreenState._textSub,
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
              _ClothingDetailScreenState._accentDeep,
              _ClothingDetailScreenState._accent,
            ],
          )
        : LinearGradient(
            colors: [
              _ClothingDetailScreenState._dangerBg,
              _ClothingDetailScreenState._dangerBg,
            ],
          );

    final fg = primary ? Colors.white : _ClothingDetailScreenState._danger;

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
                  color: _ClothingDetailScreenState._danger.withOpacity(0.3),
                ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: _ClothingDetailScreenState._accentDeep.withOpacity(
                      0.35,
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
    backgroundColor: _ClothingDetailScreenState._surface2,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: _ClothingDetailScreenState._border),
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
              color: _ClothingDetailScreenState._text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: _ClothingDetailScreenState._textMuted,
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
                      color: _ClothingDetailScreenState._surface3,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _ClothingDetailScreenState._border,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ClothingDetailScreenState._textSub,
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
                      border: Border.all(color: confirmColor.withOpacity(0.3)),
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
  const _EditSheet({required this.ctrls});

  static const _labels = <String, String>{
    'category': 'Category',
    'subcategory': 'Subcategory',
    'dominant_color': 'Primary Color',
    'secondary_color': 'Secondary Color',
    'occasion': 'Occasion',
    'attributes': 'Attributes (comma-separated)',
  };

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _ClothingDetailScreenState._surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(
        top: BorderSide(color: _ClothingDetailScreenState._border),
      ),
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
                color: _ClothingDetailScreenState._border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Edit Item',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _ClothingDetailScreenState._text,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Adjust the details detected by AI',
            style: TextStyle(
              fontSize: 13,
              color: _ClothingDetailScreenState._textMuted,
            ),
          ),
          const SizedBox(height: 24),
          ...ctrls.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: e.value,
                style: const TextStyle(
                  fontSize: 15,
                  color: _ClothingDetailScreenState._text,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: _labels[e.key] ?? e.key,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    color: _ClothingDetailScreenState._textMuted,
                  ),
                  filled: true,
                  fillColor: _ClothingDetailScreenState._surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _ClothingDetailScreenState._border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _ClothingDetailScreenState._border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _ClothingDetailScreenState._accent,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
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
                    _ClothingDetailScreenState._accentDeep,
                    _ClothingDetailScreenState._accent,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _ClothingDetailScreenState._accentDeep.withOpacity(
                      0.4,
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
                  color: Colors.white,
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
