import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/profile_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/services/outfit_service.dart';
import 'package:frontend/services/feedback_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ProfileScreen — Warm Editorial Light Theme
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final ProfileService profileService = ServiceRegistry.instance.profileService;
  final AuthService authService = ServiceRegistry.instance.authService;
  final StorageService storageService = ServiceRegistry.instance.storageService;
  final OutfitService outfitService = ServiceRegistry.instance.outfitService;
  final FeedbackService feedbackService = ServiceRegistry.instance.feedbackService;
  final ImagePicker _picker = ImagePicker();

  bool _isEditing = false;
  bool _uploadingAvatar = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _feedbackController;
  int? _feedbackRating;
  late Future<Map<String, dynamic>?> _profileBundleFuture;
  late AnimationController _enterCtrl;
  late AnimationController _editCtrl;
  late Animation<double> _fadeAnim;

  void _onThemeModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ThemeService.instance.themeMode.addListener(_onThemeModeChanged);
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _feedbackController = TextEditingController();
    _profileBundleFuture = _loadProfileBundle();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _editCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    ThemeService.instance.themeMode.removeListener(_onThemeModeChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _feedbackController.dispose();
    _enterCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    setState(() => _profileBundleFuture = _loadProfileBundle());
    await _profileBundleFuture;
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    _editCtrl.forward();
    HapticFeedback.lightImpact();
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
    _editCtrl.reverse();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: ProfileTokens.black.withValues(alpha: 0.38),
      builder: (_) => _LogoutDialog(),
    );
    if (shouldLogout == true) {
      await authService.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _toast('Names cannot be empty', err: true);
      return;
    }
    final updatedData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
    };
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: ProfileTokens.accent,
          strokeWidth: 2,
        ),
      ),
    );
    final success = await profileService.updateProfile(updatedData);
    if (!context.mounted) return;
    Navigator.pop(context);
    if (success) {
      setState(() {
        _isEditing = false;
        _profileBundleFuture = _loadProfileBundle();
      });
      _editCtrl.reverse();
      _toast('Profile updated');
    } else {
      _toast('Failed to update profile', err: true);
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (picked == null) return;
    await _uploadAvatar(File(picked.path));
  }

  Future<void> _uploadAvatar(File image) async {
    setState(() => _uploadingAvatar = true);
    final updated = await profileService.uploadAvatar(image);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    if (updated != null) {
      _toast('Profile photo updated');
      setState(() => _profileBundleFuture = _loadProfileBundle());
    } else {
      _toast('Failed to update photo', err: true);
    }
  }

  Future<void> _submitFeedback(BuildContext context) async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      _toast('Please write something first', err: true);
      return;
    }
    final ok = await feedbackService.submit(message, rating: _feedbackRating);
    if (!context.mounted) return;
    if (ok) {
      _feedbackController.clear();
      setState(() => _feedbackRating = null);
      _toast('Thanks for your feedback!');
    } else {
      _toast('Failed to send feedback', err: true);
    }
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              err ? Icons.warning_amber_rounded : Icons.check_rounded,
              size: 16,
              color: err ? ProfileTokens.danger : ProfileTokens.sage,
            ),
            const SizedBox(width: 10),
            Text(
              msg,
              style: const TextStyle(
                color: ProfileTokens.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: ProfileTokens.card,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ProfileTokens.rule),
        ),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
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
        for (final c in List<Map<String, dynamic>>.from(
          detail['clothes'] ?? [],
        )) {
          final cid = _asInt(c['id']);
          if (cid > 0) clothesById[cid] = c;
        }
      } catch (_) {}
    }

    final categoryCounts = <String, int>{};
    for (final c in clothesById.values) {
      final raw = (c['category'] ?? '').toString().trim();
      final cat = raw.isEmpty ? 'Unknown' : raw;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final sorted = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'profile': profile,
      'total_clothes': clothesById.length,
      'total_outfits': outfits.length,
      'total_storages': topLevelStorages.length,
      'category_counts': sorted,
    };
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

  // ── Chart colors: warm editorial palette ───────────────────────────────────
  static const _chartColors = <Color>[
    ProfileTokens.accent,
    ProfileTokens.gold,
    ProfileTokens.sage,
    ProfileTokens.rose,
    ProfileTokens.sky,
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.instance.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: ProfileTokens.cream,
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _profileBundleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: ProfileTokens.accent,
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return _ErrorView(onRetry: _refreshProfile);
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
            final topTotal = topCategories.fold<int>(0, (s, e) => s + e.value);

            if (!_isEditing) {
              _firstNameController.text = profile['first_name'] ?? '';
              _lastNameController.text = profile['last_name'] ?? '';
            }

            final firstName = profile['first_name'] ?? '';
            final lastName = profile['last_name'] ?? '';
            final email = profile['email'] ?? '';
            final username = profile['username'] ?? '';
            final avatarUrl = profile['avatar'];

            return FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: ProfileTokens.accent,
                backgroundColor: ProfileTokens.card,
                onRefresh: _refreshProfile,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Masthead header ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildHeader(
                        firstName,
                        lastName,
                        email,
                        avatarUrl,
                        context,
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Edit mode banner ─────────────────────────────
                            if (_isEditing)
                              _EditBanner(onCancel: _cancelEditing),

                            const SizedBox(height: 28),

                            // ── Stat trio ────────────────────────────────────
                            _buildStatRow(
                              totalClothes,
                              totalOutfits,
                              totalStorages,
                            ),

                            const SizedBox(height: 32),

                            // ── Wardrobe breakdown ───────────────────────────
                            _buildBreakdownCard(topCategories, topTotal),

                            const SizedBox(height: 24),

                            // ── Account info ─────────────────────────────────
                            _buildAccountCard(profile, username, email),

                            const SizedBox(height: 24),

                            // ── Feedback ─────────────────────────────────────
                            _buildFeedbackCard(context),

                            const SizedBox(height: 32),

                            // ── Save button (edit mode) ──────────────────────
                            if (_isEditing) ...[
                              _PrimaryButton(
                                label: 'Save Changes',
                                icon: Icons.check_rounded,
                                onTap: () => _saveProfile(context),
                                color: ProfileTokens.accent,
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ── Logout ───────────────────────────────────────
                            _OutlineButton(
                              label: 'Sign Out',
                              icon: Icons.logout_rounded,
                              onTap: () => _confirmLogout(context),
                              color: ProfileTokens.danger,
                            ),

                            const SizedBox(height: 52),
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
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    String firstName,
    String lastName,
    String email,
    dynamic avatarUrl,
    BuildContext context,
  ) {
    final resolvedAvatar = _resolveImageUrl(avatarUrl);
    return Container(
      color: ProfileTokens.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top safe area + action row
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 12,
              bottom: 0,
            ),
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  _IconChip(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                if (Navigator.of(context).canPop()) const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ProfileTokens.inkMuted,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                if (!_isEditing)
                  _IconChip(
                    icon: Icons.edit_outlined,
                    onTap: _startEditing,
                    tooltip: 'Edit',
                  ),
                const SizedBox(width: 8),
                _IconChip(
                  icon: Icons.refresh_rounded,
                  onTap: _refreshProfile,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Avatar + name
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: ProfileTokens.accentBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ProfileTokens.accent.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        image: resolvedAvatar.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(resolvedAvatar),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: resolvedAvatar.isNotEmpty
                          ? null
                          : Center(
                              child: Text(
                                '${_initial(firstName)}${_initial(lastName)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: ProfileTokens.accent,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: ProfileTokens.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: ProfileTokens.rule),
                            boxShadow: [
                              BoxShadow(
                                color: ProfileTokens.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _uploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ProfileTokens.accent,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 14,
                                  color: ProfileTokens.inkSub,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName'.trim().isEmpty
                            ? 'Your Name'
                            : '$firstName $lastName',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: ProfileTokens.ink,
                          letterSpacing: -0.7,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 13,
                            color: ProfileTokens.inkMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: ProfileTokens.inkMuted,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom rule
          const Divider(height: 1, thickness: 1, color: ProfileTokens.rule),
        ],
      ),
    );
  }

  // ── Stat row ───────────────────────────────────────────────────────────────

  Widget _buildStatRow(int clothes, int outfits, int storages) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            'Items',
            '$clothes',
            Icons.checkroom_rounded,
            ProfileTokens.accent,
            ProfileTokens.accentBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            'Outfits',
            '$outfits',
            Icons.style_rounded,
            ProfileTokens.gold,
            ProfileTokens.goldBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            'Storage',
            '$storages',
            Icons.inventory_2_rounded,
            ProfileTokens.sage,
            ProfileTokens.sageBg,
          ),
        ),
      ],
    );
  }

  // ── Breakdown card ─────────────────────────────────────────────────────────

  Widget _buildBreakdownCard(
    List<MapEntry<String, int>> categories,
    int total,
  ) {
    return _SectionCard(
      headerIcon: Icons.donut_large_rounded,
      headerIconBg: ProfileTokens.goldBg,
      headerIconColor: ProfileTokens.gold,
      title: 'Wardrobe Breakdown',
      subtitle: 'Your top categories',
      child: categories.isEmpty
          ? _EmptyChart()
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final chartSize = maxWidth.clamp(180.0, 240.0);
                final radius = chartSize * 0.32;
                final centerRadius = chartSize * 0.22;
                final titleSize = chartSize < 210 ? 10.0 : 12.0;

                return Column(
                  children: [
                    SizedBox.square(
                      dimension: chartSize,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: centerRadius,
                          startDegreeOffset: -90,
                          sections: [
                            for (int i = 0; i < categories.length; i++)
                              PieChartSectionData(
                                value: categories[i].value.toDouble(),
                                title: total == 0
                                    ? '0%'
                                    : '${((categories[i].value * 100) / total).round()}%',
                                color: _chartColors[i % _chartColors.length],
                                radius: radius,
                                titleStyle: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  color: ProfileTokens.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < categories.length; i++)
                          _LegendChip(
                            label: categories[i].key,
                            count: categories[i].value,
                            percent: total == 0
                                ? 0
                                : ((categories[i].value * 100) / total).round(),
                            color: _chartColors[i % _chartColors.length],
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── Account card ───────────────────────────────────────────────────────────

  Widget _buildAccountCard(
    Map<String, dynamic> profile,
    String username,
    String email,
  ) {
    return _SectionCard(
      headerIcon: Icons.person_outline_rounded,
      headerIconBg: ProfileTokens.accentBg,
      headerIconColor: ProfileTokens.accent,
      title: 'Account Information',
      subtitle: 'Your personal details',
      trailing: !_isEditing
          ? GestureDetector(
              onTap: _startEditing,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ProfileTokens.accentBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ProfileTokens.accent,
                  ),
                ),
              ),
            )
          : null,
      child: Column(
        children: [
          _InfoField(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: username,
            controller: null,
            isEditing: false,
          ),
          const SizedBox(height: 10),
          _InfoField(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email,
            controller: null,
            isEditing: false,
          ),
          const SizedBox(height: 10),
          _InfoField(
            icon: Icons.person_outline_rounded,
            label: 'First Name',
            value: profile['first_name'] ?? '',
            controller: _firstNameController,
            isEditing: _isEditing,
          ),
          const SizedBox(height: 10),
          _InfoField(
            icon: Icons.person_outline_rounded,
            label: 'Last Name',
            value: profile['last_name'] ?? '',
            controller: _lastNameController,
            isEditing: _isEditing,
          ),
        ],
      ),
    );
  }

  // ── Feedback card ──────────────────────────────────────────────────────────

  Widget _buildFeedbackCard(BuildContext context) {
    return _SectionCard(
      headerIcon: Icons.lightbulb_outline_rounded,
      headerIconBg: ProfileTokens.goldBg,
      headerIconColor: ProfileTokens.gold,
      title: 'Beta Feedback',
      subtitle: 'Help us improve Closet Buddy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _feedbackController,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 14,
              color: ProfileTokens.ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'What\'s working? What feels broken?',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: ProfileTokens.inkMuted,
              ),
              filled: true,
              fillColor: ProfileTokens.parchment,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: ProfileTokens.rule),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: ProfileTokens.rule),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: ProfileTokens.accent,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rating (optional)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ProfileTokens.inkMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final val = i + 1;
              final selected = _feedbackRating == val;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _feedbackRating = selected ? null : val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? ProfileTokens.gold
                          : ProfileTokens.parchment,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? ProfileTokens.gold
                            : ProfileTokens.rule,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? ProfileTokens.white
                              : ProfileTokens.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: 'Send Feedback',
            icon: Icons.send_rounded,
            onTap: () => _submitFeedback(context),
            color: ProfileTokens.gold,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _IconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconChip({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: ProfileTokens.parchment,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: ProfileTokens.inkSub),
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color bg;
  const _StatCard(this.label, this.value, this.icon, this.accent, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
    decoration: BoxDecoration(
      color: ProfileTokens.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ProfileTokens.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: ProfileTokens.ink,
            letterSpacing: -1.0,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ProfileTokens.inkMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData headerIcon;
  final Color headerIconBg;
  final Color headerIconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.headerIcon,
    required this.headerIconBg,
    required this.headerIconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: ProfileTokens.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ProfileTokens.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: headerIconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(headerIcon, size: 20, color: headerIconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ProfileTokens.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ProfileTokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, thickness: 1, color: ProfileTokens.rule),
        ),
        child,
      ],
    ),
  );
}

class _InfoField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextEditingController? controller;
  final bool isEditing;

  const _InfoField({
    required this.icon,
    required this.label,
    required this.value,
    required this.controller,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = isEditing && controller != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: canEdit ? ProfileTokens.accentBg : ProfileTokens.parchment,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canEdit
              ? ProfileTokens.accent.withValues(alpha: 0.4)
              : ProfileTokens.rule,
          width: canEdit ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: canEdit ? ProfileTokens.accent : ProfileTokens.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: canEdit
                        ? ProfileTokens.accent
                        : ProfileTokens.inkMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                canEdit
                    ? TextField(
                        controller: controller,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ProfileTokens.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : Text(
                        value.isEmpty ? '—' : value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: value.isEmpty
                              ? ProfileTokens.inkMuted
                              : ProfileTokens.ink,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final int count;
  final int percent;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ProfileTokens.ink,
              ),
            ),
            Text(
              '$count items · $percent%',
              style: const TextStyle(
                fontSize: 10,
                color: ProfileTokens.inkMuted,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EditBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _EditBanner({required this.onCancel});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    decoration: BoxDecoration(
      color: ProfileTokens.accentBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ProfileTokens.accent.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.edit_outlined, size: 16, color: ProfileTokens.accent),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Editing profile — tap fields to update',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ProfileTokens.accent,
            ),
          ),
        ),
        GestureDetector(
          onTap: onCancel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ProfileTokens.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ProfileTokens.accent,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: ProfileTokens.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ProfileTokens.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ProfileTokens.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 160,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.pie_chart_outline_rounded,
          size: 52,
          color: ProfileTokens.rule,
        ),
        const SizedBox(height: 12),
        const Text(
          'No clothing added yet',
          style: TextStyle(fontSize: 14, color: ProfileTokens.inkMuted),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: ProfileTokens.dangerBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            size: 32,
            color: ProfileTokens.danger,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Could not load profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ProfileTokens.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Check your connection and try again.',
          style: TextStyle(fontSize: 13, color: ProfileTokens.inkMuted),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: ProfileTokens.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ProfileTokens.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logout dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: ProfileTokens.card,
    surfaceTintColor: ProfileTokens.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: ProfileTokens.rule),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ProfileTokens.dangerBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: ProfileTokens.danger,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign out?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ProfileTokens.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You\'ll need to sign in again to access your wardrobe.',
            style: TextStyle(
              fontSize: 14,
              color: ProfileTokens.inkMuted,
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
                      color: ProfileTokens.parchment,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ProfileTokens.rule),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ProfileTokens.inkSub,
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
                      color: ProfileTokens.dangerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ProfileTokens.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ProfileTokens.danger,
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
