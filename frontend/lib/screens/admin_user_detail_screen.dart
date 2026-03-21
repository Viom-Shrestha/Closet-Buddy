import 'package:flutter/material.dart';

import '../services/admin_service.dart';

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

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _loading = true;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _clothing = [];
  List<Map<String, dynamic>> _outfits = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final summary = await _adminService.fetchUserSummary(widget.userId);
    final clothing = await _adminService.fetchUserClothing(userId: widget.userId);
    final outfits = await _adminService.fetchUserOutfits(userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _clothing = List<Map<String, dynamic>>.from(clothing['results'] ?? []);
      _outfits = List<Map<String, dynamic>>.from(outfits['results'] ?? []);
      _loading = false;
    });
  }

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$mm/$dd/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _sectionTitle('Wardrobe categories'),
                      const SizedBox(height: 8),
                      _buildCategoryChips(),
                      const SizedBox(height: 16),
                      _sectionTitle('Clothing items'),
                      const SizedBox(height: 8),
                      _buildClothingList(),
                      const SizedBox(height: 16),
                      _sectionTitle('Saved outfits'),
                      const SizedBox(height: 8),
                      _buildOutfitsList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final user = Map<String, dynamic>.from(_summary?['user'] ?? {});
    final counts = Map<String, dynamic>.from(_summary?['counts'] ?? {});

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (user['email'] ?? '').toString(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _pill('Joined ${_shortDate(user['date_joined']?.toString())}'),
                _pill(
                  'Last active ${_shortDate(user['last_active_at']?.toString())}',
                ),
                _pill('Clothing ${counts['clothing'] ?? 0}'),
                _pill('Accessories ${counts['accessories'] ?? 0}'),
                _pill('Outfits ${counts['outfits'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = List<Map<String, dynamic>>.from(
      _summary?['category_counts'] ?? const [],
    );
    if (categories.isEmpty) {
      return const Text('No wardrobe data yet.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map(
            (row) => _pill(
              '${row['category'] ?? 'Unknown'} • ${row['total'] ?? 0}',
            ),
          )
          .toList(),
    );
  }

  Widget _buildClothingList() {
    if (_clothing.isEmpty) {
      return const Text('No clothing items yet.');
    }

    return Column(
      children: _clothing.map((item) {
        final image = (item['image'] ?? '').toString();
        final title = '${item['subcategory'] ?? 'Item'}';
        final subtitle = '${item['category'] ?? ''}';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: image.isEmpty
                ? const CircleAvatar(child: Icon(Icons.checkroom))
                : CircleAvatar(backgroundImage: NetworkImage(image)),
            title: Text(title),
            subtitle: Text(subtitle),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutfitsList() {
    if (_outfits.isEmpty) {
      return const Text('No outfits yet.');
    }

    return Column(
      children: _outfits.map((outfit) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.style)),
            title: Text((outfit['name'] ?? 'Outfit').toString()),
            subtitle: Text((outfit['occasion'] ?? 'No occasion').toString()),
            trailing: Text(
              (outfit['rating'] ?? '-').toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
