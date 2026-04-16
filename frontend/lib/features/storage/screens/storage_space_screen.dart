import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:frontend/widgets/primary_buttons.dart';
import 'package:frontend/features/storage/screens/storage_detail_screen.dart';
import 'package:frontend/theme/app_theme.dart';

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
  final bool embedded;

  const StorageListScreen({super.key, this.embedded = false});

  @override
  State<StorageListScreen> createState() => _StorageListScreenState();
}

class _StorageListScreenState extends State<StorageListScreen> {
  bool _hasChanges = false;
  final StorageService storageService = ServiceRegistry.instance.storageService;
  List<StorageSpace> _storages = [];
  bool _isLoading = true;
  final Set<String> _expandedStorages = {};

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
      SnackBar(content: Text(message), backgroundColor: StorageTokens.success),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: StorageTokens.danger),
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
      backgroundColor: StorageTokens.transparent,
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
      backgroundColor: StorageTokens.transparent,
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
        return StorageTokens.ink;
      case StorageType.cupboard:
        return StorageTokens.slate;
      case StorageType.drawer:
        return StorageTokens.slateSoft;
      case StorageType.box:
        return StorageTokens.muted;
      case StorageType.shelf:
        return StorageTokens.mutedSoft;
      case StorageType.others:
        return StorageTokens.lineQuiet;
    }
  }

  Widget _buildStorageCard(StorageSpace storage, {int depth = 0}) {
    final hasSubStorages = storage.subStorages.isNotEmpty;
    final isExpanded = _expandedStorages.contains(storage.id);
    final indentPadding = depth * 20.0;
    final statusLabel = storage.isPutAway ? 'Put Away' : 'Active';
    final statusColor = storage.isPutAway
        ? StorageTokens.success
        : StorageTokens.muted;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(left: indentPadding, bottom: 14),
          decoration: BoxDecoration(
            color: StorageTokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: StorageTokens.line),
            boxShadow: [
              BoxShadow(
                color: StorageTokens.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: StorageTokens.transparent,
            child: InkWell(
              onTap: () => _navigateToStorageDetail(storage),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStorageColor(
                              storage.type,
                            ).withValues(alpha: 0.1),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: StorageTokens.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${storage.type.name.toUpperCase()} - ${storage.itemCount} items',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: StorageTokens.mutedSoft,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: StorageTokens.muted,
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
                                    color: StorageTokens.ink,
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
                                    color: StorageTokens.ink,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (hasSubStorages)
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: StorageTokens.muted,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _toggleExpanded(storage.id),
                          ),
                        Switch(
                          value: storage.isPutAway,
                          activeThumbColor: StorageTokens.success,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
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
                              if (!mounted) return;
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
    if (widget.embedded) {
      return Stack(
        children: [
          Positioned.fill(
            child: Container(color: StorageTokens.pageBg, child: _buildBody()),
          ),
          Positioned(right: 20, bottom: 20, child: _buildAddStorageFab()),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
        backgroundColor: StorageTokens.pageBg,
        appBar: AppBar(
          backgroundColor: StorageTokens.pageBg,
          elevation: 0,
          title: const Text(
            'Storage Spaces',
            style: TextStyle(
              color: StorageTokens.ink,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: StorageTokens.ink),
              onPressed: _loadStorages,
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: _buildAddStorageFab(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: StorageTokens.ink),
      );
    }

    if (_storages.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadStorages,
      color: StorageTokens.ink,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, widget.embedded ? 96 : 20),
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  StorageTokens.analyticsStart,
                  StorageTokens.analyticsEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: StorageTokens.onAnalytics.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: StorageTokens.black.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
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
                      color: StorageTokens.onAnalytics.withValues(alpha: 0.2),
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
                const SizedBox(height: 10),
                Text(
                  'Tap any storage card to view details or move items.',
                  style: TextStyle(
                    fontSize: 11,
                    color: StorageTokens.onAnalytics.withValues(alpha: 0.78),
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
                  color: StorageTokens.ink,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${_totalStorageCount(_storages)} spaces',
                style: const TextStyle(
                  fontSize: 13,
                  color: StorageTokens.mutedSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._storages.map((storage) => _buildStorageCard(storage)),
        ],
      ),
    );
  }

  Widget _buildAddStorageFab() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddStorageDialog(),
      backgroundColor: WidgetTokens.accent,
      icon: const Icon(Icons.add, color: StorageTokens.surface),
      label: const Text(
        'Add Storage',
        style: TextStyle(
          color: StorageTokens.surface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: StorageTokens.onAnalytics.withValues(alpha: 0.8),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: StorageTokens.onAnalytics,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: StorageTokens.onAnalytics.withValues(alpha: 0.7),
          ),
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
                color: StorageTokens.pageBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: StorageTokens.mutedSoft,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Storage Spaces Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: StorageTokens.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first storage space to start\norganizing your wardrobe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: StorageTokens.mutedSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddStorageDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Storage Space'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WidgetTokens.accent,
                foregroundColor: StorageTokens.surface,
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
        color: StorageTokens.surface,
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
                        color: StorageTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.parentName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Inside ${widget.parentName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: StorageTokens.mutedSoft,
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: StorageTokens.muted),
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
                color: StorageTokens.muted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: StorageTokens.ink),
              decoration: InputDecoration(
                hintText: 'e.g., Master Bedroom Closet',
                hintStyle: const TextStyle(color: StorageTokens.mutedSoft),
                filled: true,
                fillColor: StorageTokens.pageBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StorageTokens.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StorageTokens.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: StorageTokens.ink,
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
                color: StorageTokens.muted,
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
                          ? StorageTokens.surface
                          : StorageTokens.ink,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedType = type);
                  },
                  backgroundColor: StorageTokens.pageBg,
                  selectedColor: StorageTokens.ink,
                  side: BorderSide(
                    color: isSelected ? StorageTokens.ink : StorageTokens.line,
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
            color: StorageTokens.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.storage.name}"? This action cannot be undone.',
          style: const TextStyle(color: StorageTokens.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: StorageTokens.muted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: StorageTokens.dangerStrong),
            ),
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
        color: StorageTokens.surface,
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
                    color: StorageTokens.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: StorageTokens.dangerStrong,
                      ),
                      onPressed: _confirmDelete,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: StorageTokens.muted),
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
                color: StorageTokens.muted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 15, color: StorageTokens.ink),
              decoration: InputDecoration(
                hintText: 'Storage name',
                hintStyle: const TextStyle(color: StorageTokens.mutedSoft),
                filled: true,
                fillColor: StorageTokens.pageBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StorageTokens.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StorageTokens.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: StorageTokens.ink,
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
                color: StorageTokens.muted,
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
                          ? StorageTokens.surface
                          : StorageTokens.ink,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedType = type);
                  },
                  backgroundColor: StorageTokens.pageBg,
                  selectedColor: StorageTokens.ink,
                  side: BorderSide(
                    color: isSelected ? StorageTokens.ink : StorageTokens.line,
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
