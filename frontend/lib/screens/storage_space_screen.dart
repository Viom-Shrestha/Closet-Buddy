import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/primary_buttons.dart';
import 'storage_detail_screen.dart';

enum StorageType { closet, wardrobe, cupboard, drawer, box, shelf, others }

class StorageSpace {
  final String id;
  final String name;
  final StorageType type;
  final int itemCount;
  final String? parentId;
  final List<StorageSpace> subStorages;
  final DateTime createdAt;
  bool isPutAway;

  StorageSpace({
    required this.id,
    required this.name,
    required this.type,
    this.itemCount = 0,
    this.parentId,
    this.subStorages = const [],
    required this.createdAt,
    required this.isPutAway,
  });

  factory StorageSpace.fromJson(Map<String, dynamic> json) {
    final parent = json['parent_storage'];
    final createdAtRaw = json['created_at']?.toString();

    return StorageSpace(
      id: json['id'].toString(),
      name: json['name'],
      type: StorageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StorageType.others,
      ),
      itemCount: json['item_count'] ?? 0,
      parentId: parent is Map<String, dynamic>
          ? parent['id']?.toString()
          : null,
      subStorages:
          (json['sub_storages'] as List<dynamic>?)
              ?.map((e) => StorageSpace.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now(),
      isPutAway: json['is_put_away'] ?? false,
    );
  }
}

class StorageListScreen extends StatefulWidget {
  const StorageListScreen({super.key});

  @override
  State<StorageListScreen> createState() => _StorageListScreenState();
}

class _StorageListScreenState extends State<StorageListScreen> {
  bool _hasChanges = false;
  final StorageService storageService = StorageService();
  List<StorageSpace> _storages = [];
  bool _isLoading = true;
  Set<String> _expandedStorages = {};

  @override
  void initState() {
    super.initState();
    _loadStorages();
  }

  String _toBackendStorageType(StorageType type) {
    return type == StorageType.others ? 'other' : type.name;
  }

  int _totalStorageCount(List<StorageSpace> storages) {
    return storages.fold<int>(
      0,
      (sum, s) => sum + 1 + _totalStorageCount(s.subStorages),
    );
  }

