import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ClothingService {
  final ApiClient client = ApiClient();

  Future<Map<String, dynamic>?> process(File image) async {
    final token = await client.token();

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}/clothing/process/'),
    );

    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('image', image.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    final decoded = jsonDecode(body);

    // ✅ Success
    if (res.statusCode == 200) {
      return decoded;
    }

    // ❌ Not clothing
    if (res.statusCode == 400 && decoded['error'] == "Not a clothing item") {
      throw "Not a clothing item";
    }

    // ❌ Other backend errors
    throw decoded['error'] ?? "Processing failed";
  }

  Future<bool> save(Map<String, dynamic> data) async {
    final res = await client.post('/clothing/save/', data);
    return res.statusCode == 201;
  }

  Future<bool> deleteSegmented(String url) async {
    final res = await client.post('/delete-segmented/', {'url': url});
    return res.statusCode == 200;
  }
}
