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
}