  int _totalItemCount(List<StorageSpace> storages) {
    return storages.fold<int>(
      0,
      (sum, s) => sum + s.itemCount + _totalItemCount(s.subStorages),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _loadStorages() async {
    setState(() => _isLoading = true);

    try {
      final result = await storageService.getAll();
      final topLevel = result
          .where((s) => s['parent_storage'] == null)
          .map((s) => StorageSpace.fromJson(s))
          .toList();

      setState(() {
        _storages = topLevel;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _storages = [];
        _isLoading = false;
      });
      _showError('Failed to load storages');
    }
  }

  void _toggleExpanded(String storageId) {
    setState(() {
      if (_expandedStorages.contains(storageId)) {
        _expandedStorages.remove(storageId);
      } else {
        _expandedStorages.add(storageId);
      }
    });
  }

  void _showAddStorageDialog({String? parentId, String? parentName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddStorageSheet(
        parentId: parentId,
        parentName: parentName,
        onSave: (name, type) {
          _addStorage(name, type, parentId);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditStorageDialog(StorageSpace storage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditStorageSheet(
        storage: storage,
        onSave: (name, type) {
          _updateStorage(storage.id, name, type);
          Navigator.pop(context);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteStorage(storage.id);
        },
      ),
    );
  }

  Future<void> _addStorage(
    String name,
    StorageType type,
    String? parentId,
  ) async {
    try {
      await storageService.create(
        name: name,
        type: _toBackendStorageType(type),
        parentStorage: parentId == null ? null : int.tryParse(parentId),
      );
      _showSuccess('Storage "$name" added successfully');
      await _loadStorages();
      _hasChanges = true;
    } catch (e) {
      _showError('Failed to add storage');
    }
  }

  Future<void> _updateStorage(String id, String name, StorageType type) async {
    try {
      await storageService.update(
        id: int.parse(id),
        name: name,
        type: _toBackendStorageType(type),
      );
      _showSuccess('Storage updated successfully');
      await _loadStorages();
      _hasChanges = true;
    } catch (e) {
      _showError('Failed to update storage');
    }
  }

  Future<void> _deleteStorage(String id) async {
    try {
      await storageService.delete(int.parse(id));
      _showSuccess('Storage deleted successfully');
      await _loadStorages();
      _hasChanges = true;
    } catch (e) {
      _showError('Unable to delete storage. Remove items/sub-storages first.');
    }
  }

  void _navigateToStorageDetail(StorageSpace storage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${storage.name}...'),
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorageDetailScreen(storageId: int.parse(storage.id)),
      ),
    ).then((_) => _loadStorages());
  }

  IconData _getStorageIcon(StorageType type) {
    switch (type) {
      case StorageType.closet:
        return Icons.door_front_door_outlined;
      case StorageType.wardrobe:
        return Icons.checkroom_outlined;
      case StorageType.cupboard:
        return Icons.kitchen_outlined;
      case StorageType.drawer:
        return Icons.dashboard_outlined;
      case StorageType.box:
        return Icons.inventory_2_outlined;
      case StorageType.shelf:
        return Icons.shelves;
      case StorageType.others:
        return Icons.storage_outlined;
    }
  }

  Color _getStorageColor(StorageType type) {
    switch (type) {
      case StorageType.closet:
      case StorageType.wardrobe:
        return const Color(0xFF1A1A1A);
      case StorageType.cupboard:
        return const Color(0xFF374151);
      case StorageType.drawer:
        return const Color(0xFF4B5563);
      case StorageType.box:
        return const Color(0xFF6B7280);
      case StorageType.shelf:
        return const Color(0xFF9CA3AF);
      case StorageType.others:
        return const Color(0xFFD1D5DB);
    }
  }

  Widget _buildStorageCard(StorageSpace storage, {int depth = 0}) {
    final hasSubStorages = storage.subStorages.isNotEmpty;
    final isExpanded = _expandedStorages.contains(storage.id);
    final indentPadding = depth * 20.0;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(left: indentPadding, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToStorageDetail(storage),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStorageColor(
                              storage.type,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getStorageIcon(storage.type),
                            size: 20,
                            color: _getStorageColor(storage.type),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                storage.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    storage.type.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF9CA3AF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE5E7EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${storage.itemCount} items',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        Column(
                          children: [
                            Switch(
                              value: storage.isPutAway,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) async {
                                final oldValue = storage.isPutAway;

                                // optimistic update
                                setState(() => storage.isPutAway = val);

                                try {
                                  await storageService.togglePutAway(
                                    int.parse(storage.id),
                                    val,
                                  );
                                } catch (_) {
                                  // rollback if failed
                                  setState(() => storage.isPutAway = oldValue);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Failed to update"),
                                    ),
                                  );
                                }
                              },
                            ),
                            const Text(
                              "Put Away",
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        if (hasSubStorages)
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF6B7280),
                            ),
                            onPressed: () => _toggleExpanded(storage.id),
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF6B7280),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'add_sub':
                                _showAddStorageDialog(
                                  parentId: storage.id,
                                  parentName: storage.name,
                                );
                                break;
                              case 'edit':
                                _showEditStorageDialog(storage);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'add_sub',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Add Sub-Storage'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Edit Storage'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasSubStorages && isExpanded)
          ...storage.subStorages.map(
            (subStorage) => _buildStorageCard(subStorage, depth: depth + 1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F9FA),
          elevation: 0,
          title: const Text(
            'Storage Spaces',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
              onPressed: _loadStorages,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A1A1A)),
              )
            : _storages.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadStorages,
                color: const Color(0xFF1A1A1A),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A1A), Color(0xFF374151)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              'Total Storages',
                              '${_totalStorageCount(_storages)}',
                              Icons.inventory_2_outlined,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'Total Items',
                              '${_totalItemCount(_storages)}',
                              Icons.checkroom_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Storages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${_totalStorageCount(_storages)} spaces',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._storages.map((storage) => _buildStorageCard(storage)),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddStorageDialog(),
          backgroundColor: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add Storage',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Storage Spaces Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first storage space to start\norganizing your wardrobe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddStorageDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Storage Space'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add Storage Bottom Sheet
class AddStorageSheet extends StatefulWidget {
  final String? parentId;
  final String? parentName;
  final Function(String name, StorageType type) onSave;

  const AddStorageSheet({
    super.key,
    this.parentId,
    this.parentName,
    required this.onSave,
  });

  @override
  State<AddStorageSheet> createState() => _AddStorageSheetState();
}

class _AddStorageSheetState extends State<AddStorageSheet> {
  final _nameController = TextEditingController();
  StorageType _selectedType = StorageType.closet;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.parentId != null
                          ? 'Add Sub-Storage'
                          : 'Add Storage Space',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.parentName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Inside ${widget.parentName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Storage Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'e.g., Master Bedroom Closet',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1A1A1A),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Storage Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StorageType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(
                    type.name[0].toUpperCase() + type.name.substring(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedType = type);
                  },
                  backgroundColor: const Color(0xFFF8F9FA),
                  selectedColor: const Color(0xFF1A1A1A),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE5E7EB),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: 'Create Storage',
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    widget.onSave(_nameController.text.trim(), _selectedType);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Edit Storage Bottom Sheet
class EditStorageSheet extends StatefulWidget {
  final StorageSpace storage;
  final Function(String name, StorageType type) onSave;
  final VoidCallback onDelete;

  const EditStorageSheet({
    super.key,
    required this.storage,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditStorageSheet> createState() => _EditStorageSheetState();
}

class _EditStorageSheetState extends State<EditStorageSheet> {
  late TextEditingController _nameController;
  late StorageType _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.storage.name);
    _selectedType = widget.storage.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Storage?',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.storage.name}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Storage',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _confirmDelete,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Storage Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Storage name',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1A1A1A),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Storage Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StorageType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(
                    type.name[0].toUpperCase() + type.name.substring(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedType = type);
                  },
                  backgroundColor: const Color(0xFFF8F9FA),
                  selectedColor: const Color(0xFF1A1A1A),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE5E7EB),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: 'Save Changes',
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    widget.onSave(_nameController.text.trim(), _selectedType);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
