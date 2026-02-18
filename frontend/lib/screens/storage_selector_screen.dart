import 'package:flutter/material.dart';
import 'package:frontend/widgets/hover_clickable.dart';
import '../services/storage_service.dart';
import 'upload_clothing_screen.dart';
import 'add_non_clothing_screen.dart';

class StorageSelectorScreen extends StatefulWidget {
  final bool isClothing;

  const StorageSelectorScreen({Key? key, required this.isClothing})
    : super(key: key);

  @override
  State<StorageSelectorScreen> createState() => _StorageSelectorScreenState();
}

class _StorageSelectorScreenState extends State<StorageSelectorScreen> {
  final StorageService storageService = StorageService();
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

      setState(() {
        storageList = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load storage units: $e')),
      );
    }
  }

  void _continue() {
    if (selectedStorageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a storage unit'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.isClothing) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              UploadClothingScreen(storageId: selectedStorageId!),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AddNonClothingScreen(storageId: selectedStorageId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Storage',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
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
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose the storage location for your ${widget.isClothing ? "clothing" : "item"}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF6B7280),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF1A1A1A) : Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Color(0xFF1A1A1A)
                    : Color(0xFF1A1A1A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStorageIcon(storageType),
                color: isSelected ? Colors.white : Color(0xFF1A1A1A),
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
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$storageType • $itemCount items',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFD1D5DB), width: 2),
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
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF9CA3AF)),
          SizedBox(height: 16),
          Text(
            'No storage units found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create a storage unit first',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              backgroundColor: Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Color(0xFF1A1A1A).withOpacity(0.3),
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
