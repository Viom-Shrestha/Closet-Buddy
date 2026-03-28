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
}
