import 'package:flutter/material.dart';

import '../widgets/editable_outfit_canvas.dart';

class OutfitPreviewScreen extends StatefulWidget {
  final List<EditableCanvasItem> items;
  final Map<String, EditableCanvasTransform> initialTransforms;

  const OutfitPreviewScreen({
    super.key,
    required this.items,
    this.initialTransforms = const {},
  });

  @override
  State<OutfitPreviewScreen> createState() => _OutfitPreviewScreenState();
}

class _OutfitPreviewScreenState extends State<OutfitPreviewScreen> {
  Map<String, EditableCanvasTransform> _latest = {};

  @override
  void initState() {
    super.initState();
    _latest = Map<String, EditableCanvasTransform>.from(widget.initialTransforms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text('Preview Canvas'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F0F0F),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E3DB)),
                ),
                child: const Text(
                  'Pinch to resize, drag to move each item. This preview is independent from outfit generation.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: EditableOutfitCanvas(
                  items: widget.items,
                  initialTransforms: widget.initialTransforms,
                  showGuide: true,
                  onChanged: (value) => _latest = value,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _latest),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0F0F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
