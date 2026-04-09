import 'dart:convert';

import 'api_client.dart';

class RecommendationService {
  RecommendationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

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

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        if (res.statusCode == 422) {
          final missing = decoded['missing_slots'];
          final slots = missing is List && missing.isNotEmpty
              ? missing.join(', ')
              : null;
          throw slots != null
              ? 'Your wardrobe is missing required items: $slots. Add at least one of each to generate an outfit.'
              : (decoded['error']?.toString() ??
                  'Your wardrobe does not have enough items to generate an outfit.');
        }
        if (decoded['error'] != null) throw decoded['error'].toString();
      }
    } catch (e) {
      rethrow;
    }
    throw 'Failed to generate recommendations (status ${res.statusCode}).';
  }
}
