import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/admin_service.dart';
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
  final ProfileService _profileService = ServiceRegistry.instance.profileService;
  final AdminService _adminService = ServiceRegistry.instance.adminService;

  bool get _isDarkTheme => ThemeService.instance.isDark;

  // Controllers
  final _searchCtrl = TextEditingController();
  final _catalogSearchCtrl = TextEditingController();
  final _catalogCategoryCtrl = TextEditingController();
  final _catalogSubcategoryCtrl = TextEditingController();
  final _catalogColorCtrl = TextEditingController();
  final _catalogUserCtrl = TextEditingController();

  // Access
  bool _checkingAccess = true;
  bool _isAdmin = false;

  // Loading flags
  bool _loadingOverview = false;
  bool _loadingUsers = false;
  bool _loadingCatalog = false;
  bool _loadingOutfits = false;
  bool _loadingFeedback = false;

  // Data
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _catalogItems = [];
  List<int> _selectedCatalogIds = [];
  List<Map<String, dynamic>> _adminOutfits = [];
  List<Map<String, dynamic>> _feedback = [];
  Map<String, dynamic>? _profile;

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
      duration: const Duration(milliseconds: 500),
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
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

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
    _loadCatalog(),
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

  // ── Actions ─────────────────────────────────────────────────────────────────

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
        _DarkTextField(controller: catCtrl, label: 'Category'),
        const SizedBox(height: 10),
        _DarkTextField(controller: subCtrl, label: 'Subcategory (optional)'),
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

  Future<void> _toggleFeedbackRead(int id, bool value) async {
    final ok = await _adminService.markFeedbackRead(id, value);
    if (!mounted) return;
    if (ok) await _loadFeedback();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final avatarUrl = _resolveImageUrl(_profile?['avatar']);
    final avatarInitial = _initial(
      (_profile?['username'] ?? _profile?['first_name'] ?? '').toString(),
    );
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 12,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        color: kAdminSurface,
        border: Border(bottom: BorderSide(color: kAdminBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAdminSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAdminBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: kAdminTextMuted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Logo mark
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kAdminAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: kAdminAccent.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 15,
              color: kAdminAccent,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kAdminSurface2,
              shape: BoxShape.circle,
              border: Border.all(color: kAdminBorder),
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
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Console',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kAdminText,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Closet Buddy',
                style: TextStyle(
                  fontSize: 10,
                  color: kAdminTextDim,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: kAdminGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAdminGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
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
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await ThemeService.instance.toggle();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAdminSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAdminBorder),
              ),
              child: Icon(
                _isDarkTheme
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 18,
                color: kAdminTextMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await _refreshAll();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAdminSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAdminBorder),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: kAdminTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab strip ────────────────────────────────────────────────────────────────

  Widget _buildTabStrip() {
    return Container(
      height: 44,
      color: kAdminSurface,
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: kAdminAccent,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: kAdminAccent,
        unselectedLabelColor: kAdminTextMuted,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: _tabs
            .map(
              (t) => Tab(
                height: 44,
                child: Row(
                  children: [
                    Icon(t.icon, size: 14),
                    const SizedBox(width: 6),
                    Text(t.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Overview tab — REDESIGNED ─────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    if (_loadingOverview && _dashboard == null) {
      return _loadingCenter();
    }
    if (_dashboard == null) {
      return _errorCenter(_loadDashboard);
    }

    final overview = _map(_dashboard!['overview']);
    final last7 = _map(_dashboard!['last_7_days']);
    final engagement = _map(_dashboard!['engagement']);
    final outfitStats = _map(_dashboard!['outfit_stats']);
    final slotCoverage = _map(_dashboard!['slot_coverage']);
    final topCategories = _list(_dashboard!['top_categories']);
    final topColors = _list(_dashboard!['top_colors']);
    final recentUsers = _list(_dashboard!['recent_users']);

    // Build slot data for ring chart
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── KPI ticker row ─────────────────────────────────────────────────
          _AdminSectionLabel('Platform Totals'),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _KpiCard(
                  label: 'Users',
                  value: '${overview['total_users'] ?? 0}',
                  delta: '+${last7['new_users'] ?? 0}',
                  color: kAdminBlue,
                ),
                _KpiCard(
                  label: 'Active',
                  value: '${overview['active_users'] ?? 0}',
                  color: kAdminGreen,
                ),
                _KpiCard(
                  label: 'Items',
                  value: '${overview['total_clothing_items'] ?? 0}',
                  delta: '+${last7['new_clothing'] ?? 0}',
                  color: kAdminAccent,
                ),
                _KpiCard(
                  label: 'Outfits',
                  value: '${overview['total_outfits'] ?? 0}',
                  delta: '+${last7['new_outfits'] ?? 0}',
                  color: kAdminYellow,
                ),
                _KpiCard(
                  label: 'Acc',
                  value: '${overview['total_accessories'] ?? 0}',
                  delta: '+${last7['new_accessories'] ?? 0}',
                  color: kAdminRed,
                ),
                _KpiCard(
                  label: 'Storages',
                  value: '${overview['total_storages'] ?? 0}',
                  color: kAdminTextMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Engagement row ─────────────────────────────────────────────────
          _AdminSectionLabel('Engagement'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _EngagementGauge(
                  label: 'DAU',
                  value: _toDouble(engagement['dau']),
                  max: _toDouble(
                    overview['active_users'],
                  ).clamp(1, double.infinity),
                  color: kAdminBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EngagementGauge(
                  label: 'WAU',
                  value: _toDouble(engagement['wau']),
                  max: _toDouble(
                    overview['active_users'],
                  ).clamp(1, double.infinity),
                  color: kAdminGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Sessions/user',
                  value: '${engagement['sessions_per_user'] ?? '-'}',
                  icon: Icons.repeat_rounded,
                  color: kAdminAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Avg session',
                  value: '${engagement['average_session_seconds'] ?? '-'}s',
                  icon: Icons.timer_outlined,
                  color: kAdminYellow,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Outfit quality + slot ring ─────────────────────────────────────
          _AdminSectionLabel('Outfit Analytics'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slot ring chart
              Expanded(flex: 5, child: _SlotRingChart(data: slotData)),
              const SizedBox(width: 12),
              // Rating + fav stacked
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _RatingMeter(
                      rating: _toDouble(outfitStats['average_rating']),
                      max: 5.0,
                    ),
                    const SizedBox(height: 10),
                    _StatBlock2(
                      label: 'Favourite rate',
                      value: '${outfitStats['favourite_rate'] ?? '-'}%',
                      icon: Icons.favorite_rounded,
                      color: kAdminRed,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Top categories horizontal bar ──────────────────────────────────
          _AdminSectionLabel('Top Categories'),
          const SizedBox(height: 10),
          _HorizontalBarChart(
            rows: topCategories,
            labelKey: 'category',
            valueKey: 'total',
            color: kAdminBlue,
          ),

          const SizedBox(height: 24),

          // ── Color distribution ─────────────────────────────────────────────
          _AdminSectionLabel('Color Distribution'),
          const SizedBox(height: 10),
          _ColorSwatchChart(rows: topColors),

          const SizedBox(height: 24),

          // ── Recent sign-ups ────────────────────────────────────────────────
          _AdminSectionLabel('Recent Sign-ups'),
          const SizedBox(height: 10),
          ...recentUsers.map((u) => _RecentUserRow(user: u)),
        ],
      ),
    );
  }

  // ── Users tab ────────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return Column(
      children: [
        _SearchBar(
          controller: _searchCtrl,
          hint: 'Search by name or email…',
          onSearch: _loadUsers,
        ),
        // User count strip
        if (_users.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kAdminBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: kAdminBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '${_users.length} users',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kAdminBlue,
                    ),
                  ),
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

  // ── Catalog tab ──────────────────────────────────────────────────────────────

  Widget _buildCatalogTab() {
    return Column(
      children: [
        _SearchBar(
          controller: _catalogSearchCtrl,
          hint: 'Search catalog…',
          onSearch: _loadCatalog,
          trailing: _DarkChipButton(
            label: 'Filters',
            icon: Icons.tune_rounded,
            onTap: _showCatalogFilters,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedCatalogIds.isEmpty
                      ? kAdminSurface2
                      : kAdminAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedCatalogIds.isEmpty
                        ? kAdminBorder
                        : kAdminAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _selectedCatalogIds.isEmpty
                      ? 'Tap to select items'
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
            onRefresh: _loadCatalog,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: _loadingCatalog && _catalogItems.isEmpty
                ? _loadingCenter()
                : _catalogItems.isEmpty
                ? _emptyCenter('No items found', Icons.checkroom_rounded)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _catalogItems.length,
                    itemBuilder: (_, i) {
                      final item = _catalogItems[i];
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

  // ── Outfits tab ──────────────────────────────────────────────────────────────

  Widget _buildOutfitsTab() {
    return RefreshIndicator(
      onRefresh: _loadOutfits,
      color: kAdminAccent,
      backgroundColor: kAdminSurface,
      child: _loadingOutfits && _adminOutfits.isEmpty
          ? _loadingCenter()
          : _adminOutfits.isEmpty
          ? _emptyCenter('No outfits saved yet', Icons.style_rounded)
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1200
                    ? 4
                    : width >= 900
                    ? 3
                    : width >= 600
                    ? 2
                    : 1;
                final childAspectRatio = width >= 900 ? 1.4 : 1.2;

                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: _adminOutfits.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (_, i) =>
                      _OutfitGridCard(outfit: _adminOutfits[i]),
                );
              },
            ),
    );
  }

  // ── Feedback tab ─────────────────────────────────────────────────────────────

  Widget _buildFeedbackTab() {
    final unread = _feedback.where((f) => f['is_read'] != true).length;
    return Column(
      children: [
        if (unread > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kAdminAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAdminAccent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_rounded,
                  color: kAdminAccent,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  '$unread unread message${unread > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: kAdminAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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

  Widget _loadingCenter() {
    return Center(
      child: CircularProgressIndicator(color: kAdminAccent, strokeWidth: 2),
    );
  }

  Widget _errorCenter(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kAdminSurface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: kAdminTextDim,
              size: 28,
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
          const SizedBox(height: 10),
          _DarkButton(label: 'Retry', onTap: onRetry),
        ],
      ),
    );
  }

  // ── Access denied ────────────────────────────────────────────────────────────

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

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _emptyCenter(String label, IconData icon) => Center(
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
          child: Icon(icon, color: kAdminTextDim, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: kAdminTextMuted, fontSize: 14),
        ),
      ],
    ),
  );

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
        _DarkTextField(controller: _catalogCategoryCtrl, label: 'Category'),
        const SizedBox(height: 10),
        _DarkTextField(
          controller: _catalogSubcategoryCtrl,
          label: 'Subcategory',
        ),
        const SizedBox(height: 10),
        _DarkTextField(controller: _catalogColorCtrl, label: 'Dominant color'),
        const SizedBox(height: 10),
        _DarkTextField(controller: _catalogUserCtrl, label: 'User ID'),
      ],
      confirmLabel: 'Apply',
    );
    if (confirmed == true) await _loadCatalog();
  }

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

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initial;
  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    if (initial.isEmpty) {
      return const Center(
        child: Icon(Icons.person_rounded, size: 16, color: kAdminTextMuted),
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
