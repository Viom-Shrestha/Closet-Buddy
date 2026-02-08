import 'api_client.dart';

class MiscService {
  final ApiClient client = ApiClient();

  Future<bool> saveNonClothing(Map<String, dynamic> data) async {
    final res = await client.post('/non-clothing/', data);
    return res.statusCode == 201;
  }
}
