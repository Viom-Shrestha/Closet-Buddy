import 'dart:io';
import 'package:frontend/widgets/hover_clickable.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/clothing_service.dart';
import 'package:frontend/theme/app_theme.dart';

enum UploadStep { selectImage, reviewing, editing }

class UploadClothingScreen extends StatefulWidget {
  final int storageId;
  final bool isShoe;

  const UploadClothingScreen({
    super.key,
    required this.storageId,
    this.isShoe = false,
  });

  @override
  State<UploadClothingScreen> createState() => _UploadClothingScreenState();
}

class _UploadClothingScreenState extends State<UploadClothingScreen> {
  final ClothingService clothingService =
      ServiceRegistry.instance.clothingService;
  final ImagePicker picker = ImagePicker();

  UploadStep currentStep = UploadStep.selectImage;
  File? selectedImage;
  String? segmentedUrl;
  bool isLoading = false;

  // Extracted metadata
  String category = '';
  String subcategory = '';
  String dominantColor = '';
  String secondaryColor = '';
  String occasion = '';
  List<String> attributes = [];

  late TextEditingController categoryController;
  late TextEditingController subcategoryController;
  late TextEditingController dominantColorController;
  late TextEditingController secondaryColorController;
  late TextEditingController occasionController;
  late TextEditingController attributesController;

  @override
  void initState() {
    super.initState();

    categoryController = TextEditingController();
    subcategoryController = TextEditingController();
    dominantColorController = TextEditingController();
    secondaryColorController = TextEditingController();
    occasionController = TextEditingController();
    attributesController = TextEditingController();
  }

  @override
  void dispose() {
    categoryController.dispose();
    subcategoryController.dispose();
    dominantColorController.dispose();
    secondaryColorController.dispose();
    occasionController.dispose();
    attributesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);

    if (picked == null) return;
    final original = File(picked.path);
    final shouldCrop = await _askCropChoice();
    if (shouldCrop == null) return;

    final selected = shouldCrop ? await _cropImage(original) : original;
    if (selected == null) return;

    setState(() {
      selectedImage = selected;
      isLoading = true;
    });

