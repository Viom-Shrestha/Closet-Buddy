import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

enum AddItemStep {
  chooseStorage,
  chooseType,
  upload,
  authenticating,
  segmentation,
  confirmSegmentation,
  extracting,
  editAndSave,
  nonClothingForm,
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final ApiService api = ApiService();
  final ImagePicker picker = ImagePicker();

  AddItemStep step = AddItemStep.chooseStorage;

  // Storage
  List<Map<String, dynamic>> storageList = [];
  int? selectedStorageId;

  // Image
  File? image;
  String? segmentedUrl;

  bool isClothing = true;
  bool isLoading = false;

  // Extracted data
  String dominantColor = '';
  String secondaryColor = '';
  String category = 'Topwear';
  String subcategory = 'Shirt';
  String occasion = 'Casual';

  // Non-clothing
  String itemName = '';
  String description = '';

  @override
  void initState() {
    super.initState();
    loadStorages();
  }

  // ---------------- STORAGE ----------------

  Future<void> loadStorages() async {
    final result = await api.getStorages();

    // Optional: sort so parents appear first
    result.sort((a, b) {
      int aParent = a['parent_storage']?['id'] ?? 0;
      int bParent = b['parent_storage']?['id'] ?? 0;
      return aParent.compareTo(bParent);
    });

    setState(() {
      storageList = result;
    });
  }

