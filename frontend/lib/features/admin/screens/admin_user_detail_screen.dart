import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:frontend/services/admin_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/theme/app_theme.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final int userId;
  final String username;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = ServiceRegistry.instance.adminService;

  bool _loading = true;
  bool _hasError = false;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _clothing = [];
  List<Map<String, dynamic>> _outfits = [];

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final summaryFut = _adminService.fetchUserSummary(widget.userId);
      final clothingFut = _adminService.fetchUserClothing(
        userId: widget.userId,
      );
      final outfitsFut = _adminService.fetchUserOutfits(userId: widget.userId);
      final summary = await summaryFut;
      final clothing = await clothingFut;
      final outfits = await outfitsFut;
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _clothing = List<Map<String, dynamic>>.from(clothing['results'] ?? []);
        _outfits = List<Map<String, dynamic>>.from(outfits['results'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  // Ensure image URL is always absolute
  static String _absUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    if (s.startsWith('/')) return '${ApiClient.host}$s';
    return '${ApiClient.host}/$s';
  }

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBg,
      appBar: AppBar(
        backgroundColor: kAdminSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: kAdminTextMuted,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.username,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: kAdminText,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: kAdminTextMuted,
            ),
            onPressed: _loadAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kAdminBorder),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: kAdminAccent,
                strokeWidth: 2,
              ),
            )
          : _hasError || _summary == null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 44, color: kAdminTextDim),
        const SizedBox(height: 12),
        const Text(
          'Failed to load user data',
          style: TextStyle(color: kAdminTextMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _loadAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: kAdminAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminAccent.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: kAdminAccent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    final user = Map<String, dynamic>.from(_summary!['user'] ?? {});
    final counts = Map<String, dynamic>.from(_summary!['counts'] ?? {});
    final categories = List<Map<String, dynamic>>.from(
      _summary!['category_counts'] ?? const [],
    );

    final fn = (user['first_name'] ?? '').toString().trim();
    final ln = (user['last_name'] ?? '').toString().trim();
    final initials =
        '${fn.isNotEmpty ? fn[0] : ''}${ln.isNotEmpty ? ln[0] : ''}'
            .toUpperCase();
    final usernameInitial = widget.username.trim().isNotEmpty
        ? widget.username.trim()[0].toUpperCase()
        : '?';
    final avatarLabel = initials.isNotEmpty ? initials : usernameInitial;
    final avatarUrl = _absUrl(user['avatar']);
    final isActive = user['is_active'] == true;
    final isStaff = user['is_staff'] == true;

    return Column(
      children: [
        // ── Profile header ──────────────────────────────────────────────────
        Container(
          color: kAdminSurface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kAdminAccentDim,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kAdminAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  avatarLabel,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: kAdminAccent,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                avatarLabel,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: kAdminAccent,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.username,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kAdminText,
                          ),
                        ),
                        if ((user['email'] ?? '').toString().isNotEmpty)
                          Text(
                            user['email'].toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: kAdminTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Badge(
                        label: isActive ? 'Active' : 'Inactive',
                        color: isActive ? kAdminGreen : kAdminRed,
                        bg: isActive ? kAdminGreenDim : kAdminRedDim,
                      ),
                      if (isStaff) ...[
                        const SizedBox(height: 4),
                        _Badge(
                          label: 'Staff',
                          color: kAdminYellow,
                          bg: kAdminYellowDim,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      icon: Icons.checkroom_rounded,
                      label: 'Clothing',
                      value: '${counts['clothing'] ?? 0}',
                      color: kAdminBlue,
                      bg: kAdminBlueDim,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatBox(
                      icon: Icons.watch_rounded,
                      label: 'Access.',
                      value: '${counts['accessories'] ?? 0}',
                      color: kAdminAccent,
                      bg: kAdminAccentDim,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatBox(
                      icon: Icons.style_rounded,
                      label: 'Outfits',
                      value: '${counts['outfits'] ?? 0}',
                      color: kAdminGreen,
                      bg: kAdminGreenDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Dates
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 10,
                    color: kAdminTextDim,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Joined ${_shortDate(user['date_joined']?.toString())}',
                    style: const TextStyle(fontSize: 10, color: kAdminTextDim),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 10,
                    color: kAdminTextDim,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active ${_shortDate(user['last_active_at']?.toString())}',
                    style: const TextStyle(fontSize: 10, color: kAdminTextDim),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Category chips ──────────────────────────────────────────────────
        if (categories.isNotEmpty)
          Container(
            width: double.infinity,
            color: kAdminSurface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: kAdminBorder),
                const SizedBox(height: 10),
                const Text(
                  'WARDROBE CATEGORIES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: kAdminTextMuted,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.map((row) {
                    final cat = (row['category'] ?? 'Unknown').toString();
                    final count = (row['total'] ?? 0) as int;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kAdminSurface2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kAdminBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kAdminText,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: kAdminAccentDim,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: kAdminAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        // ── Tab bar ─────────────────────────────────────────────────────────
        Container(
          color: kAdminSurface,
          child: Column(
            children: [
              Container(height: 1, color: kAdminBorder),
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Wardrobe'),
                  Tab(text: 'Outfits'),
                ],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                labelColor: kAdminAccent,
                unselectedLabelColor: kAdminTextMuted,
                indicatorColor: kAdminAccent,
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ],
          ),
        ),

        // ── Tab content ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildWardrobeTab(), _buildOutfitsTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildWardrobeTab() {
    if (_clothing.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom_outlined, size: 42, color: kAdminTextDim),
            SizedBox(height: 8),
            Text(
              'No clothing items yet',
              style: TextStyle(color: kAdminTextMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: _clothing.length,
      itemBuilder: (_, i) =>
          _ClothingThumb(item: _clothing[i], absUrl: _absUrl),
    );
  }

  Widget _buildOutfitsTab() {
    if (_outfits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined, size: 42, color: kAdminTextDim),
            SizedBox(height: 8),
            Text(
              'No outfits yet',
              style: TextStyle(color: kAdminTextMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _outfits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _OutfitRow(outfit: _outfits[i], absUrl: _absUrl),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: kAdminTextMuted,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ClothingThumb extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) absUrl;
  const _ClothingThumb({required this.item, required this.absUrl});

  @override
  Widget build(BuildContext context) {
    final imgUrl = absUrl(item['image']);
    final subcategory = (item['subcategory'] ?? '').toString();
    final category = (item['category'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAdminBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: imgUrl.isNotEmpty
                ? Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ImgPlaceholder(),
                  )
                : const _ImgPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subcategory.isNotEmpty ? subcategory : category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kAdminText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subcategory.isNotEmpty && category.isNotEmpty)
                  Text(
                    category,
                    style: const TextStyle(fontSize: 9, color: kAdminTextMuted),
                    maxLines: 1,
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

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: kAdminSurface2,
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 22, color: kAdminTextDim),
    ),
  );
}

class _OutfitRow extends StatelessWidget {
  final Map<String, dynamic> outfit;
  final String Function(dynamic) absUrl;

  const _OutfitRow({required this.outfit, required this.absUrl});

  static const _slotKeys = [
    ('outerwear_item', 'Outer', kAdminYellow),
    ('topwear_item', 'Top', kAdminAccent),
    ('bottomwear_item', 'Bottom', kAdminBlue),
    ('shoes_item', 'Shoes', kAdminGreen),
  ];

  @override
  Widget build(BuildContext context) {
    final name = (outfit['name'] ?? 'Outfit').toString();
    final occasion = (outfit['occasion'] ?? '').toString();
    final rating = outfit['rating'];
    final wearCount = outfit['wear_count'] ?? 0;
    final isFav = outfit['is_favourite'] == true;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Slot thumbnails — 2×2 grid
          SizedBox(
            width: 100,
            height: 86,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              children: _slotKeys.map(((String, String, Color) s) {
                final slot = outfit[s.$1];
                final img = absUrl(slot is Map ? slot['image'] : null);
                final color = s.$3;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      img.isNotEmpty
                          ? Image.network(
                              img,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  _SlotEmpty(color: color),
                            )
                          : _SlotEmpty(color: color),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            s.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kAdminText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFav) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: kAdminRed,
                      ),
                    ],
                  ],
                ),
                if (occasion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    occasion,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kAdminTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: kAdminYellow,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$rating',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kAdminYellow,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Icon(
                      Icons.repeat_rounded,
                      size: 11,
                      color: kAdminTextDim,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$wearCount worn',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kAdminTextDim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotEmpty extends StatelessWidget {
  final Color color;
  const _SlotEmpty({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Using .withValues(alpha: 0.08) is correct for newer Flutter versions
      color: color.withValues(alpha: 0.08),
      child: Icon(Icons.checkroom_outlined, size: 14, color: color),
    );
  }
}
