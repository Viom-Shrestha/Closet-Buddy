import 'dart:convert';

import 'api_client.dart';

class AdminService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>?> fetchDashboard() async {
    final res = await _client.get('/admin-dashboard/');
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

  Future<List<Map<String, dynamic>>> fetchActivity({int limit = 60}) async {
    final res = await _client.get('/admin/activity/?limit=$limit');
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
}

