import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/services/accessory_service.dart';
import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/theme/app_theme.dart';

class UploadAccessoryScreen extends StatefulWidget {
  final int storageId;

  const UploadAccessoryScreen({super.key, required this.storageId});

  @override
  State<UploadAccessoryScreen> createState() => _UploadAccessoryScreenState();
}

class _UploadAccessoryScreenState extends State<UploadAccessoryScreen> {
  final AccessoryService _service = ServiceRegistry.instance.accessoryService;
  final ClothingService _clothingService =
      ServiceRegistry.instance.clothingService;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _dominantCtrl = TextEditingController();
  final TextEditingController _secondaryCtrl = TextEditingController();

  File? _selectedImage;
  String? _segmentedUrl;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _dominantCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;
    final selected = File(picked.path);

    setState(() {
      _selectedImage = selected;
      _loading = true;
    });

    try {
      final result = await _service.process(_selectedImage!);
      if (result == null) throw 'Segmentation failed';
      setState(() {
        _segmentedUrl = result['segmented_image']?.toString();
        _dominantCtrl.text = (result['dominant_color'] ?? '').toString();
        _secondaryCtrl.text = (result['secondary_color'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _selectedImage = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accessory segmentation failed')),
      );
    }
  }

  Future<void> _save() async {
    final segmented = _segmentedUrl;
    final name = _nameCtrl.text.trim();
    if (segmented == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image and accessory name are required')),
      );
      return;
    }

    setState(() => _loading = true);
    final ok = await _service.save({
      'storage_unit': widget.storageId,
      'segmented_image': segmented,
      'name': name,
      'description': _descriptionCtrl.text.trim(),
      'dominant_color': _dominantCtrl.text.trim(),
      'secondary_color': _secondaryCtrl.text.trim().isEmpty
          ? null
          : _secondaryCtrl.text.trim(),
    });
    setState(() => _loading = false);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Failed to save accessory')));
  }

  Future<void> _retake() async {
    if (_segmentedUrl != null) {
      await _clothingService.deleteSegmented(_segmentedUrl!);
    }
    setState(() {
      _selectedImage = null;
      _segmentedUrl = null;
      _dominantCtrl.clear();
      _secondaryCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UploadTokens.pageBg,
      appBar: AppBar(
        backgroundColor: UploadTokens.surface,
        foregroundColor: UploadTokens.ink,
        title: const Text('Upload Accessory'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_selectedImage == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Pick from gallery'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Use camera'),
                      ),
                    ),
                  ],
                ),
              if (_selectedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 300,
                    color: UploadTokens.surface,
                    child: _segmentedUrl == null
                        ? Image.file(_selectedImage!, fit: BoxFit.contain)
                        : Image.network(
                            _segmentedUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.contain,
                                ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_segmentedUrl != null)
                  const Text(
                    'Segmented Preview',
                    style: TextStyle(fontSize: 12, color: UploadTokens.muted),
                  ),
                if (_segmentedUrl != null) const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake image'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Accessory name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dominantCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dominant color',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _secondaryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Secondary color',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: UploadTokens.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Accessory'),
              ),
            ],
          ),
          if (_loading)
            Container(
              color: UploadTokens.black.withValues(alpha: 0.38),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
