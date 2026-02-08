import 'dart:convert';
import 'api_client.dart';

class StorageService {
  final ApiClient client = ApiClient();

  Future<List<Map<String, dynamic>>> getAll() async {
    final res = await client.get('/storage/');
    return res.statusCode == 200
        ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
        : [];
  }
}
