import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:frontend/widgets/hover_clickable.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/features/upload/screens/add_non_clothing_screen.dart';
import 'package:frontend/features/upload/screens/upload_accessory_screen.dart';
import 'package:frontend/features/upload/screens/upload_clothing_screen.dart';
import 'package:frontend/theme/app_theme.dart';

class StorageSelectorScreen extends StatefulWidget {
  final bool isClothing;
  final bool isShoe;
  final bool isAccessory;

  const StorageSelectorScreen({
    super.key,
    required this.isClothing,
    this.isShoe = false,
    this.isAccessory = false,
  });

  @override
  State<StorageSelectorScreen> createState() => _StorageSelectorScreenState();
}

class _StorageSelectorScreenState extends State<StorageSelectorScreen> {
  final StorageService storageService = ServiceRegistry.instance.storageService;
  List<Map<String, dynamic>> storageList = [];
  int? selectedStorageId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadStorages();
  }

  Future<void> loadStorages() async {
    try {
      final result = await storageService.getAll();
      result.sort((a, b) {
        int aParent = a['parent_storage']?['id'] ?? 0;
        int bParent = b['parent_storage']?['id'] ?? 0;
        return aParent.compareTo(bParent);
      });

      if (!mounted) return;
      setState(() {
        storageList = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load storage units: $e')),
      );
    }
  }

  Future<void> _continue() async {
    if (selectedStorageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a storage unit'),
          backgroundColor: StorageTokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.isAccessory) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              UploadAccessoryScreen(storageId: selectedStorageId!),
        ),
      );
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } else if (widget.isClothing) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadClothingScreen(
            storageId: selectedStorageId!,
            isShoe: widget.isShoe,
          ),
        ),
      );
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AddNonClothingScreen(storageId: selectedStorageId!),
        ),
      );
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StorageTokens.pageBg,
      appBar: AppBar(
        backgroundColor: StorageTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: StorageTokens.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Storage',
          style: TextStyle(
            color: StorageTokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: StorageTokens.line),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  StorageTokens.ink,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where will you store this?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: StorageTokens.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose the storage location for your ${widget.isAccessory
                              ? "accessory"
                              : widget.isClothing
                              ? (widget.isShoe ? "shoes" : "clothing")
                              : "item"}',
                          style: TextStyle(
                            fontSize: 15,
                            color: StorageTokens.muted,
                          ),
                        ),
                        SizedBox(height: 24),
                        if (storageList.isEmpty)
                          _buildEmptyState()
                        else
                          ...storageList.map(
                            (storage) => _buildStorageOption(storage),
                          ),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildStorageOption(Map<String, dynamic> storage) {
    final storageId = storage['id'] as int;
    final isSelected = selectedStorageId == storageId;
    final storageName = storage['name'] as String;
    final storageType = storage['type'] as String? ?? 'Storage';
    final itemCount = storage['item_count'] as int? ?? 0;
    final parentStorage = storage['parent_storage'];

    String displayName = storageName;
    if (parentStorage != null) {
      displayName = '${parentStorage['name']} › $storageName';
    }

    return HoverClickable(
      onTap: () {
        setState(() {
          selectedStorageId = storageId;
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StorageTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? StorageTokens.ink : StorageTokens.line,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: StorageTokens.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? StorageTokens.ink
                    : StorageTokens.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStorageIcon(storageType),
                color: isSelected ? StorageTokens.surface : StorageTokens.ink,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: StorageTokens.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$storageType • $itemCount items',
                    style: TextStyle(
                      fontSize: 13,
                      color: StorageTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: StorageTokens.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: StorageTokens.surface, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: StorageTokens.lineQuiet, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: StorageTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StorageTokens.line),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: StorageTokens.mutedSoft,
          ),
          SizedBox(height: 16),
          Text(
            'No storage units found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: StorageTokens.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create a storage unit first',
            style: TextStyle(fontSize: 14, color: StorageTokens.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: StorageTokens.surface,
        border: Border(top: BorderSide(color: StorageTokens.line)),
        boxShadow: [
          BoxShadow(
            color: StorageTokens.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: selectedStorageId == null ? null : _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: WidgetTokens.accent,
              foregroundColor: StorageTokens.surface,
              disabledBackgroundColor: WidgetTokens.accent.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStorageIcon(String type) {
    switch (type.toLowerCase()) {
      case 'closet':
        return Icons.checkroom_outlined;
      case 'drawer':
        return Icons.inbox_outlined;
      case 'box':
        return Icons.inventory_2_outlined;
      case 'rack':
        return Icons.view_column_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
