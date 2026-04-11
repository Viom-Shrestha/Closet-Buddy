import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/admin_service.dart';
import 'package:frontend/services/misc_service.dart';
import 'package:frontend/services/profile_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/features/admin/screens/admin_user_detail_screen.dart';

part '../../../widgets/admin/admin_screen_components.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  final ProfileService _profileService =
      ServiceRegistry.instance.profileService;
  final AdminService _adminService = ServiceRegistry.instance.adminService;
  final MiscService _miscService = ServiceRegistry.instance.miscService;

  bool get _isDarkTheme => ThemeService.instance.isDark;

  // Controllers
  final _searchCtrl = TextEditingController();
  final _catalogSearchCtrl = TextEditingController();
  final _catalogCategoryCtrl = TextEditingController();
  final _catalogSubcategoryCtrl = TextEditingController();
  final _catalogColorCtrl = TextEditingController();
  final _catalogUserCtrl = TextEditingController();
  final _catalogOccasionCtrl = TextEditingController();

  // Access
  bool _checkingAccess = true;
  bool _isAdmin = false;

  // Loading flags
  bool _loadingOverview = false;
  bool _loadingUsers = false;
  bool _loadingCatalog = false;
  bool _loadingNonClothing = false;
  bool _loadingOutfits = false;
  bool _loadingFeedback = false;

  // Data
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _catalogItems = [];
  List<Map<String, dynamic>> _nonClothingItems = [];
  List<int> _selectedCatalogIds = [];
  List<Map<String, dynamic>> _adminOutfits = [];
  List<Map<String, dynamic>> _feedback = [];
  Map<String, dynamic>? _profile;

  // Outfit sort
  String _outfitSortBy = 'Newest first';

  List<Map<String, dynamic>> get _sortedOutfits {
    final list = List<Map<String, dynamic>>.from(_adminOutfits);
    switch (_outfitSortBy) {
      case 'Oldest first':
        list.sort(
          (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
        );
      case 'Rating (high to low)':
        list.sort((a, b) {
          final ra = int.tryParse(a['rating']?.toString() ?? '') ?? 0;
          final rb = int.tryParse(b['rating']?.toString() ?? '') ?? 0;
          return rb.compareTo(ra);
        });
      case 'Favourites first':
        list.sort((a, b) {
          final fa = (a['is_favourite'] == true) ? 0 : 1;
          final fb = (b['is_favourite'] == true) ? 0 : 1;
          return fa.compareTo(fb);
        });
      default:
        list.sort(
          (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
        );
    }
    return list;
  }

  // Catalog occasion filter (client-side)
  List<Map<String, dynamic>> get _filteredCatalogItems {
    final occ = _catalogOccasionCtrl.text.trim().toLowerCase();
    if (occ.isEmpty) return _catalogItems;
    return _catalogItems.where((item) {
      final itemOcc = (item['occasion'] ?? '').toString().toLowerCase();
      return itemOcc == occ;
    }).toList();
  }

  // Tab navigation
  late final TabController _tabCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;

  void _onThemeModeChanged() {
    if (mounted) setState(() {});
  }

  static const _tabs = [
    _AdminTabMeta(Icons.dashboard_rounded, 'Overview'),
    _AdminTabMeta(Icons.group_rounded, 'Users'),
    _AdminTabMeta(Icons.checkroom_rounded, 'Catalog'),
    _AdminTabMeta(Icons.style_rounded, 'Outfits'),
    _AdminTabMeta(Icons.forum_rounded, 'Feedback'),
  ];

  @override
  void initState() {
    super.initState();
    ThemeService.instance.themeMode.addListener(_onThemeModeChanged);
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _bootstrap();
  }

  @override
  void dispose() {
    ThemeService.instance.themeMode.removeListener(_onThemeModeChanged);
    _tabCtrl.dispose();
    _enterCtrl.dispose();
    _searchCtrl.dispose();
    _catalogSearchCtrl.dispose();
    _catalogCategoryCtrl.dispose();
    _catalogSubcategoryCtrl.dispose();
    _catalogColorCtrl.dispose();
    _catalogUserCtrl.dispose();
    _catalogOccasionCtrl.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    final profile = await _profileService.fetchProfile();
    if (!mounted) return;
    final isAdmin = (profile?['role'] ?? '').toString() == 'admin';
    setState(() {
      _checkingAccess = false;
      _isAdmin = isAdmin;
      _profile = profile;
    });
    if (!isAdmin) return;
    await _refreshAll();
    _enterCtrl.forward();
  }

  Future<void> _refreshAll() => Future.wait([
    _loadProfile(),
    _loadDashboard(),
    _loadUsers(),
    _refreshCatalogData(),
    _loadOutfits(),
    _loadFeedback(),
  ]);

  Future<void> _loadDashboard() async {
    setState(() => _loadingOverview = true);
    final data = await _adminService.fetchDashboard();
    if (!mounted) return;
    setState(() {
      _dashboard = data;
      _loadingOverview = false;
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    final data = await _adminService.fetchUsers(query: _searchCtrl.text);
    if (!mounted) return;
    setState(() {
      _users = data;
      _loadingUsers = false;
    });
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    final data = await _adminService.fetchCatalog(
      query: _catalogSearchCtrl.text,
      category: _catalogCategoryCtrl.text,
      subcategory: _catalogSubcategoryCtrl.text,
      dominantColor: _catalogColorCtrl.text,
      userId: _catalogUserCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _catalogItems = List<Map<String, dynamic>>.from(data['results'] ?? []);
      _selectedCatalogIds = [];
      _loadingCatalog = false;
    });
  }

  Future<void> _loadNonClothing() async {
    setState(() => _loadingNonClothing = true);
    final data = await _miscService.fetchNonClothingItems(
      query: _catalogSearchCtrl.text,
      userId: _catalogUserCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _nonClothingItems = List<Map<String, dynamic>>.from(
        data['results'] ?? [],
      );
      _loadingNonClothing = false;
    });
  }

  Future<void> _refreshCatalogData() async {
    await Future.wait([_loadCatalog(), _loadNonClothing()]);
  }

  Future<void> _loadOutfits() async {
    setState(() => _loadingOutfits = true);
    final data = await _adminService.fetchOutfits();
    if (!mounted) return;
    setState(() {
      _adminOutfits = List<Map<String, dynamic>>.from(data['results'] ?? []);
      _loadingOutfits = false;
    });
  }

  Future<void> _loadFeedback() async {
    setState(() => _loadingFeedback = true);
    final data = await _adminService.fetchFeedback();
    if (!mounted) return;
    setState(() {
      _feedback = List<Map<String, dynamic>>.from(data['results'] ?? []);
      _loadingFeedback = false;
    });
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.fetchProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _setUserActive(Map<String, dynamic> user, bool next) async {
    final id = _asInt(user['id']);
    if (id == null) return;
    final ok = await _adminService.setUserActive(id, next);
    if (!mounted) return;
    _snack(
      ok ? (next ? 'User activated' : 'User deactivated') : 'Update failed',
      ok ? kAdminGreen : kAdminRed,
    );
    if (ok) await Future.wait([_loadUsers(), _loadDashboard()]);
  }

  Future<void> _setUserStaff(Map<String, dynamic> user, bool next) async {
    final id = _asInt(user['id']);
    if (id == null) return;
    final ok = await _adminService.setUserStaff(id, next);
    if (!mounted) return;
    _snack(
      ok
          ? (next ? 'Promoted to admin' : 'Admin role removed')
          : 'Update failed',
      ok ? kAdminGreen : kAdminRed,
    );
    if (ok) await Future.wait([_loadUsers(), _loadDashboard()]);
  }

  Future<void> _sendPasswordReset(Map<String, dynamic> user) async {
    final id = _asInt(user['id']);
    if (id == null) return;
    final ok = await _adminService.sendPasswordReset(id);
    if (!mounted) return;
    _snack(
      ok ? 'Password reset email sent' : 'Failed to send reset',
      ok ? kAdminGreen : kAdminRed,
    );
  }

  Future<void> _openUserDetail(Map<String, dynamic> user) async {
    final id = _asInt(user['id']);
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(
          userId: id,
          username: (user['username'] ?? 'User').toString(),
        ),
      ),
    );
  }

  void _toggleCatalogSelection(int id) {
    setState(() {
      if (_selectedCatalogIds.contains(id)) {
        _selectedCatalogIds.remove(id);
      } else {
        _selectedCatalogIds.add(id);
      }
    });
  }

  Future<void> _bulkReclassify() async {
    if (_selectedCatalogIds.isEmpty) {
      _snack('Select items first', kAdminAccent);
      return;
    }
    final catCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    final confirmed = await _showAdminDialog(
      title: 'Bulk Reclassify',
      subtitle: '${_selectedCatalogIds.length} items selected',
      children: [
        _DarkDropdown(
          controller: catCtrl,
          label: 'Category',
          options: _kCategories,
        ),
        const SizedBox(height: 10),
      ],
      confirmLabel: 'Apply',
    );
    if (confirmed != true) return;
    final updated = await _adminService.bulkReclassify(
      _selectedCatalogIds,
      catCtrl.text.trim(),
      subCtrl.text.trim(),
    );
    if (!mounted) return;
    _snack('Updated $updated items', kAdminGreen);
    await _loadCatalog();
  }

  Future<void> _deleteCatalogItem(int id) async {
    final ok = await _adminService.deleteClothing(id);
    if (!mounted) return;
    _snack(ok ? 'Item deleted' : 'Delete failed', ok ? kAdminGreen : kAdminRed);
    if (ok) await _loadCatalog();
  }

  Future<void> _deleteOutfit(int id) async {
    final ok = await _adminService.deleteOutfit(id);
    if (!mounted) return;
    _snack(
      ok ? 'Outfit deleted' : 'Delete failed',
      ok ? kAdminGreen : kAdminRed,
    );
    if (ok) await _loadOutfits();
  }

  Future<void> _toggleFeedbackRead(int id, bool value) async {
    final ok = await _adminService.markFeedbackRead(id, value);
    if (!mounted) return;
    if (ok) await _loadFeedback();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: kAdminBg,
        body: Center(
          child: CircularProgressIndicator(
            color: kAdminAccent,
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
          ),
        ),
      );
    }
    if (!_isAdmin) return _buildAccessDenied();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDarkTheme
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Theme(
        data: _buildAdminTheme(),
        child: Scaffold(
          key: ValueKey(_isDarkTheme),
          backgroundColor: kAdminBg,
          body: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildTopBar(),
                _buildTabStrip(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildOverviewTab(),
                      _buildUsersTab(),
                      _buildCatalogTab(),
                      _buildOutfitsTab(),
                      _buildFeedbackTab(),
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

  // ── Top bar ───────────────────────────────────────────────────────────────────
  // IMPROVED: tighter, more refined header with better visual grouping

  Widget _buildTopBar() {
    final avatarUrl = _resolveImageUrl(_profile?['avatar']);
    final avatarInitial = _initial(
      (_profile?['username'] ?? _profile?['first_name'] ?? '').toString(),
    );
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 12,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: kAdminSurface,
        border: Border(bottom: BorderSide(color: kAdminBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
            size: 15,
          ),
          const SizedBox(width: 12),

          // Brand mark + title cluster
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kAdminAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminAccent.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 14,
                  color: kAdminAccent,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Admin Console',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kAdminText,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Live pill
          _LiveBadge(),

          const SizedBox(width: 6),

          // Avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: kAdminSurface2,
              shape: BoxShape.circle,
              border: Border.all(color: kAdminBorder, width: 1.5),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _AvatarFallback(initial: avatarInitial),
                    )
                  : _AvatarFallback(initial: avatarInitial),
            ),
          ),

          const SizedBox(width: 6),

          // Theme toggle
          _IconBtn(
            icon: _isDarkTheme
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            onTap: () async {
              HapticFeedback.lightImpact();
              await ThemeService.instance.toggle();
            },
          ),

          const SizedBox(width: 4),

          // Refresh
          _IconBtn(
            icon: Icons.refresh_rounded,
            onTap: () async {
              HapticFeedback.lightImpact();
              await _refreshAll();
            },
          ),
        ],
      ),
    );
  }

  // ── Tab strip ─────────────────────────────────────────────────────────────────
  // IMPROVED: pill-style selected indicator, tighter spacing

  Widget _buildTabStrip() {
    return Container(
      color: kAdminSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 46,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: kAdminAccent,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: kAdminAccent,
              unselectedLabelColor: kAdminTextMuted,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tabs: _tabs
                  .map(
                    (t) => Tab(
                      height: 46,
                      child: Row(
                        children: [
                          Icon(t.icon, size: 14),
                          const SizedBox(width: 5),
                          Text(t.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Divider(height: 1, thickness: 1, color: kAdminBorder),
        ],
      ),
    );
  }

  // ── Overview tab ─────────────────────────────────────────────────────────────
  // IMPROVED: grouped sections, better card hierarchy, cleaner rhythm

  Widget _buildOverviewTab() {
    if (_loadingOverview && _dashboard == null) return _loadingCenter();
    if (_dashboard == null) return _errorCenter(_loadDashboard);

    final overview = _map(_dashboard!['overview']);
    final last7 = _map(_dashboard!['last_7_days']);
    final engagement = _map(_dashboard!['engagement']);
    final outfitStats = _map(_dashboard!['outfit_stats']);
    final wardrobeStats = _map(_dashboard!['wardrobe_stats']);
    final slotCoverage = _map(_dashboard!['slot_coverage']);
    final topCategories = _list(_dashboard!['top_categories']);
    final topColors = _list(_dashboard!['top_colors']);
    final storageTypes = _list(_dashboard!['storage_types']);
    final outfitsPerDay = _list(
      _dashboard!['outfit_stats']?['outfits_per_day'],
    );
    final recentUsers = _list(_dashboard!['recent_users']);

    final slotData = [
      _SlotDatum(
        'Top',
        _toDouble(slotCoverage['topwear_percent']),
        kAdminAccent,
      ),
      _SlotDatum(
        'Bottom',
        _toDouble(slotCoverage['bottomwear_percent']),
        kAdminBlue,
      ),
      _SlotDatum(
        'Shoes',
        _toDouble(slotCoverage['shoes_percent']),
        kAdminGreen,
      ),
      _SlotDatum(
        'Outer',
        _toDouble(slotCoverage['outerwear_percent']),
        kAdminYellow,
      ),
      _SlotDatum(
        'Acc',
        _toDouble(slotCoverage['accessories_percent']),
        kAdminRed,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: kAdminAccent,
      backgroundColor: kAdminSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 56),
        children: [
          // ── Hero KPI row — most important numbers up top ─────────────────
          _buildHeroKpiRow(overview, last7),

          const SizedBox(height: 20),

          // ── Secondary stats row ──────────────────────────────────────────
          _buildSecondaryKpiRow(overview, last7),

          const SizedBox(height: 28),

          // ── Activity chart ────────────────────────────────────────────────
          _SectionHeader(
            label: 'Activity',
            subtitle: 'Outfits created per day',
            icon: Icons.show_chart_rounded,
          ),
          const SizedBox(height: 12),
          _OutfitsPerDayChart(rows: outfitsPerDay),

          const SizedBox(height: 28),

          // ── Engagement ─────────────────────────────────────────────────────
          _SectionHeader(label: 'Engagement', icon: Icons.people_alt_rounded),
          const SizedBox(height: 12),
          _buildEngagementSection(overview, engagement),

          const SizedBox(height: 28),

          // ── Key Metrics ────────────────────────────────────────────────────
          _SectionHeader(label: 'Key Metrics', icon: Icons.insights_rounded),
          const SizedBox(height: 12),
          _buildKeyMetricsRow(outfitStats, wardrobeStats),

          const SizedBox(height: 28),

          // ── Wardrobe analytics ─────────────────────────────────────────────
          _SectionHeader(
            label: 'Wardrobe Analytics',
            icon: Icons.checkroom_rounded,
          ),
          const SizedBox(height: 12),
          _SlotRingChart(data: slotData),
          const SizedBox(height: 12),
          _HorizontalBarChart(
            rows: topCategories,
            labelKey: 'category',
            valueKey: 'total',
            color: kAdminBlue,
          ),

          const SizedBox(height: 28),

          // ── Storage & Colors side by side ──────────────────────────────────
          _SectionHeader(
            label: 'Storage & Colors',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StorageTypesChart(rows: storageTypes)),
                const SizedBox(width: 10),
                Expanded(child: _ColorSwatchChart(rows: topColors)),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Recent sign-ups ────────────────────────────────────────────────
          _SectionHeader(
            label: 'Recent Sign-ups',
            icon: Icons.person_add_rounded,
            count: recentUsers.length,
          ),
          const SizedBox(height: 12),
          _buildRecentUsersCard(recentUsers),
        ],
      ),
    );
  }

  // ── Hero KPI: Users + Clothing + Outfits (most prominent) ────────────────────

  Widget _buildHeroKpiRow(
    Map<String, dynamic> overview,
    Map<String, dynamic> last7,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _HeroKpiCard(
            label: 'Total Users',
            value: '${overview['total_users'] ?? 0}',
            delta: '+${last7['new_users'] ?? 0} this week',
            icon: Icons.group_rounded,
            color: kAdminBlue,
            subValue: 'Active: ${overview['active_users'] ?? 0}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: _HeroKpiCard(
            label: 'Clothing Items',
            value: '${overview['total_clothing_items'] ?? 0}',
            delta: '+${last7['new_clothing'] ?? 0} this week',
            icon: Icons.checkroom_rounded,
            color: kAdminAccent,
            subValue: 'Accessories: ${overview['total_accessories'] ?? 0}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: _HeroKpiCard(
            label: 'Outfits',
            value: '${overview['total_outfits'] ?? 0}',
            delta: '+${last7['new_outfits'] ?? 0} this week',
            icon: Icons.style_rounded,
            color: kAdminYellow,
          ),
        ),
      ],
    );
  }

  // ── Secondary KPI: smaller supporting stats ───────────────────────────────────

  Widget _buildSecondaryKpiRow(
    Map<String, dynamic> overview,
    Map<String, dynamic> last7,
  ) {
    return Row(
      children: [
        Expanded(
          child: _MiniKpiCard(
            label: 'Storages',
            value: '${overview['total_storages'] ?? 0}',
            delta: '+${last7['new_storages'] ?? 0}',
            icon: Icons.inventory_2_outlined,
            color: kAdminBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniKpiCard(
            label: 'Non-Clothing',
            value: '${overview['total_non_clothing'] ?? 0}',
            delta: '+${last7['new_non_clothing'] ?? 0}',
            icon: Icons.category_outlined,
            color: kAdminTextMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniKpiCard(
            label: 'Admins',
            value: '${overview['admin_users'] ?? 0}',
            icon: Icons.admin_panel_settings_rounded,
            color: kAdminYellow,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniKpiCard(
            label: 'Accessories',
            value: '${overview['total_accessories'] ?? 0}',
            delta: '+${last7['new_accessories'] ?? 0}',
            icon: Icons.watch_rounded,
            color: kAdminRed,
          ),
        ),
      ],
    );
  }

  // ── Engagement section ─────────────────────────────────────────────────────────

  Widget _buildEngagementSection(
    Map<String, dynamic> overview,
    Map<String, dynamic> engagement,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _EngagementGauge(
                  label: 'Daily Active Users',
                  value: _toDouble(engagement['dau']),
                  max: _toDouble(
                    overview['active_users'],
                  ).clamp(1, double.infinity),
                  color: kAdminBlue,
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 64, color: kAdminBorder),
              const SizedBox(width: 14),
              Expanded(
                child: _EngagementGauge(
                  label: 'Weekly Active Users',
                  value: _toDouble(engagement['wau']),
                  max: _toDouble(
                    overview['active_users'],
                  ).clamp(1, double.infinity),
                  color: kAdminGreen,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Divider(height: 1, color: kAdminBorder),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Sessions / user',
                  value: '${engagement['sessions_per_user'] ?? '—'}',
                  icon: Icons.repeat_rounded,
                  color: kAdminAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'Avg session length',
                  value: '${engagement['average_session_seconds'] ?? '—'}s',
                  icon: Icons.timer_outlined,
                  color: kAdminYellow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Key metrics row ──────────────────────────────────────────────────────────

  Widget _buildKeyMetricsRow(
    Map<String, dynamic> outfitStats,
    Map<String, dynamic> wardrobeStats,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            label: 'Avg wardrobe size',
            value: '${wardrobeStats['average_wardrobe_size'] ?? '—'}',
            icon: Icons.checkroom_rounded,
            color: kAdminBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            label: 'Avg outfit rating',
            value: outfitStats['average_rating'] != null
                ? '${outfitStats['average_rating']} / 5'
                : '—',
            icon: Icons.star_rounded,
            color: kAdminYellow,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            label: 'Favourite rate',
            value: '${outfitStats['favourite_rate'] ?? '—'}%',
            icon: Icons.favorite_rounded,
            color: kAdminRed,
          ),
        ),
      ],
    );
  }

  // ── Recent users card ─────────────────────────────────────────────────────────

  Widget _buildRecentUsersCard(List<Map<String, dynamic>> recentUsers) {
    if (recentUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kAdminSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAdminBorder),
        ),
        child: Center(
          child: Text(
            'No recent sign-ups',
            style: TextStyle(color: kAdminTextMuted, fontSize: 13),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: List.generate(recentUsers.length, (i) {
          final isLast = i == recentUsers.length - 1;
          return Column(
            children: [
              _RecentUserRow(user: recentUsers[i]),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(height: 1, color: kAdminBorder),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Users tab ─────────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SearchBar(
            controller: _searchCtrl,
            hint: 'Search by name or email…',
            onSearch: _loadUsers,
          ),
        ),
        if (_users.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _CountBadge(
                  count: _users.length,
                  label: 'user',
                  color: kAdminBlue,
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: _loadingUsers && _users.isEmpty
                ? _loadingCenter()
                : _users.isEmpty
                ? _emptyCenter('No users found', Icons.group_off_rounded)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: _users.length,
                    itemBuilder: (_, i) => _UserCard(
                      user: _users[i],
                      onDetail: _openUserDetail,
                      onActivate: (u) =>
                          _setUserActive(u, !(u['is_active'] == true)),
                      onStaff: (u) =>
                          _setUserStaff(u, !(u['is_staff'] == true)),
                      onReset: _sendPasswordReset,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Catalog tab ───────────────────────────────────────────────────────────────

  Widget _buildCatalogTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SearchBar(
            controller: _catalogSearchCtrl,
            hint: 'Search catalog…',
            onSearch: _refreshCatalogData,
            trailing: _DarkChipButton(
              label: 'Filters',
              icon: Icons.tune_rounded,
              onTap: _showCatalogFilters,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildNonClothingPanel(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedCatalogIds.isEmpty
                      ? kAdminSurface2
                      : kAdminAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedCatalogIds.isEmpty
                        ? kAdminBorder
                        : kAdminAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _selectedCatalogIds.isEmpty
                      ? 'Tap items to select'
                      : '${_selectedCatalogIds.length} selected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _selectedCatalogIds.isEmpty
                        ? kAdminTextDim
                        : kAdminAccent,
                  ),
                ),
              ),
              const Spacer(),
              if (_selectedCatalogIds.isNotEmpty)
                _DarkChipButton(
                  label: 'Reclassify',
                  icon: Icons.category_rounded,
                  onTap: _bulkReclassify,
                  highlight: true,
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCatalogData,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: _loadingCatalog && _catalogItems.isEmpty
                ? _loadingCenter()
                : _filteredCatalogItems.isEmpty
                ? _emptyCenter('No items found', Icons.checkroom_rounded)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _filteredCatalogItems.length,
                    itemBuilder: (_, i) {
                      final item = _filteredCatalogItems[i];
                      final id = _asInt(item['id']);
                      final selected =
                          id != null && _selectedCatalogIds.contains(id);
                      return _CatalogItemCard(
                        item: item,
                        selected: selected,
                        onToggle: id == null
                            ? null
                            : () => _toggleCatalogSelection(id),
                        onDelete: id == null
                            ? null
                            : () => _deleteCatalogItem(id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ── Non-clothing panel ────────────────────────────────────────────────────────

  Widget _buildNonClothingPanel() {
    final previewRows = _nonClothingItems.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 13, color: kAdminAccent),
              const SizedBox(width: 6),
              const Text(
                'Non-clothing Inventory',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kAdminText,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              if (_loadingNonClothing)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: kAdminAccent,
                  ),
                )
              else
                _CountBadge(
                  count: _nonClothingItems.length,
                  label: 'item',
                  color: kAdminAccent,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingNonClothing && _nonClothingItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_nonClothingItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'No non-clothing items found.',
                style: TextStyle(fontSize: 11, color: kAdminTextMuted),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 28,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 42,
                columnSpacing: 20,
                horizontalMargin: 8,
                dividerThickness: 0.5,
                headingRowColor: WidgetStateProperty.all(kAdminSurface2),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 10,
                        color: kAdminTextMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Storage',
                      style: TextStyle(
                        fontSize: 10,
                        color: kAdminTextMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Owner',
                      style: TextStyle(
                        fontSize: 10,
                        color: kAdminTextMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Created',
                      style: TextStyle(
                        fontSize: 10,
                        color: kAdminTextMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                rows: previewRows.map((item) {
                  final storage = _map(item['storage_unit']);
                  final user = _map(item['user']);
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _truncateText(item['name'], max: 22),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAdminText,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _truncateText(storage['name'], max: 18),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAdminTextMuted,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _truncateText(user['username'], max: 16),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAdminTextMuted,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatShortDate(item['created_at']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAdminTextMuted,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          if (_nonClothingItems.length > previewRows.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Showing latest ${previewRows.length} of ${_nonClothingItems.length} items',
                style: const TextStyle(fontSize: 10, color: kAdminTextDim),
              ),
            ),
        ],
      ),
    );
  }

  // ── Outfits tab ───────────────────────────────────────────────────────────────

  Widget _buildOutfitsTab() {
    if (_loadingOutfits && _adminOutfits.isEmpty) return _loadingCenter();
    if (_adminOutfits.isEmpty) {
      return _emptyCenter('No outfits saved yet', Icons.style_rounded);
    }
    final sorted = _sortedOutfits;
    return Column(
      children: [
        // Sort bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.sort, size: 16, color: kAdminTextMuted),
              const SizedBox(width: 6),
              const Text(
                'Sort:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kAdminTextMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          'Newest first',
                          'Oldest first',
                          'Rating (high to low)',
                          'Favourites first',
                        ].map((option) {
                          final active = _outfitSortBy == option;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _outfitSortBy = option),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: active ? kAdminAccent : kAdminSurface2,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active ? kAdminAccent : kAdminBorder,
                                  ),
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: active ? kAdminBg : kAdminTextMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOutfits,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1200
                    ? 4
                    : width >= 900
                    ? 3
                    : width >= 600
                    ? 2
                    : 1;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: sorted.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (_, i) {
                    final outfit = sorted[i];
                    final id = _asInt(outfit['id']);
                    return _OutfitGridCard(
                      outfit: outfit,
                      onDelete: id == null ? null : () => _deleteOutfit(id),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Feedback tab ──────────────────────────────────────────────────────────────

  Widget _buildFeedbackTab() {
    final unread = _feedback.where((f) => f['is_read'] != true).length;
    return Column(
      children: [
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _UnreadBanner(count: unread),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFeedback,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: _loadingFeedback && _feedback.isEmpty
                ? _loadingCenter()
                : _feedback.isEmpty
                ? _emptyCenter('No feedback yet', Icons.forum_rounded)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: _feedback.length,
                    itemBuilder: (_, i) {
                      final item = _feedback[i];
                      final id = _asInt(item['id']);
                      return _FeedbackCard(
                        item: item,
                        onToggleRead: id == null
                            ? null
                            : (v) => _toggleFeedbackRead(id, v),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────────

  Widget _loadingCenter() => const Center(
    child: CircularProgressIndicator(
      color: kAdminAccent,
      strokeWidth: 2,
      strokeCap: StrokeCap.round,
    ),
  );

  Widget _errorCenter(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: kAdminSurface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kAdminBorder),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: kAdminTextDim,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Could not load dashboard',
            style: TextStyle(
              color: kAdminTextMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _DarkButton(label: 'Retry', onTap: onRetry),
        ],
      ),
    );
  }

  Widget _emptyCenter(String label, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kAdminSurface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kAdminBorder),
          ),
          child: Icon(icon, color: kAdminTextDim, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: kAdminTextMuted, fontSize: 13),
        ),
      ],
    ),
  );

  // ── Access denied ─────────────────────────────────────────────────────────────

  Widget _buildAccessDenied() => Scaffold(
    backgroundColor: kAdminBg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: kAdminRedDim,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kAdminRed.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.lock_rounded, color: kAdminRed, size: 30),
          ),
          const SizedBox(height: 18),
          const Text(
            'Admin Only',
            style: TextStyle(
              color: kAdminText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You don\'t have permission to access this area.',
            style: TextStyle(color: kAdminTextMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _DarkButton(label: 'Go back', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );

  // ── Dialogs ────────────────────────────────────────────────────────────────────

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                color: kAdminText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: kAdminSurface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  Future<bool?> _showAdminDialog({
    required String title,
    String? subtitle,
    required List<Widget> children,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: _buildAdminTheme(),
        child: Dialog(
          backgroundColor: kAdminSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kAdminBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kAdminText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kAdminTextMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ...children,
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kAdminSurface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kAdminBorder),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: kAdminTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DarkButton(
                        label: confirmLabel,
                        onTap: () => Navigator.pop(ctx, true),
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCatalogFilters() async {
    final confirmed = await _showAdminDialog(
      title: 'Filter Catalog',
      children: [
        _DarkDropdown(
          controller: _catalogCategoryCtrl,
          label: 'Category',
          options: _kCategories,
        ),
        const SizedBox(height: 10),
        _DarkDropdown(
          controller: _catalogSubcategoryCtrl,
          label: 'Subcategory',
          options: _kSubcategories,
        ),
        const SizedBox(height: 10),
        _DarkDropdown(
          controller: _catalogOccasionCtrl,
          label: 'Occasion',
          options: _kOccasions,
        ),
        const SizedBox(height: 10),
        _DarkTextField(controller: _catalogColorCtrl, label: 'Dominant color'),
        const SizedBox(height: 10),
        _DarkTextField(controller: _catalogUserCtrl, label: 'User ID'),
      ],
      confirmLabel: 'Apply',
    );
    if (confirmed == true) {
      setState(() {});
      await _refreshCatalogData();
    }
  }

  // ── Constants ─────────────────────────────────────────────────────────────────

  static const _kCategories = ['Topwear', 'Outerwear', 'Bottomwear', 'Shoes'];

  static const _kSubcategories = [
    'T-Shirt',
    'Shirt',
    'Polo',
    'Blouse',
    'Tank Top',
    'Sweater',
    'Hoodie',
    'Jacket',
    'Cardigan',
    'Vest',
    'Jeans',
    'Pants',
    'Shorts',
    'Skirt',
    'Leggings',
    'Dress',
    'Sneakers',
    'Formal Shoes',
    'Boots',
    'Sandals',
    'Heels',
    'Loafers',
    'Slippers',
    'Flip Flops',
    'Sports Shoes',
  ];

  static const _kOccasions = [
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

  // ── Theme ─────────────────────────────────────────────────────────────────────

  ThemeData _buildAdminTheme() {
    final brightness = _isDarkTheme ? Brightness.dark : Brightness.light;
    final base = _isDarkTheme ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: kAdminBg,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: kAdminAccent,
        secondary: kAdminAccent,
        surface: kAdminSurface,
        onSurface: kAdminText,
        error: kAdminRed,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: kAdminText,
        displayColor: kAdminText,
      ),
      dividerColor: kAdminBorder,
      cardColor: kAdminSurface,
      cardTheme: CardThemeData(
        color: kAdminSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kAdminBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kAdminSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAdminBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAdminBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAdminAccent),
        ),
        hintStyle: const TextStyle(color: kAdminTextDim),
        labelStyle: const TextStyle(color: kAdminTextMuted),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _initial(String? value) {
    final s = (value ?? '').trim();
    return s.isEmpty ? '' : s[0].toUpperCase();
  }

  String _resolveImageUrl(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }

  String _truncateText(dynamic raw, {int max = 24}) {
    final text = (raw ?? '').toString().trim();
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  String _formatShortDate(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ── New helper widgets (drop these in admin_screen_components.dart) ──────────────

/// Reusable icon button used in the top bar.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _IconBtn({required this.icon, required this.onTap, this.size = 17});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: kAdminSurface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kAdminBorder),
        ),
        child: Icon(icon, size: size, color: kAdminTextMuted),
      ),
    );
  }
}

/// Animated "Live" badge.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAdminGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAdminGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: kAdminGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kAdminGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header with an icon, label, optional subtitle, and optional count.
class _SectionHeader extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final int? count;

  const _SectionHeader({
    required this.label,
    required this.icon,
    this.subtitle,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: kAdminAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAdminAccent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 13, color: kAdminAccent),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kAdminText,
                letterSpacing: -0.2,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 10, color: kAdminTextDim),
              ),
          ],
        ),
        if (count != null) ...[
          const Spacer(),
          _CountBadge(count: count!, label: '', color: kAdminTextMuted),
        ],
      ],
    );
  }
}

/// Hero KPI card — large, prominent, used for top-level numbers.
class _HeroKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final String? subValue;
  final IconData icon;
  final Color color;

  const _HeroKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kAdminGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    delta!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: kAdminGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: kAdminText,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: kAdminTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          if (subValue != null)
            Text(
              subValue!,
              style: const TextStyle(fontSize: 10, color: kAdminTextDim),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Mini KPI card — compact, for secondary stats.
class _MiniKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final IconData icon;
  final Color color;

  const _MiniKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: kAdminText,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: kAdminTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (delta != null)
                  Text(
                    delta!,
                    style: const TextStyle(fontSize: 9, color: kAdminGreen),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small count badge (e.g. "12 users").
class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _CountBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.isEmpty
        ? '$count'
        : '$count $label${count == 1 ? '' : 's'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Unread feedback banner.
class _UnreadBanner extends StatelessWidget {
  final int count;

  const _UnreadBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kAdminAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminAccent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_rounded,
            color: kAdminAccent,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            '$count unread message${count > 1 ? 's' : ''}',
            style: const TextStyle(
              color: kAdminAccent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar fallback (unchanged) ──────────────────────────────────────────────────

class _AvatarFallback extends StatelessWidget {
  final String initial;
  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    if (initial.isEmpty) {
      return const Center(
        child: Icon(Icons.person_rounded, size: 14, color: kAdminTextMuted),
      );
    }
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: kAdminAccent,
        ),
      ),
    );
  }
}
