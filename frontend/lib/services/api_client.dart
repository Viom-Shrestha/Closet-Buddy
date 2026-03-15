import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const host = 'http://127.0.0.1:8000';
  static const baseUrl = '$host/api';

  Future<String?> _accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('access_token', access);
    prefs.setString('refresh_token', refresh);
  }

  Future<bool> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    if (refresh == null) return false;

    final res = await http.post(
      Uri.parse('$baseUrl/auth/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (res.statusCode == 200) {
      prefs.setString('access_token', jsonDecode(res.body)['access']);
      return true;
    }
    return false;
  }

  Future<http.Response> get(String path) async {
    var token = await _accessToken();

    var res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 401 && await refresh()) {
      token = await _accessToken();
      return http.get(
        Uri.parse('$baseUrl$path'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }

    return res;
  }

  Future<http.Response> post(String path, Map body) async {
    var token = await _accessToken();

    var res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 401 && await refresh()) {
      token = await _accessToken();
      return http.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }

    return res;
  }

  Future<http.Response> put(String path, Map body) async {
    var token = await _accessToken();

    var res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 401 && await refresh()) {
      token = await _accessToken();
      return http.put(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }

    return res;
  }

  Future<http.Response> delete(String path) async {
    var token = await _accessToken();

    var res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 401 && await refresh()) {
      token = await _accessToken();
      return http.delete(
        Uri.parse('$baseUrl$path'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }

    return res;
  }

  Future<String?> token() => _accessToken();
}
