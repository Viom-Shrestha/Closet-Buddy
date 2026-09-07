import 'package:flutter/material.dart';

import 'package:frontend/widgets/hover_clickable.dart';
import 'package:frontend/features/storage/screens/storage_selector_screen.dart';
import 'package:frontend/theme/app_theme.dart';

class AddItemSelectionPage extends StatefulWidget {
  const AddItemSelectionPage({super.key});

  @override
  State<AddItemSelectionPage> createState() => _AddItemSelectionPageState();
}

Future<bool?> showAddItemSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AddItemTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const AddItemSheet(),
  );
}

class AddItemSheet extends StatelessWidget {
  const AddItemSheet({super.key});

  Future<void> _openStorageSelector(
    BuildContext context, {
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

    if (!context.mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      _AddItemOption(
        title: 'Clothing',
        description: 'AI analysis for category, colors, and attributes',
        icon: Icons.checkroom_outlined,
        iconColor: AddItemTokens.info,
        onTap: () => _openStorageSelector(context, isClothing: true),
      ),
      _AddItemOption(
        title: 'Shoes',
        description: 'Shoe type and usage-focused analysis',
        icon: Icons.hiking_outlined,
        iconColor: AddItemTokens.warning,
        onTap: () =>
            _openStorageSelector(context, isClothing: true, isShoe: true),
      ),
      _AddItemOption(
        title: 'Accessory',
        description: 'Segmentation only — bags, watches, belts, etc.',
        icon: Icons.watch_outlined,
        iconColor: AddItemTokens.purple,
        onTap: () =>
            _openStorageSelector(context, isClothing: false, isAccessory: true),
      ),
      _AddItemOption(
        title: 'Other',
        description: 'Misc items without AI processing',
        icon: Icons.shopping_bag_outlined,
        iconColor: AddItemTokens.success,
        onTap: () => _openStorageSelector(context, isClothing: false),
      ),
    ];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AddItemTokens.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to Wardrobe',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AddItemTokens.ink,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Choose what type of item to add.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AddItemTokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AddItemTokens.surfaceSoft,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _BigOptionCard(option: options[0])),
                    const SizedBox(width: 10),
                    Expanded(child: _BigOptionCard(option: options[1])),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _BigOptionCard(option: options[2])),
                    const SizedBox(width: 10),
                    Expanded(child: _BigOptionCard(option: options[3])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigOptionCard extends StatelessWidget {
  final _AddItemOption option;

  const _BigOptionCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: option.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: option.iconColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: option.iconColor.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: option.iconColor, size: 23),
            ),
            const SizedBox(height: 12),
            Text(
              option.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AddItemTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              style: const TextStyle(
                fontSize: 11,
                color: AddItemTokens.muted,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemSelectionPageState extends State<AddItemSelectionPage> {
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
        iconColor: AddItemTokens.info,
        onTap: () => _openStorageSelector(isClothing: true),
      ),
      _AddItemOption(
        title: 'Shoes',
        description: 'Shoe type and usage-focused analysis',
        icon: Icons.hiking_outlined,
        iconColor: AddItemTokens.warning,
        onTap: () => _openStorageSelector(isClothing: true, isShoe: true),
      ),
      _AddItemOption(
        title: 'Accessory',
        description: 'Upload accessory and run segmentation only',
        icon: Icons.watch_outlined,
        iconColor: AddItemTokens.purple,
        onTap: () => _openStorageSelector(isClothing: false, isAccessory: true),
      ),
      _AddItemOption(
        title: 'Non-Clothing Item',
        description: 'Add misc items without AI processing',
        icon: Icons.shopping_bag_outlined,
        iconColor: AddItemTokens.success,
        onTap: () => _openStorageSelector(isClothing: false),
      ),
    ];

    return Scaffold(
      backgroundColor: AddItemTokens.pageBg,
      appBar: AppBar(
        backgroundColor: AddItemTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AddItemTokens.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Item',
          style: TextStyle(
            color: AddItemTokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AddItemTokens.line),
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
            color: AddItemTokens.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select the type of item you want to add to your closet.',
          style: TextStyle(
            fontSize: 16,
            color: AddItemTokens.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCallout() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AddItemTokens.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AddItemTokens.info.withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              color: AddItemTokens.info,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: choose a storage first, then complete upload details. Clothing and shoes run AI analysis, accessories run segmentation only.',
              style: TextStyle(fontSize: 13, color: AddItemTokens.ink),
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
          color: AddItemTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AddItemTokens.line),
          boxShadow: [
            BoxShadow(
              color: AddItemTokens.black.withValues(alpha: 0.04),
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
                      color: AddItemTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AddItemTokens.muted,
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
              color: AddItemTokens.mutedSoft,
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
