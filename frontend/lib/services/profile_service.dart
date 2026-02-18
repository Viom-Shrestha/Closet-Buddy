import 'dart:convert';
import 'api_client.dart';

class ProfileService {
  final ApiClient client = ApiClient();

  Future<Map<String, dynamic>?> fetchProfile() async {
    final res = await client.get('/profile/');
    return res.statusCode == 200 ? jsonDecode(res.body) : null;
  }

  Future<bool> updateProfile(Map<String, String> data) async {
    final res = await client.put('/profile/update/', data);
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> fetchAdminDashboard() async {
    final res = await client.get('/admin-dashboard/');
    return res.statusCode == 200 ? jsonDecode(res.body) : null;
  }
}
