import 'dart:convert';

import 'api_client.dart';

class RecommendationService {
  RecommendationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  Map<String, dynamic>? _occasionCatalogCache;

  Future<void> primeOccasionCatalog() async {
    await fetchOccasionCatalog();
  }

  Future<Map<String, dynamic>> fetchOccasionCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _occasionCatalogCache != null) {
      return _occasionCatalogCache!;
    }

    final res = await _client.get('/occasions/');
    if (res.statusCode != 200) {
      return _occasionCatalogCache ?? const {
        'canonical_occasions': <String>[],
        'attribute_signals': <String>[],
        'sort_order': <String>[],
      };
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return _occasionCatalogCache ?? const {
        'canonical_occasions': <String>[],
        'attribute_signals': <String>[],
        'sort_order': <String>[],
      };
    }

    List<String> stringList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final catalog = <String, dynamic>{
      'canonical_occasions': stringList(decoded['canonical_occasions']),
      'attribute_signals': stringList(decoded['attribute_signals']),
      'sort_order': stringList(decoded['sort_order']),
    };

    _occasionCatalogCache = catalog;
    return catalog;
  }

  Future<Map<String, dynamic>> recommend({
    required String temperature,
    required String weather,
    String? occasion,
    String? prompt,
  }) async {
    final Map<String, dynamic> payload = {
      'weather': {'temperature': temperature, 'weather': weather},
    };

    final trimmedOccasion = (occasion ?? '').trim();
    if (trimmedOccasion.isNotEmpty) {
      payload['occasion'] = trimmedOccasion;
    }

    final trimmedPrompt = (prompt ?? '').trim();
    if (trimmedPrompt.isNotEmpty) {
      payload['prompt'] = trimmedPrompt;
    }

    final res = await _client.post('/recommendations/', payload);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return {
          'outfits': List<Map<String, dynamic>>.from(decoded),
          'fallback_used': false,
          'metadata': {'temperature': temperature, 'weather': weather},
        };
      }
      if (decoded is Map) {
        final outfitsRaw = decoded['outfits'] ?? decoded['results'] ?? [];
        final outfits = outfitsRaw is List
            ? List<Map<String, dynamic>>.from(outfitsRaw)
            : <Map<String, dynamic>>[];
        final metadataRaw = decoded['metadata'];
        final metadata = metadataRaw is Map<String, dynamic>
            ? metadataRaw
            : metadataRaw is Map
            ? Map<String, dynamic>.from(metadataRaw)
            : <String, dynamic>{'temperature': temperature, 'weather': weather};
        return {
          'outfits': outfits,
          'fallback_used': decoded['fallback_used'] == true,
          'occasion_fallback_used': decoded['occasion_fallback_used'] == true,
          'warning': decoded['warning']?.toString(),
          'metadata': metadata,
        };
      }
      throw 'Unexpected recommendation response shape.';
    }

    String message = 'Failed to generate recommendations';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {}
    throw message;
  }
}
