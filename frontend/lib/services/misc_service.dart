import 'dart:convert';

import 'api_client.dart';

class MiscService {
  MiscService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<bool> saveNonClothing(Map<String, dynamic> data) async {
    final res = await client.post('/non-clothing/', data);
    return res.statusCode == 201;
  }

  Future<bool> updateNonClothing(int id, Map<String, dynamic> data) async {
    final res = await client.put('/non-clothing/$id/', data);
    return res.statusCode == 200;
  }

  Future<bool> deleteNonClothing(int id) async {
    final res = await client.delete('/non-clothing/$id/');
    return res.statusCode == 204;
  }

  Future<Map<String, dynamic>> fetchNonClothingItems({
    String query = '',
    String userId = '',
    int limit = 40,
    int offset = 0,
  }) async {
    final q = Uri.encodeQueryComponent(query);
    final uid = Uri.encodeQueryComponent(userId);
    final res = await client.get(
      '/admin/non-clothing/?q=$q&user_id=$uid&limit=$limit&offset=$offset',
    );
    if (res.statusCode != 200) {
      return {'results': [], 'total': 0, 'limit': limit, 'offset': offset};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
