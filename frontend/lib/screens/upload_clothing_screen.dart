import 'dart:io';
import '../widgets/hover_clickable.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/clothing_service.dart';

enum UploadStep { selectImage, reviewing, editing }

class UploadClothingScreen extends StatefulWidget {
  final int storageId;

  const UploadClothingScreen({Key? key, required this.storageId})
    : super(key: key);

  @override
  State<UploadClothingScreen> createState() => _UploadClothingScreenState();
}

class _UploadClothingScreenState extends State<UploadClothingScreen> {
  final ClothingService clothingService = ClothingService();
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

  late TextEditingController categoryController;
  late TextEditingController subcategoryController;
  late TextEditingController dominantColorController;
  late TextEditingController secondaryColorController;
  late TextEditingController occasionController;

  @override
  void initState() {
    super.initState();

    categoryController = TextEditingController();
    subcategoryController = TextEditingController();
    dominantColorController = TextEditingController();
    secondaryColorController = TextEditingController();
    occasionController = TextEditingController();
  }

  @override
  void dispose() {
    categoryController.dispose();
    subcategoryController.dispose();
    dominantColorController.dispose();
    secondaryColorController.dispose();
    occasionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);

    if (picked == null) return;

    setState(() {
      selectedImage = File(picked.path);
      isLoading = true;
    });

    await _processImage();
  }

  Future<void> _processImage() async {
    if (!mounted) return;

    try {
      final result = await clothingService.process(selectedImage!);

      if (result == null) throw "Processing failed";

      setState(() {
        segmentedUrl = result['segmented_image'];

        category = result['category'];
        subcategory = result['subcategory'];
        dominantColor = result['dominant_color'];
        secondaryColor = result['secondary_color'];
        occasion = result['occasion'];

        // ✅ update controllers AFTER values exist
        categoryController.text = category;
        subcategoryController.text = subcategory;
        dominantColorController.text = dominantColor;
        secondaryColorController.text = secondaryColor;
        occasionController.text = occasion;

        isLoading = false;
        currentStep = UploadStep.reviewing;
      });
    } catch (e) {
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
            backgroundColor: Colors.red,
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
    };

    final success = await clothingService.save(payload);

    setState(() => isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clothing saved successfully"),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));

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

      categoryController.clear();
      subcategoryController.clear();
      dominantColorController.clear();
      secondaryColorController.clear();
      occasionController.clear();

      currentStep = UploadStep.selectImage;
    });
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
          'Upload Clothing',
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
      body: Stack(
        children: [
          _buildCurrentStep(),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _getLoadingMessage(),
                      style: TextStyle(
                        color: Colors.white,
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
            'Upload your clothing',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Take a photo or choose from your gallery',
            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
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
              color: Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For best results, use a clear photo with good lighting and plain background',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE5E7EB)),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Color(0xFF1A1A1A), size: 28),
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
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF9CA3AF)),
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
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI has isolated the clothing item',
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
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
                        color: Color(0xFFF3F4F6),
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFF9CA3AF),
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
                      backgroundColor: Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
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
                      foregroundColor: Color(0xFF1A1A1A),
                      side: BorderSide(color: Color(0xFFE5E7EB)),
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
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI has extracted these details. You can edit them.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
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
              ],
            ),
          ),
        ),
        Container(
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
                onPressed: isLoading ? null : _saveClothing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF10B981),
                  foregroundColor: Colors.white,
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
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  String _getLoadingMessage() {
    return 'Processing clothing...';
  }
}
