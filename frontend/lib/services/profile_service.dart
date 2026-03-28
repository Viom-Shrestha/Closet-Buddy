import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ProfileService {
  ProfileService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<Map<String, dynamic>?> fetchProfile() async {
    final res = await client.get('/profile/');
    return res.statusCode == 200 ? jsonDecode(res.body) : null;
  }

  Future<bool> updateProfile(Map<String, String> data) async {
    final res = await client.put('/profile/', data);
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> uploadAvatar(File image) async {
    final token = await client.token();
    final req = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiClient.baseUrl}/profile/'),
    );
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('avatar', image.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) {
      return jsonDecode(body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchAdminDashboard() async {
    final res = await client.get('/admin/dashboard/');
    return res.statusCode == 200 ? jsonDecode(res.body) : null;
  }
}
