import 'dart:convert';

import 'api_client.dart';

class AdminService {
  AdminService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>?> fetchDashboard() async {
    final res = await _client.get('/admin/dashboard/');
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchUsers({
    String query = '',
    int limit = 100,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final res = await _client.get('/admin/users/?q=$encodedQuery&limit=$limit');
    if (res.statusCode != 200) return const [];

    final decoded = jsonDecode(res.body);
    final results = (decoded['results'] as List?) ?? const [];
    return results
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<bool> setUserActive(int userId, bool isActive) async {
    final res = await _client.post('/admin/users/$userId/active/', {
      'is_active': isActive,
    });
    return res.statusCode == 200;
  }

  Future<bool> setUserStaff(int userId, bool isStaff) async {
    final res = await _client.post('/admin/users/$userId/staff/', {
      'is_staff': isStaff,
    });
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> fetchUserSummary(int userId) async {
    final res = await _client.get('/admin/users/$userId/');
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserClothing({
    required int userId,
    int limit = 40,
    int offset = 0,
  }) async {
    final res = await _client.get(
      '/admin/users/$userId/clothing/?limit=$limit&offset=$offset',
    );
    if (res.statusCode != 200) {
      return {'results': [], 'total': 0, 'limit': limit, 'offset': offset};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserOutfits({
    required int userId,
    int limit = 40,
    int offset = 0,
  }) async {
    final res = await _client.get(
      '/admin/users/$userId/outfits/?limit=$limit&offset=$offset',
    );
    if (res.statusCode != 200) {
      return {'results': [], 'total': 0, 'limit': limit, 'offset': offset};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> sendPasswordReset(int userId) async {
    final res = await _client.post('/admin/users/$userId/password-reset/', {});
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> fetchCatalog({
    String query = '',
    String category = '',
    String subcategory = '',
    String dominantColor = '',
    String userId = '',
    int limit = 40,
    int offset = 0,
  }) async {
    final q = Uri.encodeQueryComponent(query);
    final c = Uri.encodeQueryComponent(category);
    final sc = Uri.encodeQueryComponent(subcategory);
    final color = Uri.encodeQueryComponent(dominantColor);
    final uid = Uri.encodeQueryComponent(userId);
    final res = await _client.get(
      '/admin/clothing/?q=$q&category=$c&subcategory=$sc&dominant_color=$color&user_id=$uid&limit=$limit&offset=$offset',
    );
    if (res.statusCode != 200) {
      return {'results': [], 'total': 0, 'limit': limit, 'offset': offset};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> deleteClothing(int itemId) async {
    final res = await _client.delete('/admin/clothing/$itemId/');
    return res.statusCode == 204;
  }

  Future<bool> deleteOutfit(int outfitId) async {
    final res = await _client.delete('/admin/outfits/$outfitId/');
    return res.statusCode == 204;
  }

  Future<int> bulkReclassify(List<int> ids, String category, String subcategory) async {
    final res = await _client.post('/admin/clothing/reclassify/', {
      'ids': ids,
      'category': category,
      'subcategory': subcategory,
    });
    if (res.statusCode != 200) return 0;
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['updated'] as int?) ?? 0;
  }

  Future<Map<String, dynamic>> fetchOutfits({
    String userId = '',
    String occasion = '',
    String rating = '',
    String favourite = '',
    int limit = 40,
    int offset = 0,
  }) async {
    final uid = Uri.encodeQueryComponent(userId);
    final occ = Uri.encodeQueryComponent(occasion);
    final rate = Uri.encodeQueryComponent(rating);
    final fav = Uri.encodeQueryComponent(favourite);
    final res = await _client.get(
      '/admin/outfits/?user_id=$uid&occasion=$occ&rating=$rate&is_favourite=$fav&limit=$limit&offset=$offset',
    );
    if (res.statusCode != 200) {
      return {'results': [], 'total': 0, 'limit': limit, 'offset': offset};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchFeedback({int limit = 50, int offset = 0}) async {
    final res = await _client.get('/admin/feedback/?limit=$limit&offset=$offset');
    if (res.statusCode != 200) {
      return {'results': [], 'total': 0, 'limit': limit, 'offset': offset};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> markFeedbackRead(int feedbackId, bool isRead) async {
    final res = await _client.post('/admin/feedback/$feedbackId/read/', {
      'is_read': isRead,
    });
    return res.statusCode == 200;
  }
}
