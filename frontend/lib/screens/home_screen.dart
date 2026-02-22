import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/hover_clickable.dart';
import '../services/profile_service.dart';
import '../services/clothing_service.dart';
import '../services/storage_service.dart';
import '../services/outfit_service.dart';
import '../services/api_client.dart';

import 'profile_screen.dart';
import 'clothing_detail_screen.dart';
import 'storage_space_screen.dart';
import 'admin_screen.dart';
import 'add_item_screen.dart';
import 'storage_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileService profileService = ProfileService();
  final StorageService storageService = StorageService();
  final ClothingService clothingService = ClothingService();
  final OutfitService outfitService = OutfitService();

  List<Map<String, dynamic>> storages = [];
  List<Map<String, dynamic>> recentClothes = [];
  List<Map<String, dynamic>> outfits = [];
  bool loadingHome = true;

  String role = "user";
  int _selectedIndex = 0;

  Map<String, dynamic>? weatherData;
  bool isLoadingWeather = true;

  final TextStyle sectionTitle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A1A1A),
  );

  void _handleAddItemResult(dynamic result) {
    if (result == true) {
      fetchHomeData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added successfully'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 900),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserRole();
    fetchWeather();
    fetchHomeData();
  }

  // ---------------- BACKEND ----------------

  void fetchUserRole() async {
    final profileData = await profileService.fetchProfile();
    if (profileData != null) {
      setState(() {
        role = profileData['role']; // user / admin
      });
    }
  }

  // ---------------- WEATHER ----------------

  Future<void> fetchWeather() async {
    try {
      const apiKey = '25b6e6d819c1449381e133924261001';
      const city = 'Kathmandu';
      final url = Uri.parse(
        'https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$city&aqi=no',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          weatherData = {
            'temp': decodedData['current']['temp_c'],
            'main': decodedData['current']['condition']['text'],
            'description': decodedData['current']['condition']['text'],
          };
          isLoadingWeather = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingWeather = false;
        weatherData = {'temp': 22, 'main': 'Clear', 'description': 'clear sky'};
      });
    }
  }

  Future<void> fetchHomeData() async {
    final storageData = await storageService.getAll();
    final clothingData = await clothingService.getRecentClothes();
    final outfitData = await outfitService.getAll();

    setState(() {
      storages = storageData;
      recentClothes = clothingData;
      outfits = outfitData;
      loadingHome = false;
    });
  }

  String _resolveImageUrl(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 24),
                  _buildWelcomeSection(),
                  const SizedBox(height: 20),
                  _buildWeatherCard(),
                  const SizedBox(height: 20),
                  _buildTodayOutfitCard(),
                  const SizedBox(height: 32),
                  _buildQuickActions(),
                  const SizedBox(height: 32),
                  _buildStorageOverview(),
                  const SizedBox(height: 32),
                  _buildRecentClothing(),
                  const SizedBox(height: 32),
                  _buildRecentOutfits(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------------- TOP BAR ----------------

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HoverClickable(
            onTap: () {
              setState(() => _selectedIndex = 0);
            },
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.checkroom_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Closet Buddy",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (role == "admin")
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    );
                  },
                ),
              HoverClickable(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- SECTIONS ----------------

  Widget _buildWelcomeSection() {
    final hour = DateTime.now().hour;
    String greeting = 'Good morning';
    String emoji = '🌅';

    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
      emoji = '☀️';
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good evening';
      emoji = '🌆';
    } else if (hour >= 21 || hour < 5) {
      greeting = 'Good night';
      emoji = '🌙';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting $emoji',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Let AI style your perfect outfit today',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildWeatherCard() {
    if (isLoadingWeather) {
      return Container(
        height: 100,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
            ),
          ),
        ),
      );
    }
    final temp = (weatherData?['temp'] ?? 22).round();
    final condition = weatherData?['main'] ?? 'Clear';
    final description = weatherData?['description'] ?? 'clear sky';

    IconData weatherIcon = Icons.wb_sunny;
    Color weatherColor = Color(0xFFFBBF24);
    if (condition.contains('Rain')) {
      weatherIcon = Icons.beach_access;
      weatherColor = Color(0xFF3B82F6);
    } else if (condition.contains('Cloud')) {
      weatherIcon = Icons.cloud;
      weatherColor = Color(0xFF6B7280);
    } else if (condition.contains('Snow')) {
      weatherIcon = Icons.ac_unit;
      weatherColor = Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            weatherColor.withOpacity(0.1),
            weatherColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: weatherColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: weatherColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(weatherIcon, size: 32, color: weatherColor),
          ),
          SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp°',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        condition,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  description.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.location_on, size: 16, color: Color(0xFF6B7280)),
              SizedBox(height: 4),
              Text(
                'Kathmandu',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOutfitCard() {
    final Map<String, dynamic>? todayOutfit = outfits.isNotEmpty
        ? outfits.first
        : null;
    final String outfitName =
        (todayOutfit?['name'] ?? todayOutfit?['title'] ?? "Today's Outfit")
            .toString();
    final String occasion = (todayOutfit?['occasion'] ?? 'Any Occasion')
        .toString();
    final dynamic rawRating = todayOutfit?['rating'];
    final double? rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '');
    final dynamic clothingItems = todayOutfit?['clothing_items'];
    final int pieceCount = clothingItems is List ? clothingItems.length : 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      todayOutfit == null
                          ? "Today's Outfit"
                          : "AI Generated Outfit",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  todayOutfit == null ? 'No outfit generated yet' : outfitName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: todayOutfit == null
                      ? const Text(
                          "Generate from your wardrobe",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating == null
                                  ? occasion
                                  : '${rating.toStringAsFixed(1)} AI Rating',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: todayOutfit == null
                  ? _buildOutfitEmptyPreview()
                  : Row(
                      children: [
                        Flexible(
                          child: _buildOutfitItem(
                            'Top',
                            Icons.checkroom,
                            pieceCount > 0 ? 'Selected' : 'Not set',
                          ),
                        ),
                        Container(
                          width: 1,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        Flexible(
                          child: _buildOutfitItem(
                            'Bottom',
                            Icons.straighten,
                            pieceCount > 1 ? 'Selected' : 'Not set',
                          ),
                        ),
                        Container(
                          width: 1,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        Flexible(
                          child: _buildOutfitItem(
                            'Shoes',
                            Icons.hiking,
                            pieceCount > 2 ? 'Selected' : 'Not set',
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Flexible(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Wear Today",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      todayOutfit == null ? "Create Outfit" : "Regenerate",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
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

  Widget _buildOutfitEmptyPreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_awesome_outlined, color: Colors.white70, size: 28),
            SizedBox(height: 8),
            Text(
              'No saved outfit yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Use AI Stylist to generate one in seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitItem(String label, IconData icon, String value) {
    return Container(
      color: Colors.white.withOpacity(0.03),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Quick Access", style: sectionTitle),
        const SizedBox(height: 16),
        Row(
          children: [
            _actionButton("Add Item", Icons.add_circle_outline, () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddItemSelectionPage()),
              );

              _handleAddItemResult(result);
            }),
            const SizedBox(width: 12),
            _actionButton("AI Stylist", Icons.auto_awesome_outlined, () {}),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _actionButton("My Wardrobe", Icons.inventory_2_outlined, () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StorageListScreen()),
              );

              if (result == true) fetchHomeData();
            }),
            const SizedBox(width: 12),
            _actionButton("Saved Outfits", Icons.favorite_outline, () {}),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return Flexible(
      child: HoverClickable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOverview() {
    final topLevelStorages = storages
        .where((s) => s['parent_storage'] == null)
        .toList();
    final previewStorages = topLevelStorages.take(8).toList();

    if (topLevelStorages.isEmpty) {
      return _buildEmptyState(
        'No storage yet',
        'Create your first closet or drawer',
        Icons.inventory_2_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Your Storage", style: sectionTitle),
            Row(
              children: [
                Text(
                  '${previewStorages.length}/${topLevelStorages.length} shown',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StorageListScreen(),
                      ),
                    );

                    if (result == true) fetchHomeData();
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth * 0.58).clamp(165.0, 230.0);

            return SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: previewStorages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _storageCard(previewStorages[index], cardWidth),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _storageCard(Map<String, dynamic> storage, double width) {
    final String name = (storage['name'] ?? 'Storage').toString();
    final int count = storage['item_count'] is num
        ? (storage['item_count'] as num).toInt()
        : int.tryParse(storage['item_count']?.toString() ?? '0') ?? 0;
    final String type = (storage['type'] ?? 'storage').toString();

    return HoverClickable(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StorageDetailScreen(storageId: storage['id']),
          ),
        );

        // refresh home when coming back
        fetchHomeData();
      },

      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF1A1A1A),
                  size: 22,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${type[0].toUpperCase()}${type.substring(1)} - $count items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentClothing() {
    final hasClothes = recentClothes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Recent Items', style: sectionTitle)],
        ),
        const SizedBox(height: 16),
        hasClothes
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: recentClothes.length,
                itemBuilder: (context, index) =>
                    _buildClothingCard(recentClothes[index]),
              )
            : _buildEmptyState(
                'No items yet',
                'Add your first clothing item',
                Icons.add_circle_outline,
              ),
      ],
    );
  }

  Widget _buildClothingCard(Map<String, dynamic> item) {
    final imageUrl = _resolveImageUrl(item['image']);

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              imageUrl.isEmpty
                  ? Container(
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF9CA3AF),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),

              /// ❤️ Favourite toggle
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () async {
                    // 1. Optimistic Update (update UI immediately for responsiveness)
                    final oldStatus = item['is_favourite'] ?? false;
                    setState(() => item['is_favourite'] = !oldStatus);

                    final success = await clothingService.toggleFavourite(
                      item['id'],
                    );

                    if (!success) {
                      // Rollback if server fails
                      setState(() => item['is_favourite'] = oldStatus);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Failed to update favourite"),
                        ),
                      );
                    }
                  },
                  child: TweenAnimationBuilder<double>(
                    // Trigger the "pop" when isFavourite changes
                    tween: Tween(
                      begin: 1.0,
                      end: (item['is_favourite'] ?? false) ? 1.2 : 1.0,
                    ),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack, // Gives it that bouncy "pop"
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape
                            .circle, // Circular usually looks better for action buttons
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        // Use a custom transition for the icon specifically
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                        child: Icon(
                          (item['is_favourite'] ?? false)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          key: ValueKey(item['is_favourite'] ?? false),
                          size: 18,
                          color: (item['is_favourite'] ?? false)
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                      ),
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

  Widget _buildRecentOutfits() {
    final hasOutfits = outfits.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Outfits', style: sectionTitle),
        const SizedBox(height: 16),
        hasOutfits
            ? SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfits.length,
                  itemBuilder: (context, i) => _buildOutfitCard(i),
                ),
              )
            : _buildEmptyState(
                'No outfits yet',
                'Create your first outfit',
                Icons.auto_awesome_outlined,
              ),
      ],
    );
  }

  Widget _buildOutfitCard(int index) {
    return HoverClickable(
      onTap: () {
        // Open outfit detail page
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.checkroom_outlined,
                    size: 48,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outfit ${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Color(0xFFFBBF24)),
                      SizedBox(width: 4),
                      Text(
                        '4.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
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
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: Color(0xFF9CA3AF)),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
  // ---------------- FAB + NAV ----------------

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddItemSelectionPage()),
        );

        _handleAddItemResult(result);
      },

      backgroundColor: Color(0xFF1A1A1A),
      elevation: 4,
      icon: Icon(Icons.add, color: Colors.white, size: 24),
      label: Text(
        'Add Item',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 380;
    final isMedium = width >= 380 && width < 450;

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xFF1A1A1A),
      unselectedItemColor: const Color(0xFF9CA3AF),
      type: BottomNavigationBarType.fixed,
      selectedFontSize: isCompact
          ? 10
          : isMedium
          ? 11
          : 12,
      unselectedFontSize: isCompact
          ? 10
          : isMedium
          ? 11
          : 12,
      iconSize: isCompact ? 22 : 24,
      showUnselectedLabels: !isCompact,
      onTap: (index) {
        setState(() => _selectedIndex = index);

        if (index == 0) {
          return;
        }

        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StorageListScreen()),
          ).then((_) => fetchHomeData());
          return;
        }

        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Outfits page coming soon")),
          );
          return;
        }

        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: "Wardrobe",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome),
          label: "Outfits",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
