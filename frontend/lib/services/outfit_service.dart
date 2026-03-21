import 'dart:convert';
import 'api_client.dart';

class OutfitService {
  final ApiClient client = ApiClient();

  Future<List<Map<String, dynamic>>> getAll() async {
    final res = await client.get('/outfits/');
    return res.statusCode == 200
        ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
        : [];
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final res = await client.get('/outfits/$id/');
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>?> create(Map<String, dynamic> data) async {
    final res = await client.post('/outfits/', data);
    if (res.statusCode != 201) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>?> update(int id, Map<String, dynamic> data) async {
    final res = await client.put('/outfits/$id/', data);
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>?> updatePartial(int id, Map<String, dynamic> data) async {
    final res = await client.patch('/outfits/$id/', data);
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<bool> delete(int id) async {
    final res = await client.delete('/outfits/$id/');
    return res.statusCode == 204;
  }

  Future<Map<String, dynamic>?> toggleFavourite(int id) async {
    final res = await client.post('/outfits/$id/toggle-favourite/', {});
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>?> markWorn(int id) async {
    final res = await client.post('/outfits/$id/wear/', {});
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }
}
