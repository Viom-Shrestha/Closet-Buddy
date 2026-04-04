import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/widgets/hover_clickable.dart';
import 'package:frontend/services/profile_service.dart';
import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/services/outfit_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/widgets/editable_outfit_canvas.dart';
import 'package:frontend/widgets/outfit_canvas.dart';
import 'package:frontend/widgets/app_logo.dart';

import 'package:frontend/features/home/screens/add_item_screen.dart';
import 'package:frontend/features/admin/screens/admin_screen.dart';
import 'package:frontend/features/wardrobe/screens/clothing_detail_screen.dart';
import 'package:frontend/features/outfit/screens/outfit_screen.dart';
import 'package:frontend/features/profile/screens/profile_screen.dart';
import 'package:frontend/features/recommendation/screens/recommendation_screen.dart';
import 'package:frontend/features/storage/screens/storage_space_screen.dart';
import 'package:frontend/features/wardrobe/screens/wardrobe_screen.dart';
import 'package:frontend/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HomeScreen — Warm Editorial Light
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final String? startupMessage;

  const HomeScreen({super.key, this.startupMessage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ProfileService profileService = ServiceRegistry.instance.profileService;
  final StorageService storageService = ServiceRegistry.instance.storageService;
  final ClothingService clothingService =
      ServiceRegistry.instance.clothingService;
  final OutfitService outfitService = ServiceRegistry.instance.outfitService;

  List<Map<String, dynamic>> storages = [];
  List<Map<String, dynamic>> recentClothes = [];
  List<Map<String, dynamic>> outfits = [];
  bool loadingHome = true;

  String role = 'user';
  Map<String, dynamic>? _profile;
  int _selectedIndex = 0;
  bool _wardrobeSelecting = false;

  Map<String, dynamic>? weatherData;
  bool isLoadingWeather = true;
  Map<String, dynamic>? _todayOutfit;
  final Random _rng = Random();
  int _themeRefreshRevision = 0;

  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  void _onThemeModeChanged() {
    if (!mounted) return;
    setState(() => _themeRefreshRevision++);
    _enterCtrl.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    ThemeService.instance.themeMode.addListener(_onThemeModeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = widget.startupMessage?.trim();
      if (message != null && message.isNotEmpty) {
        _toast(message);
      }
    });
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    fetchUserRole();
    fetchWeather();
    fetchHomeData();
  }

  @override
  void dispose() {
    ThemeService.instance.themeMode.removeListener(_onThemeModeChanged);
    _enterCtrl.dispose();
    super.dispose();
  }

  void _handleAddItemResult(dynamic result) {
    if (result == true) {
      fetchHomeData();
      _toast('Item added successfully');
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
              color: err ? HomeTokens.accent : HomeTokens.sage,
            ),
            const SizedBox(width: 10),
            Text(
              msg,
              style: const TextStyle(
                color: HomeTokens.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: HomeTokens.card,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: HomeTokens.rule),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> fetchUserRole() async {
    final p = await profileService.fetchProfile();
    if (!mounted) return;
    setState(() {
      role = (p?['role'] ?? 'user').toString();
      _profile = p;
    });
  }

  Future<void> fetchWeather() async {
    try {
      const apiKey = '25b6e6d819c1449381e133924261001';
      const city = 'Kathmandu';
      final url = Uri.parse(
        'https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$city&aqi=no',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final d = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          weatherData = {
            'temp': d['current']['temp_c'],
            'main': d['current']['condition']['text'],
            'description': d['current']['condition']['text'],
          };
          isLoadingWeather = false;
        });
        _refreshTodayOutfit();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingWeather = false;
        weatherData = {'temp': 22, 'main': 'Clear', 'description': 'clear sky'};
      });
      _refreshTodayOutfit();
    }
  }

  Future<void> fetchHomeData() async {
    final storageData = await storageService.getAll();
    final clothingData = await clothingService.getRecentClothes();
    final outfitData = await outfitService.getAll();
    if (mounted) {
      setState(() {
        storages = storageData;
        recentClothes = clothingData;
        outfits = outfitData;
        loadingHome = false;
      });
      _refreshTodayOutfit();
      _enterCtrl.forward(from: 0);
    }
  }

  Future<void> _refreshHomeTab() async {
    await Future.wait<void>([fetchUserRole(), fetchWeather(), fetchHomeData()]);
  }

  String _resolveImageUrl(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }

  String _initial(String? value) {
    final s = (value ?? '').trim();
    return s.isEmpty ? '' : s[0].toUpperCase();
  }

  Future<void> _openRecommendation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationScreen(weatherData: weatherData),
      ),
    );
  }

  Future<void> _openOutfitsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OutfitsPage()),
    );
    if (mounted) fetchHomeData();
  }

  Future<void> _openCreateOutfit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OutfitBuilderPage()),
    );
    if (changed == true && mounted) {
      fetchHomeData();
    }
  }

  void _refreshTodayOutfit({bool force = false, int? excludeId}) {
    if (!mounted) return;
    if (outfits.isEmpty) {
      if (_todayOutfit != null) {
        setState(() => _todayOutfit = null);
      }
      return;
    }

    final current = _todayOutfit;
    if (!force && current != null) {
      final currentId = _asInt(current['id']);
      if (currentId != null) {
        final latest = outfits
            .where((o) => _asInt(o['id']) == currentId)
            .cast<Map<String, dynamic>?>()
            .firstWhere((o) => o != null, orElse: () => null);
        if (latest != null) {
          if (!_outfitMatchesWeather(latest)) {
            setState(() => _todayOutfit = _pickTodayOutfit());
          } else {
            setState(() => _todayOutfit = latest);
          }
          return;
        }
      }
    }

    setState(() => _todayOutfit = _pickTodayOutfit(excludeId: excludeId));
  }

  Map<String, dynamic>? _pickTodayOutfit({int? excludeId}) {
    final candidates = _matchingOutfitsForWeather();
    if (candidates.isEmpty) return null;
    final usable = candidates
        .where((o) => _asInt(o['id']) != excludeId)
        .toList();
    final poolBase = usable.isEmpty ? candidates : usable;
    poolBase.sort((a, b) => _outfitWearCount(a).compareTo(_outfitWearCount(b)));
    final poolSize = (poolBase.length * 0.35).ceil().clamp(1, poolBase.length);
    final pool = poolBase.take(poolSize).toList();
    return pool[_rng.nextInt(pool.length)];
  }

  List<Map<String, dynamic>> _matchingOutfitsForWeather() {
    if (outfits.isEmpty) return [];
    final matches = outfits.where(_outfitMatchesWeather).toList();
    return matches.isEmpty ? outfits : matches;
  }

  bool _outfitMatchesWeather(Map<String, dynamic> outfit) {
    final tags = _weatherTags();
    if (tags.isEmpty) return true;
    final outfitOccasion = (outfit['occasion'] ?? '').toString();
    final outfitName = (outfit['name'] ?? '').toString();
    if (_stringMatchesWeather(outfitOccasion, tags) ||
        _stringMatchesWeather(outfitName, tags)) {
      return true;
    }

    final items = <Map<String, dynamic>>[];
    final outerwear = _slot(outfit, 'outerwear_item');
    final topwear = _slot(outfit, 'topwear_item');
    final bottomwear = _slot(outfit, 'bottomwear_item');
    final shoes = _slot(outfit, 'shoes_item');
    if (outerwear != null) items.add(outerwear);
    if (topwear != null) items.add(topwear);
    if (bottomwear != null) items.add(bottomwear);
    if (shoes != null) items.add(shoes);
    items.addAll(_accessoryList(outfit));

    return items.any((item) => _itemMatchesWeather(item, tags));
  }

  bool _itemMatchesWeather(Map<String, dynamic> item, Set<String> tags) {
    final weather = (item['detected_weather'] ?? '').toString();
    final temp = (item['detected_temp'] ?? '').toString();
    final occasion = (item['occasion'] ?? '').toString();
    if (_stringMatchesWeather(weather, tags) ||
        _stringMatchesWeather(temp, tags) ||
        _stringMatchesWeather(occasion, tags)) {
      return true;
    }
    final attrs = item['attributes'];
    if (attrs is List) {
      for (final entry in attrs) {
        if (_stringMatchesWeather(entry.toString(), tags)) return true;
      }
    }
    return false;
  }

  bool _stringMatchesWeather(String raw, Set<String> tags) {
    final value = raw.toLowerCase().trim();
    if (value.isEmpty) return false;
    if (tags.contains('rain') &&
        (value.contains('rain') ||
            value.contains('drizzle') ||
            value.contains('storm'))) {
      return true;
    }
    if (tags.contains('snow') &&
        (value.contains('snow') || value.contains('sleet'))) {
      return true;
    }
    if (tags.contains('cloud') &&
        (value.contains('cloud') || value.contains('overcast'))) {
      return true;
    }
    if (tags.contains('clear') &&
        (value.contains('clear') || value.contains('sun'))) {
      return true;
    }
    if (tags.contains('wind') && value.contains('wind')) return true;
    if (tags.contains('fog') &&
        (value.contains('fog') ||
            value.contains('mist') ||
            value.contains('haze'))) {
      return true;
    }
    if (tags.contains('cold') &&
        (value.contains('cold') ||
            value.contains('winter') ||
            value.contains('cool'))) {
      return true;
    }
    if (tags.contains('hot') &&
        (value.contains('hot') ||
            value.contains('warm') ||
            value.contains('summer'))) {
      return true;
    }
    if (tags.contains('mild') &&
        (value.contains('mild') ||
            value.contains('spring') ||
            value.contains('fall') ||
            value.contains('autumn'))) {
      return true;
    }
    return false;
  }

  Set<String> _weatherTags() {
    final main = (weatherData?['main'] ?? '').toString().toLowerCase();
    final desc = (weatherData?['description'] ?? '').toString().toLowerCase();
    final blob = '$main $desc';
    final tags = <String>{};
    if (blob.contains('rain') || blob.contains('drizzle')) tags.add('rain');
    if (blob.contains('snow') || blob.contains('sleet')) tags.add('snow');
    if (blob.contains('cloud') || blob.contains('overcast')) tags.add('cloud');
    if (blob.contains('storm') || blob.contains('thunder')) tags.add('storm');
    if (blob.contains('wind')) tags.add('wind');
    if (blob.contains('fog') ||
        blob.contains('mist') ||
        blob.contains('haze')) {
      tags.add('fog');
    }
    if (blob.contains('clear') || blob.contains('sun')) tags.add('clear');

    final tempRaw = weatherData?['temp'];
    final temp = tempRaw is num
        ? tempRaw.toDouble()
        : double.tryParse(tempRaw?.toString() ?? '');
    if (temp != null) {
      if (temp <= 10) {
        tags.add('cold');
      } else if (temp >= 26) {
        tags.add('hot');
      } else {
        tags.add('mild');
      }
    }
    return tags;
  }

  int _outfitWearCount(Map<String, dynamic> outfit) {
    return _asInt(outfit['wear_count']) ?? 0;
  }

  Map<String, dynamic>? _resolveTodayOutfit() {
    final currentId = _asInt(_todayOutfit?['id']);
    if (currentId != null) {
      final latest = outfits
          .where((o) => _asInt(o['id']) == currentId)
          .cast<Map<String, dynamic>?>()
          .firstWhere((o) => o != null, orElse: () => null);
      return latest ?? _todayOutfit;
    }
    return _todayOutfit ?? (outfits.isNotEmpty ? outfits.first : null);
  }

  String _activeTabLabel() {
    switch (_selectedIndex) {
      case 1:
        return 'Wardrobe';
      case 2:
        return 'Storage';
      case 3:
        return 'Outfits';
      default:
        return 'Home';
    }
  }

  IconData _activeTabIcon() {
    switch (_selectedIndex) {
      case 1:
        return Icons.inventory_2_outlined;
      case 2:
        return Icons.apartment_outlined;
      case 3:
        return Icons.auto_awesome_outlined;
      default:
        return Icons.home_outlined;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showHome = _selectedIndex == 0;
    final showWardrobe = _selectedIndex == 1;
    final showStorage = _selectedIndex == 2;
    final showOutfit = _selectedIndex == 3;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.instance.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: HomeTokens.cream,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: showHome
                      ? FadeTransition(
                          key: ValueKey('home_tab_$_themeRefreshRevision'),
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: RefreshIndicator(
                              onRefresh: _refreshHomeTab,
                              color: HomeTokens.accent,
                              backgroundColor: HomeTokens.card,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                children: [
                                  const SizedBox(height: 24),
                                  _buildWelcomeSection(),
                                  const SizedBox(height: 20),
                                  _buildWeatherCard(),
                                  const SizedBox(height: 24),
                                  _buildTodayOutfitCard(),
                                  const SizedBox(height: 32),
                                  _buildQuickActions(),
                                  const SizedBox(height: 32),
                                  _buildRecentClothing(),
                                  const SizedBox(height: 32),
                                  _buildRecentOutfits(),
                                  const SizedBox(height: 120),
                                ],
                              ),
                            ),
                          ),
                        )
                      : showWardrobe
                      ? Padding(
                          key: ValueKey('wardrobe_tab_$_themeRefreshRevision'),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: WardrobeScreen(
                            embedded: true,
                            onSelectionChanged: (v) =>
                                setState(() => _wardrobeSelecting = v),
                          ),
                        )
                      : showStorage
                      ? StorageListScreen(
                          key: ValueKey('storage_tab_$_themeRefreshRevision'),
                          embedded: true,
                        )
                      : showOutfit
                      ? OutfitsPage(
                          key: ValueKey('outfit_tab_$_themeRefreshRevision'),
                          embedded: true,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: (showOutfit || showStorage || _wardrobeSelecting)
            ? null
            : _buildFAB(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final avatarUrl = _resolveImageUrl(_profile?['avatar']);
    final avatarInitial = _initial(
      (_profile?['username'] ?? _profile?['first_name'] ?? '').toString(),
    );
    final tabLabel = _activeTabLabel();
    final tabIcon = _activeTabIcon();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: HomeTokens.card,
        border: Border(bottom: BorderSide(color: HomeTokens.rule)),
        boxShadow: [
          BoxShadow(
            color: HomeTokens.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 0),
            child: Row(
              children: [
                AppLogo(
                  size: 38,
                  borderRadius: 10,
                  darkBackground: ThemeService.instance.isDark,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Closet Buddy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: HomeTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Row(
                        key: ValueKey('tab_hint_$_selectedIndex'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tabIcon, size: 12, color: HomeTokens.inkMuted),
                          const SizedBox(width: 4),
                          Text(
                            tabLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HomeTokens.inkMuted,
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
          const Spacer(),
          _AppBarBtn(
            icon: ThemeService.instance.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            onTap: () async {
              HapticFeedback.lightImpact();
              await ThemeService.instance.toggle();
            },
          ),
          const SizedBox(width: 8),
          if (role == 'admin')
            _AppBarBtn(
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          const SizedBox(width: 8),
          _AvatarBtn(
            imageUrl: avatarUrl,
            initial: avatarInitial,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              if (mounted) fetchUserRole();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetIcon;

    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning';
      greetIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
      greetIcon = Icons.light_mode_outlined;
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good evening';
      greetIcon = Icons.wb_twilight_outlined;
    } else {
      greeting = 'Good night';
      greetIcon = Icons.nightlight_outlined;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(greetIcon, size: 15, color: HomeTokens.gold),
                  const SizedBox(width: 6),
                  Text(
                    greeting.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: HomeTokens.gold,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                "What are you\nwearing today?",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: HomeTokens.ink,
                  letterSpacing: -0.8,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _openRecommendation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: HomeTokens.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HomeTokens.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: HomeTokens.white,
                ),
                SizedBox(width: 6),
                Text(
                  'Style Me',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: HomeTokens.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Weather ────────────────────────────────────────────────────────────────

  Widget _buildWeatherCard() {
    if (isLoadingWeather) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: HomeTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomeTokens.rule),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HomeTokens.accent,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
      );
    }

    final temp = (weatherData?['temp'] ?? 22).round();
    final condition = weatherData?['main'] ?? 'Clear';
    IconData weatherIcon;
    Color weatherColor;
    String tip;

    if (condition.toLowerCase().contains('rain')) {
      weatherIcon = Icons.umbrella_rounded;
      weatherColor = HomeTokens.sky;
      tip = 'Bring a waterproof layer';
    } else if (condition.toLowerCase().contains('cloud')) {
      weatherIcon = Icons.cloud_outlined;
      weatherColor = HomeTokens.skySoft;
      tip = 'Layer up, it may cool down';
    } else if (condition.toLowerCase().contains('snow')) {
      weatherIcon = Icons.ac_unit_rounded;
      weatherColor = HomeTokens.skyMuted;
      tip = 'Wrap up warm today';
    } else {
      weatherIcon = Icons.wb_sunny_rounded;
      weatherColor = HomeTokens.gold;
      tip = 'Great day for light layers';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeTokens.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeTokens.rule),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: weatherColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(weatherIcon, size: 26, color: weatherColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$temp°C',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: HomeTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      condition,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HomeTokens.inkSub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HomeTokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 13,
                color: HomeTokens.inkMuted,
              ),
              const SizedBox(height: 2),
              const Text(
                'Kathmandu',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: HomeTokens.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TODAY'S OUTFIT — the star of the show ─────────────────────────────────

  Widget _buildTodayOutfitCard() {
    final Map<String, dynamic>? todayOutfit = _resolveTodayOutfit();

    final String outfitName =
        (todayOutfit?['name'] ?? todayOutfit?['title'] ?? "Today's Look")
            .toString();
    final String occasion = (todayOutfit?['occasion'] ?? 'Any Occasion')
        .toString();
    final dynamic ratingRaw = todayOutfit?['rating'];
    final double? rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '');
    final int wearCount = _asInt(todayOutfit?['wear_count']) ?? 0;
    final bool wornToday = _isWornToday(todayOutfit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: HomeTokens.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "TODAY'S OUTFIT",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: HomeTokens.inkMuted,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Main card
        Container(
          decoration: BoxDecoration(
            color: HomeTokens.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HomeTokens.rule),
            boxShadow: [
              BoxShadow(
                color: HomeTokens.ink.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top metadata strip ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (todayOutfit != null) ...[
                            Text(
                              outfitName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: HomeTokens.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _MetaChip(
                                  icon: Icons.theater_comedy_outlined,
                                  label: occasion,
                                  color: HomeTokens.accentBg,
                                  textColor: HomeTokens.accent,
                                ),
                                if (rating != null)
                                  _MetaChip(
                                    icon: Icons.auto_awesome_rounded,
                                    label:
                                        '${rating.toStringAsFixed(1)} rating',
                                    color: HomeTokens.goldBg,
                                    textColor: HomeTokens.gold,
                                  ),
                                _MetaChip(
                                  icon: wornToday
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.checkroom_rounded,
                                  label: wornToday
                                      ? 'Worn today'
                                      : wearCount == 0
                                      ? 'Never worn'
                                      : '$wearCount wears',
                                  color: wornToday
                                      ? HomeTokens.sageBg
                                      : HomeTokens.parchment,
                                  textColor: wornToday
                                      ? HomeTokens.sage
                                      : HomeTokens.inkSub,
                                ),
                              ],
                            ),
                          ] else ...[
                            const Text(
                              'No outfit yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: HomeTokens.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Let AI build your look from your wardrobe',
                              style: TextStyle(
                                fontSize: 13,
                                color: HomeTokens.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Worn status badge (right side)
                    if (wornToday)
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: HomeTokens.sageBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: HomeTokens.sage.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.done_all_rounded,
                              size: 13,
                              color: HomeTokens.sage,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'On',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: HomeTokens.sage,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Outfit canvas ──────────────────────────────────────────
              Container(
                height: 380,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: HomeTokens.parchment,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: HomeTokens.rule),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: todayOutfit == null
                      ? _buildOutfitEmptyPreview()
                      : _buildTodayOutfitPreview(todayOutfit),
                ),
              ),

              // ── Action buttons ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _OutfitActionButton(
                        label: todayOutfit == null
                            ? 'Generate Outfit'
                            : wornToday
                            ? 'View Details'
                            : 'Wear Today',
                        icon: todayOutfit == null
                            ? Icons.auto_awesome_rounded
                            : wornToday
                            ? Icons.open_in_new_rounded
                            : Icons.checkroom_rounded,
                        isPrimary: true,
                        onTap: todayOutfit == null
                            ? _openRecommendation
                            : () async {
                                if (!wornToday) {
                                  final id = _asInt(todayOutfit['id']);
                                  if (id != null) {
                                    final updated = await outfitService
                                        .markWorn(id);
                                    if (updated != null && mounted) {
                                      setState(() {
                                        final idx = outfits.indexWhere(
                                          (o) => _asInt(o['id']) == id,
                                        );
                                        if (idx != -1) outfits[idx] = updated;
                                        if (_asInt(_todayOutfit?['id']) == id) {
                                          _todayOutfit = updated;
                                        }
                                      });
                                    }
                                  }
                                }
                                if (!mounted) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OutfitDetailPage(
                                      initialOutfit: todayOutfit,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                fetchHomeData();
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _OutfitActionButton(
                        label: todayOutfit == null ? 'Browse' : 'Re-pick',
                        icon: todayOutfit == null
                            ? Icons.style_outlined
                            : Icons.refresh_rounded,
                        isPrimary: false,
                        onTap: todayOutfit == null
                            ? _openOutfitsPage
                            : () => _refreshTodayOutfit(
                                force: true,
                                excludeId: _asInt(todayOutfit['id']),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitEmptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: HomeTokens.accentBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 28,
              color: HomeTokens.accent,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No outfit generated yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomeTokens.inkSub,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tap "Generate" to build a look\nfrom your wardrobe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: HomeTokens.inkMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOutfitPreview(Map<String, dynamic> outfit) {
    final previewItems = _previewItems(outfit);
    final previewTransforms = _layoutToTransforms(_previewLayout(outfit));

    return Padding(
      padding: const EdgeInsets.all(6),
      child: previewItems.isNotEmpty
          ? EditableOutfitCanvas(
              items: previewItems,
              initialTransforms: previewTransforms,
              interactive: false,
            )
          : OutfitCanvas(
              outerwear: _slot(outfit, 'outerwear_item'),
              topwear: _slot(outfit, 'topwear_item'),
              bottomwear: _slot(outfit, 'bottomwear_item'),
              shoes: _slot(outfit, 'shoes_item'),
              accessories: _accessoryList(outfit),
              compact: false,
              slotScale: 1.0,
            ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                label: 'Create Outfit',
                icon: Icons.draw_outlined,
                iconColor: HomeTokens.sky,
                iconBg: HomeTokens.skyBg,
                onTap: _openCreateOutfit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionTile(
                label: 'Generate Outfit',
                icon: Icons.auto_awesome_outlined,
                iconColor: HomeTokens.gold,
                iconBg: HomeTokens.goldBg,
                onTap: _openRecommendation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Storage ────────────────────────────────────────────────────────────────

  Widget _buildRecentClothing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Recent Items'),
        const SizedBox(height: 14),
        recentClothes.isNotEmpty
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: recentClothes.length,
                itemBuilder: (_, i) => _buildClothingCard(recentClothes[i]),
              )
            : _buildEmptyState(
                'No items yet',
                'Add your first clothing item',
                Icons.add_circle_outline_rounded,
              ),
      ],
    );
  }

  Widget _buildClothingCard(Map<String, dynamic> item) {
    final imageUrl = _resolveImageUrl(item['image']);
    final isFav = item['is_favourite'] ?? false;

    return HoverClickable(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClothingDetailScreen(clothingId: item['id']),
          ),
        );
        if (result == true) fetchHomeData();
      },
      child: Container(
        decoration: BoxDecoration(
          color: HomeTokens.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HomeTokens.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              imageUrl.isEmpty
                  ? Container(
                      color: HomeTokens.parchment,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: HomeTokens.inkMuted,
                      ),
                    )
                  : Container(
                      color: HomeTokens.parchment,
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),

              // Favourite button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final old = item['is_favourite'] ?? false;
                    setState(() => item['is_favourite'] = !old);
                    final ok = await clothingService.toggleFavourite(
                      item['id'],
                    );
                    if (!ok) setState(() => item['is_favourite'] = old);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: HomeTokens.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: HomeTokens.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 15,
                      color: isFav ? HomeTokens.accent : HomeTokens.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent outfits ─────────────────────────────────────────────────────────

  Widget _buildRecentOutfits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionHeader(title: 'Recent Outfits')),
            GestureDetector(
              onTap: _openOutfitsPage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: HomeTokens.parchment,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HomeTokens.inkSub,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        outfits.isNotEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth * 0.45).clamp(
                    155.0,
                    185.0,
                  );
                  return SizedBox(
                    height: 380,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: outfits.length,
                      itemBuilder: (_, i) => _buildOutfitCard(i, cardWidth),
                    ),
                  );
                },
              )
            : _buildEmptyState(
                'No outfits yet',
                'Generate your first look',
                Icons.auto_awesome_outlined,
              ),
      ],
    );
  }

  Widget _buildOutfitCard(int index, double width) {
    final outfit = outfits[index];
    final name = (outfit['name'] ?? 'Outfit').toString();
    final ratingRaw = outfit['rating'];
    final aiRatingScore = _asDouble(outfit['ai_rating_score']);
    final rating = ratingRaw == null ? '—' : ratingRaw.toString();
    final wearCount = _asInt(outfit['wear_count']) ?? 0;
    final previewItems = _previewItems(outfit);
    final previewTransforms = _layoutToTransforms(_previewLayout(outfit));

    return HoverClickable(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OutfitDetailPage(initialOutfit: outfit),
          ),
        );
        fetchHomeData();
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: HomeTokens.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomeTokens.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HomeTokens.parchment,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: previewItems.isNotEmpty
                        ? EditableOutfitCanvas(
                            items: previewItems,
                            initialTransforms: previewTransforms,
                            interactive: false,
                          )
                        : OutfitCanvas(
                            outerwear: _slot(outfit, 'outerwear_item'),
                            topwear: _slot(outfit, 'topwear_item'),
                            bottomwear: _slot(outfit, 'bottomwear_item'),
                            shoes: _slot(outfit, 'shoes_item'),
                            accessories: _accessoryList(outfit),
                            compact: true,
                          ),
                  ),
                ),
              ),
            ),

            // Metadata
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: HomeTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: HomeTokens.gold,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: HomeTokens.inkSub,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HomeTokens.parchment,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          wearCount == 0 ? 'New' : '$wearCount×',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: HomeTokens.inkSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (aiRatingScore != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HomeTokens.parchment,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: HomeTokens.gold,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                aiRatingScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: HomeTokens.inkSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FAB + nav ──────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await showAddItemSheet(context);
        _handleAddItemResult(result);
      },
      backgroundColor: WidgetTokens.accent,
      elevation: 4,
      icon: const Icon(
        Icons.add_rounded,
        color: WidgetTokens.surface,
        size: 22,
      ),
      label: const Text(
        'Add Item',
        style: TextStyle(
          color: WidgetTokens.surface,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 380;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: HomeTokens.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomeTokens.rule),
          boxShadow: [
            BoxShadow(
              color: HomeTokens.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: HomeTokens.accent,
            unselectedItemColor: HomeTokens.inkMuted,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: isCompact ? 10 : 11,
            unselectedFontSize: isCompact ? 10 : 11,
            iconSize: isCompact ? 22 : 24,
            backgroundColor: HomeTokens.card,
            elevation: 0,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
                if (index != 1) _wardrobeSelecting = false;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Wardrobe',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.apartment_outlined),
                activeIcon: Icon(Icons.apartment_rounded),
                label: 'Storage',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Outfits',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String sub, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: HomeTokens.parchment,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeTokens.rule),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HomeTokens.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 26, color: HomeTokens.inkMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: HomeTokens.inkMuted),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _slot(Map<String, dynamic> outfit, String key) {
    final raw = outfit[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  List<Map<String, dynamic>> _accessoryList(Map<String, dynamic> outfit) {
    final raw = outfit['accessory_items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _previewLayout(Map<String, dynamic> outfit) {
    final raw = outfit['preview_layout'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<EditableCanvasItem> _previewItems(Map<String, dynamic> outfit) {
    final top = _slot(outfit, 'topwear_item');
    final bottom = _slot(outfit, 'bottomwear_item');
    final shoes = _slot(outfit, 'shoes_item');
    final outerwear = _slot(outfit, 'outerwear_item');
    final accs = _accessoryList(outfit);
    final items = <EditableCanvasItem>[];

    if (bottom != null) {
      items.add(
        EditableCanvasItem(
          id: 'bottom-${_asInt(bottom['id']) ?? 0}',
          label: 'Bottomwear',
          imageUrl: _imageOf(bottom),
          widthFactor: 0.5,
          heightFactor: 0.27,
          defaultOffset: const Offset(0, 0.23),
        ),
      );
    }
    if (top != null) {
      items.add(
        EditableCanvasItem(
          id: 'top-${_asInt(top['id']) ?? 0}',
          label: 'Topwear',
          imageUrl: _imageOf(top),
          widthFactor: 0.62,
          heightFactor: 0.28,
          defaultOffset: const Offset(0, -0.03),
        ),
      );
    }
    if (outerwear != null) {
      items.add(
        EditableCanvasItem(
          id: 'outerwear-${_asInt(outerwear['id']) ?? 0}',
          label: 'Outerwear',
          imageUrl: _imageOf(outerwear),
          widthFactor: 0.64,
          heightFactor: 0.24,
          defaultOffset: const Offset(0, -0.23),
        ),
      );
    }
    if (shoes != null) {
      items.add(
        EditableCanvasItem(
          id: 'shoes-${_asInt(shoes['id']) ?? 0}',
          label: 'Shoes',
          imageUrl: _imageOf(shoes),
          widthFactor: 0.46,
          heightFactor: 0.17,
          defaultOffset: const Offset(0, 0.41),
        ),
      );
    }
    for (var i = 0; i < accs.length; i++) {
      final acc = accs[i];
      final col = i % 4;
      final row = i ~/ 4;
      items.add(
        EditableCanvasItem(
          id: 'acc-${_asInt(acc['id']) ?? i}',
          label: 'Accessory',
          imageUrl: _imageOf(acc),
          widthFactor: 0.17,
          heightFactor: 0.11,
          defaultOffset: Offset(-0.225 + (col * 0.15), 0.5 - (row * 0.09)),
        ),
      );
    }
    return items.where((item) => item.imageUrl.isNotEmpty).toList();
  }

  Map<String, EditableCanvasTransform> _layoutToTransforms(
    Map<String, dynamic> layout,
  ) {
    final out = <String, EditableCanvasTransform>{};
    layout.forEach((key, value) {
      if (value is! Map) return;
      final x = value['offset_x'] is num
          ? (value['offset_x'] as num).toDouble()
          : double.tryParse('${value['offset_x']}');
      final y = value['offset_y'] is num
          ? (value['offset_y'] as num).toDouble()
          : double.tryParse('${value['offset_y']}');
      final s = value['scale'] is num
          ? (value['scale'] as num).toDouble()
          : double.tryParse('${value['scale']}');
      if (x == null || y == null || s == null) return;
      out[key] = EditableCanvasTransform(offset: Offset(x, y), scale: s);
    });
    return out;
  }

  String _imageOf(Map<String, dynamic> item) {
    final raw = (item['image'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiClient.host}$raw';
    return '${ApiClient.host}/$raw';
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  bool _isWornToday(Map<String, dynamic>? outfit) {
    final raw = outfit?['last_worn_at'];
    if (raw == null) return false;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return false;
    final local = parsed.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: HomeTokens.parchment,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: HomeTokens.inkSub),
    ),
  );
}

class _AvatarBtn extends StatelessWidget {
  final String imageUrl;
  final String initial;
  final VoidCallback onTap;
  const _AvatarBtn({
    required this.imageUrl,
    required this.initial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: HomeTokens.parchment,
        shape: BoxShape.circle,
        border: Border.all(color: HomeTokens.rule),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallback(initial: initial),
              )
            : _AvatarFallback(initial: initial),
      ),
    ),
  );
}

class _AvatarFallback extends StatelessWidget {
  final String initial;
  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    if (initial.isEmpty) {
      return const Center(
        child: Icon(Icons.person_rounded, size: 16, color: HomeTokens.inkMuted),
      );
    }
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: HomeTokens.accent,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: HomeTokens.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: HomeTokens.inkMuted,
          letterSpacing: 1.8,
        ),
      ),
    ],
  );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: textColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

class _OutfitActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _OutfitActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPrimary ? HomeTokens.accent : HomeTokens.parchment,
        borderRadius: BorderRadius.circular(14),
        border: isPrimary ? null : Border.all(color: HomeTokens.rule),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: HomeTokens.accent.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isPrimary ? HomeTokens.white : HomeTokens.inkSub,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isPrimary ? HomeTokens.white : HomeTokens.inkSub,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => HoverClickable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeTokens.rule),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: HomeTokens.ink,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: HomeTokens.inkMuted,
          ),
        ],
      ),
    ),
  );
}

