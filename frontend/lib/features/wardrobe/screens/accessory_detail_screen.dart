import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:frontend/services/accessory_service.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/theme/app_theme.dart';

class AccessoryDetailScreen extends StatefulWidget {
  final int accessoryId;
  final Map<String, dynamic>? initialData;

  const AccessoryDetailScreen({
    super.key,
    required this.accessoryId,
    this.initialData,
  });

  @override
  State<AccessoryDetailScreen> createState() => _AccessoryDetailScreenState();
}

class _AccessoryDetailScreenState extends State<AccessoryDetailScreen> {
  final AccessoryService _service = ServiceRegistry.instance.accessoryService;

  Map<String, dynamic>? _item;
  bool _loading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _item = widget.initialData;
    _load();
  }

  Future<void> _load() async {
    final latest = await _service.getById(widget.accessoryId);
    if (!mounted) return;
    setState(() {
      _item = latest ?? _item;
      _loading = false;
    });
  }

  String _imageOf(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }

  String _formatDate(dynamic raw) {
    final dt = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (dt == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _toast(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: err
            ? WardrobeTokens.dangerStrong
            : WardrobeTokens.inkStrong,
      ),
    );
  }

  Future<void> _toggleFavourite() async {
    final item = _item;
    if (item == null) return;
    final current = item['is_favourite'] == true;
    setState(() => item['is_favourite'] = !current);
    final ok = await _service.toggleFavourite(widget.accessoryId);
    if (!mounted) return;
    if (!ok) {
      setState(() => item['is_favourite'] = current);
      _toast('Failed to update favourite', err: true);
      return;
    }
    _hasChanges = true;
  }

  Future<void> _deleteAccessory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete accessory?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: WardrobeTokens.dangerStrong,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await _service.delete(widget.accessoryId);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context, true);
      return;
    }
    _toast('Failed to delete accessory', err: true);
  }

  Future<void> _editAccessory() async {
    final item = _item;
    if (item == null) return;
    final nameCtrl = TextEditingController(
      text: (item['name'] ?? '').toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (item['description'] ?? '').toString(),
    );
    final dominantCtrl = TextEditingController(
      text: (item['dominant_color'] ?? '').toString(),
    );
    final secondaryCtrl = TextEditingController(
      text: (item['secondary_color'] ?? '').toString(),
    );

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WardrobeTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dominantCtrl,
                decoration: const InputDecoration(labelText: 'Dominant color'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: secondaryCtrl,
                decoration: const InputDecoration(labelText: 'Secondary color'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: WardrobeTokens.inkStrong,
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (save != true) {
      nameCtrl.dispose();
      descriptionCtrl.dispose();
      dominantCtrl.dispose();
      secondaryCtrl.dispose();
      return;
    }

    final payload = {
      'name': nameCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'dominant_color': dominantCtrl.text.trim().isEmpty
          ? 'Unknown'
          : dominantCtrl.text.trim(),
      'secondary_color': secondaryCtrl.text.trim().isEmpty
          ? null
          : secondaryCtrl.text.trim(),
    };
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    dominantCtrl.dispose();
    secondaryCtrl.dispose();

    if ((payload['name'] as String).isEmpty) {
      _toast('Name is required', err: true);
      return;
    }

    final ok = await _service.update(widget.accessoryId, payload);
    if (!mounted) return;
    if (!ok) {
      _toast('Failed to save changes', err: true);
      return;
    }
    setState(() => _item = {...item, ...payload});
    _hasChanges = true;
    _toast('Accessory updated');
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accessory')),
        body: const Center(child: Text('Accessory not found')),
      );
    }

    final image = _imageOf(item['image']);
    final name = (item['name'] ?? 'Accessory').toString();
    final description = (item['description'] ?? '').toString();
    final dominant = (item['dominant_color'] ?? '').toString();
    final secondary = (item['secondary_color'] ?? '').toString();
    final createdAt = _formatDate(item['created_at']);
    final isFav = item['is_favourite'] == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
        backgroundColor: WardrobeTokens.pageWarm,
        appBar: AppBar(
          backgroundColor: WardrobeTokens.surface,
          foregroundColor: WardrobeTokens.inkStrong,
          title: const Text('Accessory Detail'),
          actions: [
            IconButton(
              onPressed: _toggleFavourite,
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav
                    ? WardrobeTokens.dangerStrong
                    : WardrobeTokens.inkStrong,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 300,
                color: WardrobeTokens.surface,
                child: image.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 44,
                          color: WardrobeTokens.lineQuiet,
                        ),
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 44,
                            color: WardrobeTokens.lineQuiet,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WardrobeTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WardrobeTokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: WardrobeTokens.inkStrong,
                    ),
                  ),
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: WardrobeTokens.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (dominant.trim().isNotEmpty)
                        _chip('Dominant: $dominant'),
                      if (secondary.trim().isNotEmpty)
                        _chip('Secondary: $secondary'),
                      if (createdAt.isNotEmpty) _chip('Added: $createdAt'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _editAccessory,
                style: FilledButton.styleFrom(
                  backgroundColor: WardrobeTokens.inkStrong,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Accessory'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteAccessory,
                icon: const Icon(Icons.delete_outline),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WardrobeTokens.dangerStrong,
                ),
                label: const Text('Delete Accessory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: WardrobeTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: WardrobeTokens.inkStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
