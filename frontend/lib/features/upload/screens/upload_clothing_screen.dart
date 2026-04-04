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
  String? originalImageUrl;
  bool useOriginalImage = false;
  bool segmentationFailed = false;
  String? segmentationNotice;
  bool isLoading = false;

  // Extracted metadata
  String category = '';
  String subcategory = '';
  String dominantColor = '';
  String secondaryColor = '';
  String occasion = '';
  String detectedTemp = '';
  String detectedWeather = '';
  List<String> attributes = [];

  late TextEditingController categoryController;
  late TextEditingController subcategoryController;
  late TextEditingController dominantColorController;
  late TextEditingController secondaryColorController;
  late TextEditingController occasionController;
  late TextEditingController detectedTempController;
  late TextEditingController detectedWeatherController;
  late TextEditingController attributesController;

  @override
  void initState() {
    super.initState();

    categoryController = TextEditingController();
    subcategoryController = TextEditingController();
    dominantColorController = TextEditingController();
    secondaryColorController = TextEditingController();
    occasionController = TextEditingController();
    detectedTempController = TextEditingController();
    detectedWeatherController = TextEditingController();
    attributesController = TextEditingController();
  }

  @override
  void dispose() {
    categoryController.dispose();
    subcategoryController.dispose();
    dominantColorController.dispose();
    secondaryColorController.dispose();
    occasionController.dispose();
    detectedTempController.dispose();
    detectedWeatherController.dispose();
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
      segmentedUrl = null;
      originalImageUrl = null;
      useOriginalImage = false;
      segmentationFailed = false;
      segmentationNotice = null;
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

      final parsedSegmented = _safeText(result['segmented_image']);
      final parsedOriginal = _safeText(result['original_image']);
      final hasSegmented = parsedSegmented.isNotEmpty;
      final hasOriginal = parsedOriginal.isNotEmpty;
      final failedFromApi = result['segmentation_failed'] == true;
      final fallbackToOriginal = failedFromApi || (!hasSegmented && hasOriginal);
      final segmentationMessage = _safeText(result['segmentation_message']);

      setState(() {
        segmentedUrl = hasSegmented ? parsedSegmented : null;
        originalImageUrl = hasOriginal ? parsedOriginal : null;
        segmentationFailed = fallbackToOriginal;
        useOriginalImage = fallbackToOriginal;
        segmentationNotice = fallbackToOriginal
            ? (segmentationMessage.isNotEmpty
                  ? segmentationMessage
                  : 'Segmentation failed. You can continue without segmentation.')
            : null;

        category = _safeText(result['category']);
        subcategory = _safeText(result['subcategory']);
        dominantColor = _safeText(result['dominant_color']);
        secondaryColor = _safeText(result['secondary_color']);
        occasion = _safeText(result['occasion']);
        detectedTemp = _safeText(result['detected_temp']);
        detectedWeather = _safeText(result['detected_weather']);
        attributes = _extractTags(result);

        // ✅ update controllers AFTER values exist
        categoryController.text = category;
        subcategoryController.text = subcategory;
        dominantColorController.text = dominantColor;
        secondaryColorController.text = secondaryColor;
        occasionController.text = occasion;
        detectedTempController.text = detectedTemp;
        detectedWeatherController.text = detectedWeather;
        attributesController.text = attributes.join(', ');

        isLoading = false;
        currentStep = UploadStep.reviewing;
      });

      if (fallbackToOriginal && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Segmentation failed. Showing original image.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      if (e is Map && e["type"] == "not_clothing") {
        setState(() {
          isLoading = false;
          currentStep = UploadStep.selectImage;
          selectedImage = null;
        });
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

      setState(() {
        isLoading = false;
        currentStep = UploadStep.selectImage;
        selectedImage = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Processing failed")));
    }
  }

  void _confirmSegmentationReview() {
    setState(() {
      if (segmentedUrl == null) {
        useOriginalImage = true;
      }
      currentStep = UploadStep.editing;
    });
  }

  void _continueWithoutSegmentation() {
    setState(() {
      useOriginalImage = true;
      currentStep = UploadStep.editing;
    });
  }

  Future<void> _redoSegmentation() async {
    if (selectedImage == null) return;
    setState(() {
      isLoading = true;
      segmentationNotice = null;
      segmentationFailed = false;
      useOriginalImage = false;
    });
    await _processImage();
  }

  Future<void> _saveClothing() async {
    final useSegmentation = !useOriginalImage && segmentedUrl != null;
    final sourceUrl = useSegmentation ? segmentedUrl : (originalImageUrl ?? segmentedUrl);
    if (sourceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No processed image available to save')),
      );
      return;
    }

    setState(() => isLoading = true);

    category = categoryController.text.trim();
    subcategory = subcategoryController.text.trim();
    dominantColor = dominantColorController.text.trim();
    secondaryColor = secondaryColorController.text.trim();
    occasion = occasionController.text.trim();
    detectedTemp = detectedTempController.text.trim();
    detectedWeather = detectedWeatherController.text.trim();
    attributes = _normalizeTags(_splitAttributes(attributesController.text));

    final payload = {
      "storage_unit": widget.storageId,
      "segmented_image": sourceUrl,
      "original_image": originalImageUrl,
      "use_segmentation": useSegmentation,
      "category": category,
      "subcategory": subcategory,
      "dominant_color": dominantColor,
      "secondary_color": secondaryColor,
      "occasion": occasion,
      "attributes": attributes,
      "detected_temp": detectedTemp,
      "detected_weather": detectedWeather,
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

  Future<void> _cleanupTemporaryImages() async {
    final cleanupUrls = <String>{};
    if (segmentedUrl != null && segmentedUrl!.trim().isNotEmpty) {
      cleanupUrls.add(segmentedUrl!);
    }
    if (originalImageUrl != null && originalImageUrl!.trim().isNotEmpty) {
      cleanupUrls.add(originalImageUrl!);
    }

    for (final url in cleanupUrls) {
      try {
        await clothingService.deleteSegmented(url);
      } catch (_) {
        // Cleanup is best-effort; don't block navigation if delete fails.
      }
    }
  }

  Future<void> _retakePhoto() async {
    await _cleanupTemporaryImages();
    setState(() {
      selectedImage = null;
      segmentedUrl = null;
      originalImageUrl = null;
      useOriginalImage = false;
      segmentationFailed = false;
      segmentationNotice = null;

      category = '';
      subcategory = '';
      dominantColor = '';
      secondaryColor = '';
      occasion = '';
      detectedTemp = '';
      detectedWeather = '';
      attributes = [];

      categoryController.clear();
      subcategoryController.clear();
      dominantColorController.clear();
      secondaryColorController.clear();
      occasionController.clear();
      detectedTempController.clear();
      detectedWeatherController.clear();
      attributesController.clear();

      currentStep = UploadStep.selectImage;
    });
  }

  Future<void> _handleBackPressed() async {
    if (isLoading) return;
    if (currentStep == UploadStep.reviewing) {
      await _retakePhoto();
      return;
    }
    if (currentStep == UploadStep.editing) {
      await _cleanupTemporaryImages();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: UploadTokens.pageBg,
        appBar: AppBar(
          backgroundColor: UploadTokens.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: UploadTokens.ink),
            onPressed: _handleBackPressed,
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
    final guidance = <String>[
      'Use bright, even lighting. Avoid dark shadows and heavy color tints.',
      'Lay the item on a flat, plain surface with good contrast from the clothing.',
      'Position the camera straight-on so the item is centered and properly aligned.',
      'Capture the full item in frame from top to bottom without cropping edges.',
      if (widget.isShoe)
        'Show the full shoe clearly (front/side visible), not covered by hands or objects.'
      else
        'Keep full sleeves or pant legs visible and facing the camera. Do not fold or tuck them.',
      'Avoid wrinkles, clutter, overlapping items, blur, and tilted shots.',
    ];

    return SingleChildScrollView(
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
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UploadTokens.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: UploadTokens.info.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: UploadTokens.info,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Photo Guidelines',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: UploadTokens.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ...guidance.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: UploadTokens.info,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: UploadTokens.ink,
                            ),
                          ),
                        ),
                      ],
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
    final previewingOriginal = useOriginalImage || segmentedUrl == null;
    final canContinueWithoutSegmentation =
        originalImageUrl != null || selectedImage != null;

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
                  previewingOriginal
                      ? 'Previewing original image'
                      : 'AI has isolated the clothing item',
                  style: TextStyle(fontSize: 15, color: UploadTokens.muted),
                ),
                if (segmentationFailed && segmentationNotice != null) ...[
                  SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UploadTokens.dangerStrong.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: UploadTokens.dangerStrong.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: UploadTokens.dangerStrong,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            segmentationNotice!,
                            style: TextStyle(
                              fontSize: 13,
                              color: UploadTokens.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24),
                _buildProcessedPreview(height: 320),
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
                    onPressed: _confirmSegmentationReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UploadTokens.ink,
                      foregroundColor: UploadTokens.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm',
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
                    onPressed: canContinueWithoutSegmentation
                        ? _continueWithoutSegmentation
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UploadTokens.ink,
                      side: BorderSide(color: UploadTokens.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue Without Segmentation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: _redoSegmentation,
                    icon: Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Redo Segmentation',
                      style: TextStyle(
                        fontSize: 15,
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
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: UploadTokens.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: UploadTokens.info.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'Please review and correct AI-extracted details. Accurate data is important for better recommendations and overall performance.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: UploadTokens.ink,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                _buildProcessedPreview(height: 220),
                if (useOriginalImage) ...[
                  SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: UploadTokens.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: UploadTokens.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Using original image without segmentation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: UploadTokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 24),
                _buildMetadataSummary(),
                SizedBox(height: 16),
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
                  'Temperature',
                  detectedTempController,
                  (val) => detectedTemp = val.trim(),
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Weather',
                  detectedWeatherController,
                  (val) => detectedWeather = val.trim(),
                ),
                SizedBox(height: 16),
                _buildTextField(
                  'Tags (comma separated)',
                  attributesController,
                  _onAttributesChanged,
                ),
                SizedBox(height: 12),
                _buildTagPreview(),
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

  String? _previewImageUrl() {
    if (useOriginalImage || segmentedUrl == null) {
      return originalImageUrl ?? segmentedUrl;
    }
    return segmentedUrl;
  }

  Widget _buildProcessedPreview({double height = 300}) {
    final previewUrl = _previewImageUrl();

    if (previewUrl != null && previewUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          previewUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPreviewFallback(height),
        ),
      );
    }

    return _buildPreviewFallback(height);
  }

  Widget _buildPreviewFallback(double height) {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          selectedImage!,
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      );
    }

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: UploadTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UploadTokens.line),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: UploadTokens.mutedSoft,
      ),
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

  Widget _buildMetadataSummary() {
    final chips = <Widget>[
      if (detectedTemp.trim().isNotEmpty)
        _summaryChip(
          icon: Icons.thermostat_rounded,
          label: 'Temp',
          value: _humanize(detectedTemp),
        ),
      if (detectedWeather.trim().isNotEmpty)
        _summaryChip(
          icon: Icons.wb_cloudy_rounded,
          label: 'Weather',
          value: _humanize(detectedWeather),
        ),
      if (attributes.isNotEmpty)
        _summaryChip(
          icon: Icons.sell_outlined,
          label: 'Tags',
          value: '${attributes.length} detected',
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UploadTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UploadTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected metadata',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: UploadTokens.ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Review and correct before saving. Accurate data improves AI performance.',
            style: TextStyle(fontSize: 12, color: UploadTokens.muted),
          ),
          if (chips.isNotEmpty) ...[
            SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: UploadTokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: UploadTokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: UploadTokens.muted),
          SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: UploadTokens.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPreview() {
    if (attributes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: UploadTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UploadTokens.line),
        ),
        child: Text(
          'No tags detected yet. Add comma separated tags above.',
          style: TextStyle(fontSize: 12, color: UploadTokens.muted),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attributes
          .asMap()
          .entries
          .map(
            (entry) => Chip(
              label: Text(_humanize(entry.value)),
              onDeleted: () => _removeTag(entry.key),
              side: BorderSide(color: UploadTokens.line),
              backgroundColor: UploadTokens.surface,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UploadTokens.ink,
              ),
              deleteIconColor: UploadTokens.muted,
              visualDensity: VisualDensity.compact,
            ),
          )
          .toList(),
    );
  }

  void _removeTag(int index) {
    if (index < 0 || index >= attributes.length) return;
    setState(() {
      final next = List<String>.from(attributes)..removeAt(index);
      attributes = next;
      attributesController.text = next.join(', ');
      attributesController.selection = TextSelection.collapsed(
        offset: attributesController.text.length,
      );
    });
  }

  void _onAttributesChanged(String value) {
    setState(() {
      attributes = _normalizeTags(_splitAttributes(value));
    });
  }

  String _safeText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  List<String> _extractTags(Map<String, dynamic> result) {
    final raw = result['attributes'] ?? result['tags'];
    if (raw is List) {
      return _normalizeTags(raw.map((entry) => _safeText(entry)).toList());
    }
    if (raw is String) {
      return _normalizeTags(_splitAttributes(raw));
    }
    return const [];
  }

  List<String> _normalizeTags(List<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final clean = _safeText(value);
      if (clean.isEmpty) continue;
      final key = clean.toLowerCase();
      if (seen.add(key)) {
        normalized.add(clean);
      }
    }
    return normalized;
  }

  String _humanize(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (normalized.isEmpty) return '';
    return normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
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
