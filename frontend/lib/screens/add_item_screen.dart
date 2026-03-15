import 'package:flutter/material.dart';

import '../widgets/hover_clickable.dart';
import 'storage_selector_screen.dart';

const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE5E7EB);

class AddItemSelectionPage extends StatefulWidget {
  const AddItemSelectionPage({super.key});

  @override
  State<AddItemSelectionPage> createState() => _AddItemSelectionPageState();
}

class _AddItemSelectionPageState extends State<AddItemSelectionPage> {
  static const _pageBg = Color(0xFFF8F9FA);
  static const _ink = Color(0xFF1A1A1A);

  Future<void> _openStorageSelector({
    required bool isClothing,
    bool isShoe = false,
    bool isAccessory = false,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StorageSelectorScreen(
          isClothing: isClothing,
          isShoe: isShoe,
          isAccessory: isAccessory,
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      _AddItemOption(
        title: 'Clothing Item',
        description: 'AI analysis for category, colors, and attributes',
        icon: Icons.checkroom_outlined,
        iconColor: const Color(0xFF3B82F6),
        onTap: () => _openStorageSelector(isClothing: true),
      ),
      _AddItemOption(
        title: 'Shoes',
        description: 'Shoe type and usage-focused analysis',
        icon: Icons.hiking_outlined,
        iconColor: const Color(0xFFF59E0B),
        onTap: () => _openStorageSelector(isClothing: true, isShoe: true),
      ),
      _AddItemOption(
        title: 'Accessory',
        description: 'Upload accessory and run segmentation only',
        icon: Icons.watch_outlined,
        iconColor: const Color(0xFF8B5CF6),
        onTap: () => _openStorageSelector(isClothing: false, isAccessory: true),
      ),
      _AddItemOption(
        title: 'Non-Clothing Item',
        description: 'Add misc items without AI processing',
        icon: Icons.shopping_bag_outlined,
        iconColor: const Color(0xFF10B981),
        onTap: () => _openStorageSelector(isClothing: false),
      ),
    ];

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Item',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _line),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          itemCount: options.length + 2,
          separatorBuilder: (context, index) =>
              SizedBox(height: index == 0 ? 20 : 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHeader();
            }
            if (index == options.length + 1) {
              return _buildInfoCallout();
            }
            return _buildItemTypeCard(option: options[index - 1]);
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What would you like to add?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select the type of item you want to add to your closet.',
          style: TextStyle(fontSize: 16, color: _muted, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildInfoCallout() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: choose a storage first, then complete upload details. Clothing and shoes run AI analysis, accessories run segmentation only.',
              style: TextStyle(fontSize: 13, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTypeCard({required _AddItemOption option}) {
    return HoverClickable(
      onTap: option.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: option.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(option.icon, color: option.iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemOption {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _AddItemOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
}
