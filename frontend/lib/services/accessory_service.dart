import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class AccessoryService {
  AccessoryService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<Map<String, dynamic>?> process(File image) async {
    final token = await client.token();

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}/accessories/process/'),
    );

    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('image', image.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    final decoded = jsonDecode(body);

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(decoded);
    }
    throw decoded['error'] ?? 'Accessory processing failed';
  }

  Future<bool> save(Map<String, dynamic> data) async {
    final res = await client.post('/accessories/save/', data);
    return res.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final res = await client.get('/accessories/all/');
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final res = await client.get('/accessories/$id/');
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    final res = await client.put('/accessories/$id/', data);
    return res.statusCode == 200;
  }

  Future<bool> delete(int id) async {
    final res = await client.delete('/accessories/$id/');
    return res.statusCode == 204;
  }

  Future<bool> toggleFavourite(int id) async {
    final res = await client.post('/accessories/$id/toggle-favourite/', {});
    return res.statusCode == 200;
  }
}
