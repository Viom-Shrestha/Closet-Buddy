import 'dart:convert';
import 'api_client.dart';

class StorageService {
  StorageService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<List<Map<String, dynamic>>> getAll() async {
    final res = await client.get('/storage/');
    return res.statusCode == 200
        ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
        : [];
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String type,
    int? parentStorage,
    String? description,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      if (parentStorage != null) 'parent_storage': parentStorage,
      if (description != null) 'description': description,
    };

    final res = await client.post('/storage/', payload);
    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to create storage: ${res.body}');
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String name,
    required String type,
    int? parentStorage,
    String? description,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      if (parentStorage != null) 'parent_storage': parentStorage,
      if (description != null) 'description': description,
    };

    final res = await client.put('/storage/$id/', payload);
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to update storage: ${res.body}');
  }

  Future<void> delete(int id) async {
    final res = await client.delete('/storage/$id/');
    if (res.statusCode != 204) {
      throw Exception('Failed to delete storage: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getDetail(int id) async {
    final res = await client.get('/storage/$id/view/');

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }

    throw Exception('Failed to load storage detail');
  }

  Future<void> togglePutAway(int id, bool value) async {
    final res = await client.put('/storage/$id/', {"is_put_away": value});

    if (res.statusCode != 200) {
      throw Exception("Failed to toggle put away");
    }
  }
}