  // ---------------- IMAGE PICK ----------------

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      image = File(picked.path);
      step = AddItemStep.authenticating;
      setState(() {});
      authenticate();
    }
  }

  // ---------------- AUTH ----------------

  Future<void> authenticate() async {
    isLoading = true;
    setState(() {});

    final isValid = await api.checkIfClothing(image!);

    isLoading = false;

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This is not a clothing item")),
      );
      step = AddItemStep.upload;
    } else {
      step = AddItemStep.segmentation;
      segment();
    }
    setState(() {});
  }

  // ---------------- SEGMENT ----------------

  Future<void> segment() async {
    isLoading = true;
    setState(() {});

    segmentedUrl = await api.segmentImage(image!);

    isLoading = false;
    step = AddItemStep.confirmSegmentation;
    setState(() {});
  }

  // ---------------- EXTRACT ----------------

  // Inside _AddItemScreenState

  Future<void> extract() async {
    if (segmentedUrl == null) return;

    setState(() => isLoading = true);

    try {
      final result = await api.extractMetadata(segmentedUrl!);

      if (result.isNotEmpty) {
        setState(() {
          // Map the backend keys to your Flutter state variables
          dominantColor = result['dominant_color'] ?? 'Unknown';
          secondaryColor = result['secondary_color'] ?? 'Unknown';
          category = result['category'] ?? 'Topwear';
          subcategory = result['subcategory'] ?? 'Shirt';
          occasion =
              result['occassion'] ??
              'Casual'; // Note: check backend spelling "occassion" vs "occasion"

          isLoading = false;
          // Step 1: Move the state to 'editAndSave'
          step = AddItemStep.editAndSave;
        });

        // Step 2: Show the dialog after the state has updated
        showEditDialog();
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Extraction failed: $e")));
    }
  }

  // ---------------- SAVE ----------------

  Future<void> saveClothing() async {
    setState(() => isLoading = true);

    final Map<String, dynamic> itemData = {
      "storage_id": selectedStorageId,
      "image_url": segmentedUrl,
      "category": category,
      "subcategory": subcategory,
      "dominant_color": dominantColor,
      "secondary_color": secondaryColor,
      "occasion":
          occasion, // Make sure this spelling matches your Django model!
    };

    final success = await api.saveClothing(itemData);

    setState(() => isLoading = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Item added to closet!")));
      // Go back to the main screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save item. Check logs.")),
      );
    }
  }

  Future<void> saveNonClothing() async {
    await api.saveNonClothing({
      "storage_id": selectedStorageId,
      "name": itemName,
      "description": description,
    });

    Navigator.pop(context);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Item")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(child: buildContent()),
          ),
          if (isLoading)
            const ModalBarrier(dismissible: false, color: Colors.black45),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget buildContent() {
    switch (step) {
      case AddItemStep.chooseStorage:
        return buildStorageSelector();
      case AddItemStep.chooseType:
        return buildTypeChooser();
      case AddItemStep.upload:
        return buildUpload();
      case AddItemStep.confirmSegmentation:
        return buildSegmentationConfirm();
      case AddItemStep.nonClothingForm:
        return buildNonClothingForm();
      default:
        return const SizedBox();
    }
  }

  // ---------------- WIDGETS ----------------

  Widget buildStorageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Storage", style: TextStyle(fontSize: 18)),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          hint: const Text("Select Storage"),
          value: selectedStorageId,
          items: storageList.map((s) {
            String displayName = s['name'];
            if (s['parent_storage'] != null) {
              displayName = "${s['parent_storage']['name']} > $displayName";
            }
            return DropdownMenuItem<int>(
              value: s['id'] as int,
              child: Text(displayName),
            );
          }).toList(),
          onChanged: (v) => setState(() => selectedStorageId = v),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: selectedStorageId == null
              ? null
              : () => setState(() => step = AddItemStep.chooseType),
          child: const Text("Next"),
        ),
      ],
    );
  }

  Widget buildTypeChooser() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            isClothing = true;
            step = AddItemStep.upload;
            setState(() {});
          },
          child: const Text("Add Clothing"),
        ),
        OutlinedButton(
          onPressed: () {
            isClothing = false;
            step = AddItemStep.nonClothingForm;
            setState(() {});
          },
          child: const Text("Add Non-Clothing"),
        ),
      ],
    );
  }

  Widget buildUpload() {
    return Column(
      children: [
        ElevatedButton(onPressed: pickImage, child: const Text("Upload Image")),
        OutlinedButton(
          onPressed: () {},
          child: const Text("Take Picture (Coming Soon)"),
        ),
      ],
    );
  }

  Widget buildSegmentationConfirm() {
    return Column(
      children: [
        Image.network(segmentedUrl!, height: 250),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: extract,
          child: const Text("Segmentation Looks Good"),
        ),
        OutlinedButton(
          onPressed: () async {
            await api.deleteSegmentedImage(segmentedUrl!);
            setState(() {
              segmentedUrl = null;
              image = null;
              step = AddItemStep.upload;
            });
          },
          child: const Text("Redo"),
        ),
      ],
    );
  }

  Widget buildNonClothingForm() {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: "Item Name"),
          onChanged: (v) => itemName = v,
        ),
        TextField(
          decoration: const InputDecoration(labelText: "Description"),
          onChanged: (v) => description = v,
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: saveNonClothing, child: const Text("Save")),
      ],
    );
  }

  void showEditDialog() {
    // 1. Initialize controllers with the AI results
    final TextEditingController catCtrl = TextEditingController(text: category);
    final TextEditingController subCatCtrl = TextEditingController(
      text: subcategory,
    );
    final TextEditingController occasionCtrl = TextEditingController(
      text: occasion,
    );
    final TextEditingController domColorCtrl = TextEditingController(
      text: dominantColor,
    );
    final TextEditingController secColorCtrl = TextEditingController(
      text: secondaryColor,
    );

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental closing
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Final Review"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show the segmented image at the top
                if (segmentedUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      segmentedUrl!,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 15),

                // Metadata Fields
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    labelText: "Category (e.g. Topwear)",
                  ),
                ),
                TextField(
                  controller: subCatCtrl,
                  decoration: const InputDecoration(
                    labelText: "Subcategory (e.g. Shirt)",
                  ),
                ),
                TextField(
                  controller: domColorCtrl,
                  decoration: const InputDecoration(labelText: "Primary Color"),
                ),
                TextField(
                  controller: secColorCtrl,
                  decoration: const InputDecoration(
                    labelText: "Secondary Color",
                  ),
                ),
                TextField(
                  controller: occasionCtrl,
                  decoration: const InputDecoration(labelText: "Occasion"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                // 2. Update state with the user's manual edits
                setState(() {
                  category = catCtrl.text;
                  subcategory = subCatCtrl.text;
                  dominantColor = domColorCtrl.text;
                  secondaryColor = secColorCtrl.text;
                  occasion = occasionCtrl.text;
                });

                Navigator.pop(context); // Close the dialog
                saveClothing(); // Call the final save function
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Confirm & Save"),
            ),
          ],
        );
      },
    );
  }
}