    await _processImage();
  }

  Future<bool?> _askCropChoice() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: UploadTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prepare Image',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Do you want to crop the image before segmentation?',
                style: TextStyle(fontSize: 13, color: UploadTokens.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Use Original'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: UploadTokens.ink,
                      ),
                      child: const Text('Crop Image'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File?> _cropImage(File source) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cropping is not supported on this platform yet. Using original image.',
            ),
          ),
        );
      }
      return source;
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: source.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Clothing',
            toolbarColor: UploadTokens.surface,
            toolbarWidgetColor: UploadTokens.ink,
            statusBarColor: UploadTokens.surface,
            backgroundColor: UploadTokens.pageBg,
            activeControlsWidgetColor: UploadTokens.ink,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Clothing', aspectRatioLockEnabled: false),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cropping failed. Using original image instead.'),
          ),
        );
      }
      return source;
    }
  }

  Future<void> _processImage() async {
    if (!mounted) return;

    try {
      final result = await clothingService.process(
        selectedImage!,
        isShoe: widget.isShoe,
      );

      if (result == null) throw "Processing failed";
      if (!mounted) return;

      setState(() {
        segmentedUrl = result['segmented_image'];

        category = result['category'];
        subcategory = result['subcategory'];
        dominantColor = result['dominant_color'];
        secondaryColor = result['secondary_color'];
        occasion = result['occasion'];
        attributes = List<String>.from(result['attributes'] ?? const []);

        // ✅ update controllers AFTER values exist
        categoryController.text = category;
        subcategoryController.text = subcategory;
        dominantColorController.text = dominantColor;
        secondaryColorController.text = secondaryColor;
        occasionController.text = occasion;
        attributesController.text = attributes.join(', ');

        isLoading = false;
        currentStep = UploadStep.reviewing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        currentStep = UploadStep.selectImage;
        selectedImage = null;
      });

      if (e is Map && e["type"] == "not_clothing") {
        final confidence = (e["confidence"] * 100).toStringAsFixed(1);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "This doesn’t look like clothing.\nAI confidence: $confidence%",
            ),
            backgroundColor: UploadTokens.dangerStrong,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Processing failed")));
    }
  }

  Future<void> _saveClothing() async {
    if (segmentedUrl == null) return;

    setState(() => isLoading = true);

    final payload = {
      "storage_unit": widget.storageId,
      "segmented_image": segmentedUrl,
      "category": category,
      "subcategory": subcategory,
      "dominant_color": dominantColor,
      "secondary_color": secondaryColor,
      "occasion": occasion,
      "attributes": attributes,
    };

    final success = await clothingService.save(payload);

    if (!mounted) return;
    setState(() => isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clothing saved successfully"),
          backgroundColor: UploadTokens.success,
          duration: Duration(seconds: 1),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pop(context, true); // IMPORTANT
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save clothing")));
    }
  }

  Future<void> _retakePhoto() async {
    if (segmentedUrl != null) {
      await clothingService.deleteSegmented(segmentedUrl!);
    }
    setState(() {
      selectedImage = null;
      segmentedUrl = null;

      category = '';
      subcategory = '';
      dominantColor = '';
      secondaryColor = '';
      occasion = '';
      attributes = [];

      categoryController.clear();
      subcategoryController.clear();
      dominantColorController.clear();
      secondaryColorController.clear();
      occasionController.clear();
      attributesController.clear();

      currentStep = UploadStep.selectImage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UploadTokens.pageBg,
      appBar: AppBar(
        backgroundColor: UploadTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: UploadTokens.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isShoe ? 'Upload Shoes' : 'Upload Clothing',
          style: TextStyle(
            color: UploadTokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: UploadTokens.line),
        ),
      ),
      body: Stack(
        children: [
          _buildCurrentStep(),
          if (isLoading)
            Container(
              color: UploadTokens.black.withValues(alpha: 0.54),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        UploadTokens.surface,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _getLoadingMessage(),
                      style: TextStyle(
                        color: UploadTokens.surface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case UploadStep.selectImage:
        return _buildImageSelector();
      case UploadStep.reviewing:
        return _buildReviewSegmentation();
      case UploadStep.editing:
        return _buildEditMetadata();
    }
  }

  Widget _buildImageSelector() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isShoe ? 'Upload your shoes' : 'Upload your clothing',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: UploadTokens.ink,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.isShoe
                ? 'Take a shoe photo, crop it, and continue'
                : 'Take a photo, crop it, and continue',
            style: TextStyle(fontSize: 15, color: UploadTokens.muted),
          ),
          SizedBox(height: 40),
          _buildUploadButton(
            icon: Icons.photo_library_outlined,
            title: 'Choose from Gallery',
            description: 'Select an existing photo',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          SizedBox(height: 16),
          _buildUploadButton(
            icon: Icons.camera_alt_outlined,
            title: 'Take Photo',
            description: 'Use your camera to capture',
            onTap: () {
              if (Platform.isWindows) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Camera only works on mobile devices"),
                  ),
                );
                return;
              }
              _pickImage(ImageSource.camera);
            },
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UploadTokens.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: UploadTokens.info.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: UploadTokens.info,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For best results, use a clear photo with good lighting and plain background',
                    style: TextStyle(fontSize: 13, color: UploadTokens.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return HoverClickable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: UploadTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UploadTokens.line),
          boxShadow: [
            BoxShadow(
              color: UploadTokens.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: UploadTokens.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: UploadTokens.ink, size: 28),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: UploadTokens.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: UploadTokens.muted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: UploadTokens.mutedSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSegmentation() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review segmentation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: UploadTokens.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI has isolated the clothing item',
                  style: TextStyle(fontSize: 15, color: UploadTokens.muted),
                ),
                SizedBox(height: 24),
                if (segmentedUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      segmentedUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 300,
                        color: UploadTokens.surfaceSoft,
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: UploadTokens.mutedSoft,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UploadTokens.surface,
            border: Border(top: BorderSide(color: UploadTokens.line)),
            boxShadow: [
              BoxShadow(
                color: UploadTokens.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => currentStep = UploadStep.editing);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UploadTokens.ink,
                      foregroundColor: UploadTokens.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Looks Good',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _retakePhoto,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UploadTokens.ink,
                      side: BorderSide(color: UploadTokens.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Retake Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditMetadata() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Edit Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: UploadTokens.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI has extracted these details. You can edit them.',
                  style: TextStyle(fontSize: 15, color: UploadTokens.muted),
                ),
                SizedBox(height: 24),
                if (segmentedUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      segmentedUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                SizedBox(height: 24),
                _buildTextField(
                  'Category',
                  categoryController,
                  (val) => category = val,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Subcategory',
                  subcategoryController,
                  (val) => subcategory = val,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Primary Color',
                  dominantColorController,
                  (val) => dominantColor = val,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Secondary Color',
                  secondaryColorController,
                  (val) => secondaryColor = val,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Occasion',
                  occasionController,
                  (val) => occasion = val,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Attributes (comma separated)',
                  attributesController,
                  (val) => attributes = _splitAttributes(val),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UploadTokens.surface,
            border: Border(top: BorderSide(color: UploadTokens.line)),
            boxShadow: [
              BoxShadow(
                color: UploadTokens.black.withValues(alpha: 0.04),
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
                onPressed: isLoading ? null : _saveClothing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UploadTokens.success,
                  foregroundColor: UploadTokens.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save to Wardrobe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: UploadTokens.ink,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15, color: UploadTokens.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: UploadTokens.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: UploadTokens.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: UploadTokens.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: UploadTokens.ink, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  String _getLoadingMessage() {
    return widget.isShoe ? 'Processing shoes...' : 'Processing clothing...';
  }

  List<String> _splitAttributes(String value) {
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
}
