import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/clothing_service.dart';
import '../services/api_client.dart';

class ClothingDetailScreen extends StatefulWidget {
  final int clothingId;

  const ClothingDetailScreen({super.key, required this.clothingId});

  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

class _ClothingDetailScreenState extends State<ClothingDetailScreen>
    with SingleTickerProviderStateMixin {
  final ClothingService clothingService = ClothingService();

  Map<String, dynamic>? item;
  bool loading = true;
  bool hasChanges = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF7F7F8);
  static const _white = Color(0xFFFFFFFF);
  static const _text = Color(0xFF111111);
  static const _textSub = Color(0xFF555555);
  static const _textMuted = Color(0xFF999999);
  static const _border = Color(0xFFE8E8E8);
  static const _chip = Color(0xFFF0F0F0);
  static const _accent = Color(0xFF2563EB);
  static const _accentSoft = Color(0xFFEFF4FF);
  static const _danger = Color(0xFFDC2626);
  static const _dangerSoft = Color(0xFFFEF2F2);
  static const _favOn = Color(0xFFE53E3E);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadItem();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    final data = await clothingService.getById(widget.clothingId);
    if (mounted) {
      setState(() {
        item = data;
        loading = false;
      });
      _animController.forward();
    }
  }

  String _img(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (s.startsWith('http')) return s;
    return '${ApiClient.host}$s';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleFavourite() async {
    HapticFeedback.lightImpact();
    final old = item!['is_favourite'] ?? false;
    setState(() => item!['is_favourite'] = !old);
    final ok = await clothingService.toggleFavourite(item!['id']);
    if (!ok && mounted) {
      setState(() => item!['is_favourite'] = old);
      _toast('Failed to update favourite', error: true);
    } else {
      hasChanges = true;
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete item?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: _textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSub, fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await clothingService.deleteClothing(item!['id']);
    if (ok && mounted) Navigator.pop(context, true);
  }

  Future<void> _edit() async {
    final c = TextEditingController(text: item!['category']);
    final sc = TextEditingController(text: item!['subcategory']);
    final dc = TextEditingController(text: item!['dominant_color']);
    final sec = TextEditingController(text: item!['secondary_color']);
    final occ = TextEditingController(text: item!['occasion']);
    final attrs = TextEditingController(text: _attributesFromItem().join(', '));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBottomSheet(
        controllers: [c, sc, dc, sec, occ, attrs],
        labels: [
          'Category',
          'Subcategory',
          'Primary Color',
          'Secondary Color',
          'Occasion',
          'Attributes (comma-separated)',
        ],
      ),
    );

    if (saved != true) return;

    final payload = {
      'category': c.text,
      'subcategory': sc.text,
      'dominant_color': dc.text,
      'secondary_color': sec.text,
      'occasion': occ.text,
      'attributes': _splitAttributes(attrs.text),
    };

    final ok = await clothingService.updateClothing(item!['id'], payload);
    if (ok && mounted) {
      setState(() => item!.addAll(payload));
      hasChanges = true;
      _toast('Changes saved');
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: error ? _danger : _text,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final isFav = item!['is_favourite'] == true;

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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero image + nav ────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 340,
                  pinned: true,
                  backgroundColor: _white,
                  elevation: 0,
                  shadowColor: Colors.black12,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: _border),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: Stack(
                      children: [
                        // White background
                        const Positioned.fill(child: ColoredBox(color: _white)),

                        // Item image — full, unobstructed
                        Positioned(
                          left: 0,
                          right: 0,
                          top: MediaQuery.of(context).padding.top + 56,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                            child: Hero(
                              tag: 'clothing_${item!['id']}',
                              child: Image.network(
                                _img(item!['image']),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        // Nav bar — back + favourite
                        Positioned(
                          top: MediaQuery.of(context).padding.top,
                          left: 0,
                          right: 0,
                          height: 56,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _NavBtn(
                                  icon: Icons.arrow_back_rounded,
                                  onTap: () =>
                                      Navigator.pop(context, hasChanges),
                                ),
                                _NavBtn(
                                  icon: isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  iconColor: isFav ? _favOn : _textSub,
                                  onTap: _toggleFavourite,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Body content ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + occasion badge
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayName(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _text,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  if (_subName().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        _subName(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: _textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if ((item!['occasion'] ?? '').toString().isNotEmpty)
                              _Badge(_titleCase(item!['occasion'])),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Details card
                      _Card(
                        child: Column(
                          children: [
                            _Row(
                              icon: Icons.category_outlined,
                              label: 'Category',
                              value: item!['category'],
                            ),
                            _Row(
                              icon: Icons.style_outlined,
                              label: 'Subcategory',
                              value: item!['subcategory'],
                            ),
                            _Row(
                              icon: Icons.palette_outlined,
                              label: 'Primary Color',
                              value: item!['dominant_color'],
                              colorDot: true,
                            ),
                            _Row(
                              icon: Icons.color_lens_outlined,
                              label: 'Secondary Color',
                              value: item!['secondary_color'],
                              colorDot: true,
                            ),
                            _Row(
                              icon: Icons.event_outlined,
                              label: 'Occasion',
                              value: item!['occasion'],
                            ),
                            _Row(
                              icon: Icons.thermostat_outlined,
                              label: 'Temperature',
                              value: _titleCase(item!['detected_temp']),
                            ),
                            _Row(
                              icon: Icons.wb_cloudy_outlined,
                              label: 'Weather',
                              value: _titleCase(item!['detected_weather']),
                            ),
                            _Row(
                              icon: Icons.calendar_today_outlined,
                              label: 'Added',
                              value: _formatDate(item!['created_at']),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),

                      // Attributes
                      if (_attributesFromItem().isNotEmpty) ...[
                        _SectionHeader('Attributes'),
                        _Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _attributesFromItem()
                                  .map((a) => _AttrChip(a))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],

                      // Description
                      _SectionHeader('Description'),
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _generatedDescription(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: _textSub,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionBtn(
                                label: 'Edit Item',
                                icon: Icons.edit_outlined,
                                onTap: _edit,
                                bg: _accentSoft,
                                textColor: _accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionBtn(
                                label: 'Delete',
                                icon: Icons.delete_outline_rounded,
                                onTap: _delete,
                                bg: _dangerSoft,
                                textColor: _danger,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _displayName() {
    final cat = (item!['category'] ?? '').toString().trim();
    if (cat.isNotEmpty) return _titleCase(cat);
    final sub = (item!['subcategory'] ?? '').toString().trim();
    if (sub.isNotEmpty) return _titleCase(sub);
    return 'Clothing Item';
  }

  String _subName() {
    final cat = (item!['category'] ?? '').toString().trim();
    final sub = (item!['subcategory'] ?? '').toString().trim();
    if (cat.isNotEmpty && sub.isNotEmpty) return _titleCase(sub);
    return '';
  }

  String _titleCase(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '-';
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return '-';
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  List<String> _attributesFromItem() {
    final raw = item?['attributes'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  List<String> _splitAttributes(String value) =>
      value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  String _generatedDescription() {
    final cat = (item?['category'] ?? '').toString().trim();
    final sub = (item?['subcategory'] ?? '').toString().trim();
    final dom = (item?['dominant_color'] ?? '').toString().trim();
    final sec = (item?['secondary_color'] ?? '').toString().trim();
    final occ = (item?['occasion'] ?? '').toString().trim();
    final temp = (item?['detected_temp'] ?? '').toString().trim();
    final weather = (item?['detected_weather'] ?? '').toString().trim();
    final attrs = _attributesFromItem();

    final parts = <String>[];
    if (cat.isNotEmpty || sub.isNotEmpty) {
      parts.add(_titleCase([cat, sub].where((e) => e.isNotEmpty).join(' / ')));
    }
    if (dom.isNotEmpty) parts.add('Primary color: $dom');
    if (sec.isNotEmpty) parts.add('Secondary color: $sec');
    if (occ.isNotEmpty) parts.add('Occasion: $occ');
    if (temp.isNotEmpty && temp != 'null') {
      parts.add('Temperature fit: ${_titleCase(temp)}');
    }
    if (weather.isNotEmpty && weather != 'null') {
      parts.add('Weather: ${_titleCase(weather)}');
    }
    if (attrs.isNotEmpty) parts.add('Attributes: ${attrs.join(', ')}');

    return parts.isEmpty ? 'No description available.' : '${parts.join('. ')}.';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _NavBtn({
    required this.icon,
    required this.onTap,
    this.iconColor = _ClothingDetailScreenState._textSub,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _ClothingDetailScreenState._white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: iconColor),
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    decoration: BoxDecoration(
      color: _ClothingDetailScreenState._white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _ClothingDetailScreenState._border),
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _ClothingDetailScreenState._textMuted,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final bool colorDot;
  final bool isLast;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.colorDot = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final val = (value ?? '').toString().trim();
    final isEmpty = val.isEmpty || val == '-' || val == 'null';
    final display = isEmpty ? '—' : val;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Icon(icon, size: 18, color: _ClothingDetailScreenState._textMuted),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _ClothingDetailScreenState._textSub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (colorDot && !isEmpty) ...[
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _colorFromName(display),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ClothingDetailScreenState._border,
                      ),
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    display,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isEmpty
                          ? _ClothingDetailScreenState._textMuted
                          : _ClothingDetailScreenState._text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorFromName(String name) {
    final n = name.toLowerCase();
    const map = {
      'red': Color(0xFFEF4444),
      'blue': Color(0xFF3B82F6),
      'green': Color(0xFF22C55E),
      'yellow': Color(0xFFFACC15),
      'orange': Color(0xFFF97316),
      'purple': Color(0xFFA855F7),
      'pink': Color(0xFFEC4899),
      'brown': Color(0xFF92400E),
      'black': Color(0xFF111827),
      'white': Color(0xFFF9FAFB),
      'grey': Color(0xFF9CA3AF),
      'gray': Color(0xFF9CA3AF),
      'beige': Color(0xFFF5F5DC),
      'navy': Color(0xFF1E3A8A),
      'maroon': Color(0xFF9B1C1C),
      'olive': Color(0xFF6B7280),
      'teal': Color(0xFF14B8A6),
      'cyan': Color(0xFF06B6D4),
      'lime': Color(0xFF84CC16),
      'indigo': Color(0xFF6366F1),
      'cream': Color(0xFFFFFBEB),
      'khaki': Color(0xFFC2B280),
    };
    for (final e in map.entries) {
      if (n.contains(e.key)) return e.value;
    }
    return const Color(0xFFD1D5DB);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _ClothingDetailScreenState._accentSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _ClothingDetailScreenState._accent,
      ),
    ),
  );
}

class _AttrChip extends StatelessWidget {
  final String label;
  const _AttrChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: _ClothingDetailScreenState._chip,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _ClothingDetailScreenState._text,
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color textColor;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Edit Bottom Sheet ─────────────────────────────────────────────────────────

class _EditBottomSheet extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<String> labels;

  const _EditBottomSheet({required this.controllers, required this.labels});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _ClothingDetailScreenState._white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: EdgeInsets.fromLTRB(
      24,
      16,
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _ClothingDetailScreenState._border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Edit Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ClothingDetailScreenState._text,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            controllers.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: controllers[i],
                style: const TextStyle(
                  fontSize: 15,
                  color: _ClothingDetailScreenState._text,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: labels[i],
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    color: _ClothingDetailScreenState._textMuted,
                  ),
                  filled: true,
                  fillColor: _ClothingDetailScreenState._bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _ClothingDetailScreenState._border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _ClothingDetailScreenState._border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _ClothingDetailScreenState._accent,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _ClothingDetailScreenState._accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
