import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  AuthService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<bool> register(
    String username,
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );

    return res.statusCode == 201;
  }

  Future<bool> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await client.saveTokens(data['access'], data['refresh']);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await client.post('/auth/logout/', {});
  }
}
