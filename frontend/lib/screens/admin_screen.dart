import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/profile_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ProfileService _profileService = ProfileService();
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  bool _checkingAccess = true;
  bool _isAdmin = false;

  bool _loadingOverview = false;
  bool _loadingUsers = false;
  bool _loadingActivity = false;

  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final profile = await _profileService.fetchProfile();
    if (!mounted) return;

    final isAdmin = (profile?['role'] ?? '').toString() == 'admin';
    if (!isAdmin) {
      setState(() {
        _checkingAccess = false;
        _isAdmin = false;
      });
      return;
    }

    setState(() {
      _checkingAccess = false;
      _isAdmin = true;
    });

    await Future.wait([_loadDashboard(), _loadUsers(), _loadActivity()]);
  }

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
    final data = await _adminService.fetchUsers(query: _searchController.text);
    if (!mounted) return;
    setState(() {
      _users = data;
      _loadingUsers = false;
    });
  }

  Future<void> _loadActivity() async {
    setState(() => _loadingActivity = true);
    final data = await _adminService.fetchActivity();
    if (!mounted) return;
    setState(() {
      _activity = data;
      _loadingActivity = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadDashboard(), _loadUsers(), _loadActivity()]);
  }

  Future<void> _setUserActive(Map<String, dynamic> user, bool next) async {
    final id = _asInt(user['id']);
    if (id == null) return;

    final ok = await _adminService.setUserActive(id, next);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (next ? 'User activated' : 'User deactivated')
              : 'Failed to update user status',
        ),
      ),
    );

    if (ok) {
      await Future.wait([_loadUsers(), _loadDashboard()]);
    }
  }

  Future<void> _setUserStaff(Map<String, dynamic> user, bool next) async {
    final id = _asInt(user['id']);
    if (id == null) return;

    final ok = await _adminService.setUserStaff(id, next);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (next ? 'User promoted to admin' : 'Admin role removed')
              : 'Failed to update user role',
        ),
      ),
    );

    if (ok) {
      await Future.wait([_loadUsers(), _loadDashboard()]);
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Admin access only',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account does not have permission to open the admin dashboard.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.group_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.timeline_outlined), text: 'Activity'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildUsersTab(),
            _buildActivityTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_loadingOverview && _dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dashboard == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadDashboard,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry loading dashboard'),
        ),
      );
    }

    final overview = Map<String, dynamic>.from(_dashboard?['overview'] ?? {});
    final last7 = Map<String, dynamic>.from(_dashboard?['last_7_days'] ?? {});
    final topCategories = (_dashboard?['top_categories'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final topColors = (_dashboard?['top_colors'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final storageTypes = (_dashboard?['storage_types'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final recentUsers = (_dashboard?['recent_users'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Platform totals'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard('Users', overview['total_users']),
              _metricCard('Admins', overview['admin_users']),
              _metricCard('Active users', overview['active_users']),
              _metricCard('Storages', overview['total_storages']),
              _metricCard('Clothing', overview['total_clothing_items']),
              _metricCard('Accessories', overview['total_accessories']),
              _metricCard('Other items', overview['total_non_clothing']),
              _metricCard('Outfits', overview['total_outfits']),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle('Last 7 days'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard('New users', last7['new_users']),
              _metricCard('New storages', last7['new_storages']),
              _metricCard('New clothing', last7['new_clothing']),
              _metricCard('New accessories', last7['new_accessories']),
              _metricCard('New other items', last7['new_non_clothing']),
              _metricCard('New outfits', last7['new_outfits']),
            ],
          ),
          const SizedBox(height: 18),
          _rankedSection(
            title: 'Top clothing categories',
            rows: topCategories,
            labelKey: 'category',
          ),
          const SizedBox(height: 14),
          _rankedSection(
            title: 'Top clothing colors',
            rows: topColors,
            labelKey: 'dominant_color',
          ),
          const SizedBox(height: 14),
          _rankedSection(
            title: 'Storage type distribution',
            rows: storageTypes,
            labelKey: 'type',
          ),
          const SizedBox(height: 14),
          _sectionTitle('Recent users'),
          const SizedBox(height: 8),
          ...recentUsers.map(
            (user) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    _initialChar((user['username'] ?? '').toString()),
                  ),
                ),
                title: Text((user['username'] ?? 'User').toString()),
                subtitle: Text((user['email'] ?? '').toString()),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    _tinyBadge('C ${user['clothing_count'] ?? 0}'),
                    _tinyBadge('O ${user['outfit_count'] ?? 0}'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadUsers(),
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _loadUsers, child: const Text('Search')),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            child: _loadingUsers && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 160),
                      Center(child: Text('No users found')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isStaff = user['is_staff'] == true;
                      final isActive = user['is_active'] == true;
                      final canEdit = user['can_edit'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      _initialChar(
                                        (user['username'] ?? '').toString(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (user['username'] ?? 'User')
                                              .toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          (user['email'] ?? '').toString(),
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _tinyBadge(isStaff ? 'Admin' : 'User'),
                                  const SizedBox(width: 6),
                                  _tinyBadge(
                                    isActive ? 'Active' : 'Inactive',
                                    color: isActive
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _tinyBadge(
                                    'Clothing ${user['clothing_count'] ?? 0}',
                                  ),
                                  _tinyBadge(
                                    'Accessories ${user['accessory_count'] ?? 0}',
                                  ),
                                  _tinyBadge(
                                    'Outfits ${user['outfit_count'] ?? 0}',
                                  ),
                                  _tinyBadge(
                                    'Storages ${user['storage_count'] ?? 0}',
                                  ),
                                ],
                              ),
                              if (canEdit) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () =>
                                          _setUserActive(user, !isActive),
                                      child: Text(
                                        isActive ? 'Deactivate' : 'Activate',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _setUserStaff(user, !isStaff),
                                      child: Text(
                                        isStaff ? 'Remove admin' : 'Make admin',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    return RefreshIndicator(
      onRefresh: _loadActivity,
      child: _loadingActivity && _activity.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _activity.isEmpty
          ? ListView(
              children: [
                SizedBox(height: 160),
                Center(child: Text('No activity yet')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              itemCount: _activity.length,
              itemBuilder: (context, index) {
                final event = _activity[index];
                final type = (event['type'] ?? '').toString();
                final icon = _activityIcon(type);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(icon, size: 18)),
                    title: Text((event['title'] ?? '').toString()),
                    subtitle: Text(
                      '${(event['subtitle'] ?? '').toString()} - ${(event['username'] ?? '').toString()}',
                    ),
                    trailing: Text(
                      _shortDate((event['created_at'] ?? '').toString()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _metricCard(String label, dynamic value) {
    return Container(
      width: 162,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
  }

  Widget _rankedSection({
    required String title,
    required List<Map<String, dynamic>> rows,
    required String labelKey,
  }) {
    final int max = rows.isEmpty
        ? 1
        : rows
              .map((e) => _asInt(e['total']) ?? 0)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 1000000)
              .toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text(
              'No data yet',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else
            ...rows.map((row) {
              final label = (row[labelKey] ?? 'Unknown').toString();
              final total = _asInt(row['total']) ?? 0;
              final double factor = max <= 0 ? 0.0 : total / max;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(label)),
                        Text('$total'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: factor,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _tinyBadge(String text, {Color color = const Color(0xFFF3F4F6)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'user_signup':
        return Icons.person_add_alt_1;
      case 'clothing_upload':
        return Icons.checkroom_outlined;
      case 'accessory_upload':
        return Icons.watch_outlined;
      case 'outfit_saved':
        return Icons.auto_awesome_outlined;
      case 'storage_created':
        return Icons.inventory_2_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  String _initialChar(String text) {
    if (text.isEmpty) return '?';
    return text.substring(0, 1).toUpperCase();
  }
}
