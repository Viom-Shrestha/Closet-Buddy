import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ClothingService {
  ClothingService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<Map<String, dynamic>?> process(File image, {bool isShoe = false}) async {
    final token = await client.token();

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}/clothing/process/'),
    );

    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('image', image.path));
    req.fields['is_shoe'] = isShoe.toString();

    final res = await req.send();
    final body = await res.stream.bytesToString();

    final decoded = jsonDecode(body);

    // Success
    if (res.statusCode == 200) {
      return decoded;
    }

    // Not clothing
    if (res.statusCode == 400 && decoded['error'] == "Not a clothing item") {
      throw {"type": "not_clothing", "confidence": decoded["confidence"]};
    }

    final errorText = decoded is Map ? (decoded['error'] ?? '').toString() : '';
    if (errorText.toLowerCase().contains('segmentation failed') ||
        errorText.toLowerCase().contains('segmented file missing')) {
      throw {
        "type": "segmentation_failed",
        "message": errorText,
        "original_image": decoded is Map ? decoded['original_image'] : null,
      };
    }

    // Other backend errors
    throw decoded is Map ? (decoded['error'] ?? "Processing failed") : "Processing failed";
  }

  Future<bool> save(Map<String, dynamic> data) async {
    final res = await client.post('/clothing/save/', data);
    return res.statusCode == 201;
  }

  Future<bool> deleteSegmented(String url) async {
    final res = await client.post('/clothing/segmented/delete/', {'url': url});
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getRecentClothes() async {
    final res = await client.get('/clothing/recent/');
    return res.statusCode == 200
        ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
        : [];
  }

  Future<List<Map<String, dynamic>>> getAllClothes() async {
    final res = await client.get('/clothing/all/');
    return res.statusCode == 200
        ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
        : [];
  }

  Future<bool> toggleFavourite(int id) async {
    final res = await client.post('/clothing/$id/toggle-favourite/', {});

    return res.statusCode == 200;
  }

  Future<bool> deleteClothing(int id) async {
    final res = await client.delete('/clothing/$id/delete/');
    return res.statusCode == 204;
  }

  Future<bool> updateClothing(int id, Map data) async {
    final res = await client.put('/clothing/$id/update/', data);
    return res.statusCode == 200;
  }

  Future<bool> moveToStorage(int id, int storageId) async {
    final res = await client.put('/clothing/$id/update/', {
      'storage_unit': storageId,
    });
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final res = await client.get('/clothing/$id/');

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    return null;
  }
}
