import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class SegmentationScreen extends StatefulWidget {
  const SegmentationScreen({super.key});

  @override
  State<SegmentationScreen> createState() => _SegmentationScreenState();
}

class _SegmentationScreenState extends State<SegmentationScreen> {
  File? image;
  String? segmentedUrl;
  bool _isLoading = false;
  final picker = ImagePicker();
  final api = ApiService();

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        image = File(picked.path);
        segmentedUrl = null;
      });
    }
  }

  Future<void> segment() async {
    if (image == null) return; // Safety check

    setState(() {
      _isLoading = true; // Start loading
      segmentedUrl = null; // Clear previous result
    });

    final result = await api.segmentImage(image!);
    if (!mounted) return;

    setState(() {
      _isLoading = false; // Stop loading
      if (result != null) {
        segmentedUrl = result;
      } else {
        // Show an error message if segmentation failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segmentation failed. Check logs/API.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segment Clothing')),
      body: Stack(
        // <-- Use Stack for overlaying the spinner
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Displaying the Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: (image == null)
                          ? const Text('No Image Selected')
                          : (segmentedUrl != null)
                          ? Image.network(segmentedUrl!, fit: BoxFit.contain)
                          : Image.file(image!, fit: BoxFit.contain),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Upload Button
                  ElevatedButton(
                    onPressed: pickImage,
                    child: const Text('Upload Image'),
                  ),

                  const SizedBox(height: 10),

                  // Segment Button (Hidden when loading)
                  if (image != null && !_isLoading && segmentedUrl == null)
                    ElevatedButton.icon(
                      onPressed: segment,
                      icon: const Icon(Icons.cut),
                      label: const Text('Run Segmentation'),
                    ),

                  // Confirm/Redo Buttons
                  if (segmentedUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // confirm (later store)
                              Navigator.pop(context);
                            },
                            child: const Text('Confirm'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              // <-- Make this function async
                              if (segmentedUrl != null) {
                                // STEP 1: Call API to delete the file on the server
                                await api.deleteSegmentedImage(segmentedUrl!);
                              }

                              // STEP 2: Clear the local UI state
                              setState(() {
                                image = null;
                                segmentedUrl = null;
                              });
                            },
                            child: const Text('Redo'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Overlay for Loading Indicator
          if (_isLoading)
            const ModalBarrier(dismissible: false, color: Colors.black45),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
