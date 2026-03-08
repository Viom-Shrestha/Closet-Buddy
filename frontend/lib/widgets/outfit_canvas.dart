import 'package:flutter/material.dart';

import '../services/api_client.dart';

class OutfitCanvas extends StatelessWidget {
  final Map<String, dynamic>? topwear;
  final Map<String, dynamic>? bottomwear;
  final Map<String, dynamic>? shoes;
  final String silhouette;
  final double height;
  final bool compact;

  const OutfitCanvas({
    super.key,
    this.topwear,
    this.bottomwear,
    this.shoes,
    this.silhouette = 'male',
    this.height = 420,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final silhouetteAsset = silhouette.toLowerCase() == 'female'
        ? 'assets/images/Female_N.png'
        : 'assets/images/Male_N.png';

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 16),
              child: Opacity(
                opacity: compact ? 0.28 : 0.3,
                child: Image.asset(
                  silhouetteAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.accessibility_new_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 46,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          _slotLayer(
            item: topwear,
            topFraction: 0.08,
            heightFraction: 0.38,
            horizontalPaddingFraction: compact ? 0.2 : 0.18,
          ),
          _slotLayer(
            item: bottomwear,
            topFraction: 0.43,
            heightFraction: 0.35,
            horizontalPaddingFraction: compact ? 0.23 : 0.2,
          ),
          _slotLayer(
            item: shoes,
            topFraction: 0.78,
            heightFraction: 0.18,
            horizontalPaddingFraction: compact ? 0.28 : 0.26,
          ),
        ],
      ),
    );
  }

  Widget _slotLayer({
    required Map<String, dynamic>? item,
    required double topFraction,
    required double heightFraction,
    required double horizontalPaddingFraction,
  }) {
    final imageUrl = _resolveImage(item?['image']);
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    final alignmentY = ((topFraction + (heightFraction / 2)) * 2) - 1;
    final widthFactor = 1 - (horizontalPaddingFraction * 2);

    return Align(
      alignment: Alignment(0, alignmentY),
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: heightFraction,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveImage(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiClient.host}$url';
    return '${ApiClient.host}/$url';
  }
}
