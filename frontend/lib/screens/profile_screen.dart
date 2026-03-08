import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/outfit_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileService profileService = ProfileService();
  final AuthService authService = AuthService();
  final StorageService storageService = StorageService();
  final OutfitService outfitService = OutfitService();

  bool _isEditing = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late Future<Map<String, dynamic>?> _profileBundleFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _profileBundleFuture = _loadProfileBundle();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileBundleFuture = _loadProfileBundle();
    });
    await _profileBundleFuture;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFDC2626)),
            SizedBox(width: 12),
            Text('Logout?'),
          ],
        ),
        content: const Text(
          'You will need to sign in again to continue using the app.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await authService.logout();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Names cannot be empty'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final Map<String, String> updatedData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await profileService.updateProfile(updatedData);

    if (!context.mounted) return;
    Navigator.pop(context);

    if (success) {
      setState(() {
        _isEditing = false;
        _profileBundleFuture = _loadProfileBundle();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile updated successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Text('Failed to update profile'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<Map<String, dynamic>?> _loadProfileBundle() async {
    final profile = await profileService.fetchProfile();
    if (profile == null) return null;

    final storages = await storageService.getAll();
    final outfits = await outfitService.getAll();

    final topLevelStorages = storages.where((s) => s['parent_storage'] == null);

    final Map<int, Map<String, dynamic>> clothesById = {};

    for (final storage in topLevelStorages) {
      final id = _asInt(storage['id']);
      if (id <= 0) continue;

      try {
        final detail = await storageService.getDetail(id);
        final clothes = List<Map<String, dynamic>>.from(
          detail['clothes'] ?? [],
        );

        for (final c in clothes) {
          final clothingId = _asInt(c['id']);
          if (clothingId > 0) clothesById[clothingId] = c;
        }
      } catch (_) {
        // skip failing storage detail requests
      }
    }

    final categoryCounts = <String, int>{};
    for (final c in clothesById.values) {
      final raw = (c['category'] ?? '').toString().trim();
      final category = raw.isEmpty ? 'Unknown' : raw;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'profile': profile,
      'total_clothes': clothesById.length,
      'total_outfits': outfits.length,
      'total_storages': topLevelStorages.length,
      'category_counts': sortedCategories,
    };
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(
    String label,
    String value,
    TextEditingController? controller,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isEditing && controller != null
            ? Colors.white
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEditing && controller != null
              ? const Color(0xFF3B82F6)
              : const Color(0xFFE5E7EB),
          width: _isEditing && controller != null ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                _isEditing && controller != null
                    ? TextField(
                        controller: controller,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return '';
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileBundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load profile',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final bundle = snapshot.data!;
          final profile = Map<String, dynamic>.from(bundle['profile'] ?? {});
          final totalClothes = _asInt(bundle['total_clothes']);
          final totalOutfits = _asInt(bundle['total_outfits']);
          final totalStorages = _asInt(bundle['total_storages']);
          final categoryCounts = List<MapEntry<String, int>>.from(
            bundle['category_counts'] ?? const <MapEntry<String, int>>[],
          );
          final topCategories = categoryCounts.take(5).toList();
          final topTotal = topCategories.fold<int>(
            0,
            (sum, e) => sum + e.value,
          );

          final chartColors = <Color>[
            const Color(0xFF3B82F6),
            const Color(0xFF8B5CF6),
            const Color(0xFFEC4899),
            const Color(0xFFF59E0B),
            const Color(0xFF10B981),
          ];

          if (!_isEditing) {
            _firstNameController.text = profile['first_name'] ?? '';
            _lastNameController.text = profile['last_name'] ?? '';
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: _refreshProfile,
              child: CustomScrollView(
                slivers: [
                  // Modern App Bar with Gradient
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: const Color(0xFF111827),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF111827), Color(0xFF1F2937)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF3B82F6),
                                            Color(0xFF8B5CF6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF3B82F6,
                                            ).withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${_initial(profile['first_name']?.toString())}${_initial(profile['last_name']?.toString())}',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            profile['email'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      if (!_isEditing)
                        IconButton(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit, color: Colors.white),
                        ),
                      IconButton(
                        onPressed: _refreshProfile,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Edit Mode Banner
                          if (_isEditing)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF3B82F6,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Edit mode active',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _isEditing = false),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Stats Cards
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                            children: [
                              _buildStatCard(
                                'Items',
                                '$totalClothes',
                                Icons.checkroom_rounded,
                                const Color(0xFF3B82F6),
                                const Color(0xFFEFF6FF),
                              ),
                              _buildStatCard(
                                'Outfits',
                                '$totalOutfits',
                                Icons.style_rounded,
                                const Color(0xFF8B5CF6),
                                const Color(0xFFF5F3FF),
                              ),
                              _buildStatCard(
                                'Storage',
                                '$totalStorages',
                                Icons.inventory_2_rounded,
                                const Color(0xFFEC4899),
                                const Color(0xFFFDF2F8),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Wardrobe Analytics
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.pie_chart_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Wardrobe Breakdown',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          'Category distribution',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                if (topCategories.isEmpty)
                                  Container(
                                    height: 200,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.pie_chart_outline,
                                          size: 64,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No clothing data yet',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Column(
                                    children: [
                                      SizedBox(
                                        height: 220,
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 60,
                                            sections: [
                                              for (
                                                int i = 0;
                                                i < topCategories.length;
                                                i++
                                              )
                                                PieChartSectionData(
                                                  value: topCategories[i].value
                                                      .toDouble(),
                                                  title: topTotal == 0
                                                      ? '0%'
                                                      : '${((topCategories[i].value * 100) / topTotal).round()}%',
                                                  color:
                                                      chartColors[i %
                                                          chartColors.length],
                                                  radius: 70,
                                                  titleStyle: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          for (
                                            int i = 0;
                                            i < topCategories.length;
                                            i++
                                          )
                                            _buildLegendItem(
                                              topCategories[i].key,
                                              topCategories[i].value,
                                              chartColors[i %
                                                  chartColors.length],
                                              topTotal == 0
                                                  ? 0
                                                  : ((topCategories[i].value *
                                                                100) /
                                                            topTotal)
                                                        .round(),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Account Information
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Account Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildInfoField(
                                  'Username',
                                  profile['username'] ?? '',
                                  null,
                                  Icons.account_circle,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoField(
                                  'Email Address',
                                  profile['email'] ?? '',
                                  null,
                                  Icons.email,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoField(
                                  'First Name',
                                  profile['first_name'] ?? '',
                                  _firstNameController,
                                  Icons.person_outline,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoField(
                                  'Last Name',
                                  profile['last_name'] ?? '',
                                  _lastNameController,
                                  Icons.person_outline,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons
                          if (_isEditing) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => _saveProfile(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _confirmLogout(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFDC2626),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                foregroundColor: const Color(0xFFDC2626),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color, int percent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '$value items • $percent%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
