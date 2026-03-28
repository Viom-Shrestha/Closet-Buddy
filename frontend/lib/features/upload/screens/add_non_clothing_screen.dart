import 'package:flutter/material.dart';
import 'package:frontend/core/core.dart';
import 'package:frontend/services/misc_service.dart';
import 'package:frontend/theme/app_theme.dart';

class AddNonClothingScreen extends StatefulWidget {
  final int storageId;

  const AddNonClothingScreen({super.key, required this.storageId});

  @override
  State<AddNonClothingScreen> createState() => _AddNonClothingScreenState();
}

class _AddNonClothingScreenState extends State<AddNonClothingScreen> {
  final MiscService miscService = ServiceRegistry.instance.miscService;
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      final itemData = {
        'storage_id': widget.storageId,
        'name': _itemNameController.text,
        'description': _descriptionController.text,
      };

      try {
        final success = await miscService.saveNonClothing(itemData);
        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item added successfully!'),
              backgroundColor: UploadTokens.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 900),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save item'),
              backgroundColor: UploadTokens.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: UploadTokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          'Add Non-Clothing Item',
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
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: UploadTokens.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add accessories and miscellaneous items',
                          style: TextStyle(
                            fontSize: 15,
                            color: UploadTokens.muted,
                          ),
                        ),
                        SizedBox(height: 32),
                        _buildTextField(
                          label: 'Item Name',
                          controller: _itemNameController,
                          hint: 'e.g., Watch, Sunglasses, Belt',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an item name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        _buildTextArea(
                          label: 'Description (Optional)',
                          controller: _descriptionController,
                          hint: 'Add any additional details about the item',
                        ),
                        SizedBox(height: 24),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: UploadTokens.success.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: UploadTokens.success.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: UploadTokens.success,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Non-clothing items don\'t require AI analysis',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: UploadTokens.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: UploadTokens.surface,
                  border: Border(
                    top: BorderSide(color: UploadTokens.line),
                  ),
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
                      onPressed: isLoading ? null : _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UploadTokens.ink,
                        foregroundColor: UploadTokens.surface,
                        disabledBackgroundColor: UploadTokens.ink
                            .withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Item',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: UploadTokens.black.withValues(alpha: 0.54),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(UploadTokens.surface),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
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
        TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(fontSize: 15, color: UploadTokens.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: UploadTokens.mutedSoft),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: UploadTokens.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: UploadTokens.danger, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
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
          maxLines: 4,
          style: TextStyle(fontSize: 15, color: UploadTokens.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: UploadTokens.mutedSoft),
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
            contentPadding: EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
