import 'package:flutter/material.dart';

import 'package:frontend/widgets/editable_outfit_canvas.dart';
import 'package:frontend/theme/app_theme.dart';

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
    _latest = Map<String, EditableCanvasTransform>.from(
      widget.initialTransforms,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WardrobeTokens.pageWarm,
      appBar: AppBar(
        title: const Text('Preview Canvas'),
        backgroundColor: WardrobeTokens.surface,
        foregroundColor: WardrobeTokens.inkDeep,
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
                  color: WardrobeTokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WardrobeTokens.borderWarm),
                ),
                child: const Text(
                  'Pinch to resize, drag to move each item. This preview is independent from outfit generation.',
                  style: TextStyle(fontSize: 12, color: WardrobeTokens.muted),
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
                    backgroundColor: WardrobeTokens.inkDeep,
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
