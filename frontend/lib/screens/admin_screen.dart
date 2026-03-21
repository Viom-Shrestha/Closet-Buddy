library admin_screen;

import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/profile_service.dart';
import '../widgets/admin/admin_theme.dart';
import '../widgets/outfit_canvas.dart';
import 'admin_user_detail_screen.dart';

part '../widgets/admin/admin_screen_components.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final AdminService _adminService = AdminService();

  // Controllers
  final _searchCtrl = TextEditingController();
  final _catalogSearchCtrl = TextEditingController();
  final _catalogCategoryCtrl = TextEditingController();
  final _catalogSubcategoryCtrl = TextEditingController();
  final _catalogColorCtrl = TextEditingController();
  final _catalogUserCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();

  // Access
  bool _checkingAccess = true;
  bool _isAdmin = false;

  // Loading flags
  bool _loadingOverview = false;
  bool _loadingUsers = false;
  bool _loadingCatalog = false;
  bool _loadingOutfits = false;
  bool _loadingFeedback = false;
  bool _loadingInvites = false;

  // Data
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _catalogItems = [];
  List<int> _selectedCatalogIds = [];
  List<Map<String, dynamic>> _adminOutfits = [];
  List<Map<String, dynamic>> _feedback = [];
  List<Map<String, dynamic>> _invites = [];

  // Navigation
  late final TabController _tabCtrl;

  static const _tabs = [
    AdminTabMeta(Icons.dashboard_rounded, 'Overview'),
    AdminTabMeta(Icons.group_rounded, 'Users'),
    AdminTabMeta(Icons.checkroom_rounded, 'Catalog'),
    AdminTabMeta(Icons.style_rounded, 'Outfits'),
    AdminTabMeta(Icons.forum_rounded, 'Feedback'),
    AdminTabMeta(Icons.alternate_email_rounded, 'Invites'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _catalogSearchCtrl.dispose();
    _catalogCategoryCtrl.dispose();
    _catalogSubcategoryCtrl.dispose();
    _catalogColorCtrl.dispose();
    _catalogUserCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  // ------------------------------

  Future<void> _bootstrap() async {
    final profile = await _profileService.fetchProfile();
    if (!mounted) return;
    final isAdmin = (profile?['role'] ?? '').toString() == 'admin';
    setState(() {
      _checkingAccess = false;
      _isAdmin = isAdmin;
    });
    if (!isAdmin) return;
    await _refreshAll();
  }

  Future<void> _refreshAll() => Future.wait([
    _loadDashboard(),
    _loadUsers(),
    _loadCatalog(),
    _loadOutfits(),
    _loadFeedback(),
    _loadInvites(),
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

  Future<void> _loadInvites() async {
    setState(() => _loadingInvites = true);
    final data = await _adminService.fetchInvites();
    if (!mounted) return;
    setState(() {
      _invites = data;
      _loadingInvites = false;
    });
  }

  // ------------------------------

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
    final confirmed = await _showDarkDialog(
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

  Future<void> _addInvite() async {
    final email = _inviteCtrl.text.trim();
    if (email.isEmpty) return;
    final ok = await _adminService.addInvite(email);
    if (!mounted) return;
    if (ok) {
      _inviteCtrl.clear();
      await _loadInvites();
    }
    _snack(
      ok ? 'Invite added' : 'Failed to add invite',
      ok ? kAdminGreen : kAdminRed,
    );
  }

  Future<void> _deleteInvite(int id) async {
    final ok = await _adminService.deleteInvite(id);
    if (!mounted) return;
    if (ok) await _loadInvites();
    _snack(
      ok ? 'Invite removed' : 'Delete failed',
      ok ? kAdminGreen : kAdminRed,
    );
  }

  Future<void> _toggleFeedbackRead(int id, bool value) async {
    final ok = await _adminService.markFeedbackRead(id, value);
    if (!mounted) return;
    if (ok) await _loadFeedback();
  }

  // ------------------------------

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: kAdminBg,
        body: Center(child: CircularProgressIndicator(color: kAdminAccent)),
      );
    }

    if (!_isAdmin) return _buildAccessDenied();

    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        backgroundColor: kAdminBg,
        body: Column(
          children: [
            _AdminTopBar(
              onBack: () => Navigator.of(context).maybePop(),
              onRefresh: _refreshAll,
              tabCtrl: _tabCtrl,
              tabs: _tabs,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildOverviewTab(),
                  _buildUsersTab(),
                  _buildCatalogTab(),
                  _buildOutfitsTab(),
                  _buildFeedbackTab(),
                  _buildInvitesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: kAdminBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kAdminRedDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_rounded, color: kAdminRed, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Admin Only',
              style: TextStyle(
                color: kAdminText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have permission to access this area.',
              style: TextStyle(color: kAdminTextMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _DarkButton(label: 'Go back', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  // ------------------------------

  Widget _buildOverviewTab() {
    if (_loadingOverview && _dashboard == null) {
      return _scrollableState(
        const CircularProgressIndicator(color: kAdminAccent),
      );
    }
    if (_dashboard == null) {
      return _scrollableState(
        _DarkButton(label: 'Retry', onTap: _loadDashboard),
      );
    }

    final overview = _map(_dashboard!['overview']);
    final last7 = _map(_dashboard!['last_7_days']);
    final engagement = _map(_dashboard!['engagement']);
    final outfitStats = _map(_dashboard!['outfit_stats']);
    final slotCoverage = _map(_dashboard!['slot_coverage']);
    final topCategories = _list(_dashboard!['top_categories']);
    final topColors = _list(_dashboard!['top_colors']);
    final recentUsers = _list(_dashboard!['recent_users']);

    final slotRows = [
      {'label': 'Topwear', 'total': slotCoverage['topwear_percent'] ?? 0},
      {'label': 'Bottomwear', 'total': slotCoverage['bottomwear_percent'] ?? 0},
      {'label': 'Shoes', 'total': slotCoverage['shoes_percent'] ?? 0},
      {'label': 'Outerwear', 'total': slotCoverage['outerwear_percent'] ?? 0},
      {
        'label': 'Accessories',
        'total': slotCoverage['accessories_percent'] ?? 0,
      },
    ];

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: kAdminAccent,
      backgroundColor: kAdminSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ------------------------------
          _SectionLabel(label: 'Platform totals'),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              _BigMetric(
                label: 'Total users',
                value: '${overview['total_users'] ?? 0}',
                accent: kAdminBlue,
              ),
              _BigMetric(
                label: 'Active users',
                value: '${overview['active_users'] ?? 0}',
                accent: kAdminGreen,
              ),
              _BigMetric(
                label: 'Clothing items',
                value: '${overview['total_clothing_items'] ?? 0}',
                accent: kAdminAccent,
              ),
              _BigMetric(
                label: 'Outfits saved',
                value: '${overview['total_outfits'] ?? 0}',
                accent: kAdminAccent,
              ),
              _BigMetric(
                label: 'Accessories',
                value: '${overview['total_accessories'] ?? 0}',
                accent: kAdminTextMuted,
              ),
              _BigMetric(
                label: 'Storages',
                value: '${overview['total_storages'] ?? 0}',
                accent: kAdminTextMuted,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ------------------------------
          _SectionLabel(label: 'Last 7 days', badge: 'NEW'),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              _SmallMetric(
                label: 'New users',
                value: '${last7['new_users'] ?? 0}',
                delta: true,
              ),
              _SmallMetric(
                label: 'New clothing',
                value: '${last7['new_clothing'] ?? 0}',
                delta: true,
              ),
              _SmallMetric(
                label: 'New outfits',
                value: '${last7['new_outfits'] ?? 0}',
                delta: true,
              ),
              _SmallMetric(
                label: 'Accessories',
                value: '${last7['new_accessories'] ?? 0}',
                delta: true,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ------------------------------
          _SectionLabel(label: 'Engagement'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EngagementCard(
                  label: 'DAU',
                  value: '${engagement['dau'] ?? 0}',
                  subLabel: 'Daily active',
                  icon: Icons.person_outline_rounded,
                  color: kAdminBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EngagementCard(
                  label: 'WAU',
                  value: '${engagement['wau'] ?? 0}',
                  subLabel: 'Weekly active',
                  icon: Icons.people_outline_rounded,
                  color: kAdminGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EngagementCard(
                  label: 'Sessions / user',
                  value: '${engagement['sessions_per_user'] ?? '-'}',
                  subLabel: 'Weekly',
                  icon: Icons.repeat_rounded,
                  color: kAdminAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EngagementCard(
                  label: 'Avg session',
                  value: '${engagement['average_session_seconds'] ?? '-'}s',
                  subLabel: 'Duration',
                  icon: Icons.timer_outlined,
                  color: kAdminTextMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ------------------------------
          _SectionLabel(label: 'Outfit quality'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Avg rating',
                  value:
                      outfitStats['average_rating']?.toStringAsFixed(1) ?? '-',
                  unit: '/ 5',
                  color: kAdminAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBlock(
                  label: 'Favourite rate',
                  value: '${outfitStats['favourite_rate'] ?? '-'}',
                  unit: '%',
                  color: kAdminRed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ------------------------------
          _SectionLabel(label: 'Slot coverage'),
          const SizedBox(height: 12),
          _BarChart(rows: slotRows, labelKey: 'label', color: kAdminGreen),

          const SizedBox(height: 20),
          _SectionLabel(label: 'Top categories'),
          const SizedBox(height: 12),
          _BarChart(
            rows: topCategories,
            labelKey: 'category',
            color: kAdminBlue,
          ),

          const SizedBox(height: 20),
          _SectionLabel(label: 'Top colors'),
          const SizedBox(height: 12),
          _ColorBarChart(rows: topColors),

          const SizedBox(height: 28),

          // ------------------------------
          _SectionLabel(label: 'Recent sign-ups'),
          const SizedBox(height: 12),
          ...recentUsers.map((u) => _RecentUserRow(user: u)),
        ],
      ),
    );
  }

  // ------------------------------

  Widget _buildUsersTab() {
    return Column(
      children: [
        _SearchBar(
          controller: _searchCtrl,
          hint: 'Search by name or email...',
          onSearch: _loadUsers,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: _loadingUsers && _users.isEmpty
                ? _scrollableState(
                    const CircularProgressIndicator(color: kAdminAccent),
                  )
                : _users.isEmpty
                ? _scrollableState(
                    _emptyState('No users found', Icons.group_off_rounded),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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

  // ------------------------------

  Widget _buildCatalogTab() {
    return Column(
      children: [
        _SearchBar(
          controller: _catalogSearchCtrl,
          hint: 'Search catalog...',
          onSearch: _loadCatalog,
          trailing: _DarkChipButton(
            label: 'Filters',
            icon: Icons.tune_rounded,
            onTap: _showCatalogFilters,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Text(
                _selectedCatalogIds.isEmpty
                    ? 'Tap items to select'
                    : '${_selectedCatalogIds.length} selected',
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedCatalogIds.isEmpty
                      ? kAdminTextDim
                      : kAdminAccent,
                  fontWeight: FontWeight.w600,
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
                ? _scrollableState(
                    const CircularProgressIndicator(color: kAdminAccent),
                  )
                : _catalogItems.isEmpty
                ? _scrollableState(
                    _emptyState('No items found', Icons.checkroom_rounded),
                  )
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

  // ------------------------------

  Widget _buildOutfitsTab() {
    return RefreshIndicator(
      onRefresh: _loadOutfits,
      color: kAdminAccent,
      backgroundColor: kAdminSurface,
      child: _loadingOutfits && _adminOutfits.isEmpty
          ? _scrollableState(
              const CircularProgressIndicator(color: kAdminAccent),
            )
          : _adminOutfits.isEmpty
          ? _scrollableState(
              _emptyState('No outfits saved yet', Icons.style_rounded),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _adminOutfits.length,
              itemBuilder: (_, i) => _OutfitRow(outfit: _adminOutfits[i]),
            ),
    );
  }

  // ------------------------------

  Widget _buildFeedbackTab() {
    final unread = _feedback.where((f) => f['is_read'] != true).length;
    return Column(
      children: [
        if (unread > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kAdminAccentDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAdminAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_rounded,
                  color: kAdminAccent,
                  size: 16,
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
                ? _scrollableState(
                    const CircularProgressIndicator(color: kAdminAccent),
                  )
                : _feedback.isEmpty
                ? _scrollableState(
                    _emptyState('No feedback yet', Icons.forum_rounded),
                  )
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

  // ------------------------------

  Widget _buildInvitesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _DarkTextField(
                  controller: _inviteCtrl,
                  label: 'Email address',
                  hint: 'user@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 10),
              _DarkButton(label: 'Add', onTap: _addInvite, compact: true),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadInvites,
            color: kAdminAccent,
            backgroundColor: kAdminSurface,
            child: _loadingInvites && _invites.isEmpty
                ? _scrollableState(
                    const CircularProgressIndicator(color: kAdminAccent),
                  )
                : _invites.isEmpty
                ? _scrollableState(
                    _emptyState(
                      'No invites yet',
                      Icons.alternate_email_rounded,
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _invites.length,
                    itemBuilder: (_, i) {
                      final invite = _invites[i];
                      final id = _asInt(invite['id']);
                      return _InviteRow(
                        invite: invite,
                        onDelete: id == null ? null : () => _deleteInvite(id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ------------------------------

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: kAdminText)),
        backgroundColor: kAdminSurface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
      ),
    );
  }

  Future<bool?> _showDarkDialog({
    required String title,
    String? subtitle,
    required List<Widget> children,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: _darkTheme(),
        child: AlertDialog(
          backgroundColor: kAdminSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kAdminBorder),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kAdminText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(color: kAdminTextMuted, fontSize: 12),
                ),
            ],
          ),
          content: Column(mainAxisSize: MainAxisSize.min, children: children),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: kAdminTextMuted),
              ),
            ),
            _DarkButton(
              label: confirmLabel,
              onTap: () => Navigator.pop(ctx, true),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCatalogFilters() async {
    final confirmed = await _showDarkDialog(
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

  Widget _emptyState(String label, IconData icon) {
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
            child: Icon(icon, color: kAdminTextDim, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(color: kAdminTextMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _scrollableState(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const SizedBox(height: 120),
        Center(child: child),
      ],
    );
  }

  ThemeData _darkTheme() => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: kAdminBg,
    colorScheme: const ColorScheme.dark(
      primary: kAdminAccent,
      surface: kAdminSurface,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
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
}
