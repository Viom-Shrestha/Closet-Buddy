import 'dart:convert';

import 'api_client.dart';

class RecommendationService {
  RecommendationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> recommend({
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
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
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
