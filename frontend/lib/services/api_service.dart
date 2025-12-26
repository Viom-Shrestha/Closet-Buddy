import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ---------------- BASE URLS ----------------
  static const String host = 'http://127.0.0.1:8000';
  static const String baseUrl = '$host/api/auth';

  // ---------------- AUTH ----------------
  Future<bool> register(
    String username,
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );
    return response.statusCode == 201;
  }

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access'], data['refresh']);
      return true;
    }
    return false;
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<bool> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access']);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    String? token = await getAccessToken();
    if (token == null) return null;

    var response = await http.get(
      Uri.parse('$baseUrl/profile/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (!refreshed) return null;

      token = await getAccessToken();
      response = await http.get(
        Uri.parse('$baseUrl/profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchAdminData() async {
    final token = await getAccessToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/admin-dashboard/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // 1. Create a helper for Authenticated GETs
  Future<http.Response> _getWithRefresh(String url) async {
    String? token = await getAccessToken();
    var response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      if (await refreshToken()) {
        token = await getAccessToken();
        return await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    }
    return response;
  }

  // 2. Create a helper for Authenticated POSTs
  Future<http.Response> _postWithRefresh(
    String url,
    Map<String, dynamic> body,
  ) async {
    String? token = await getAccessToken();
    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      if (await refreshToken()) {
        token = await getAccessToken();
        return await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      }
    }
    return response;
  }

  // ---------------- STORAGE ----------------
  Future<List<Map<String, dynamic>>> getStorages() async {
    final response = await _getWithRefresh('$baseUrl/storage/');

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      print("Failed to load storages: ${response.statusCode} ${response.body}");
      return [];
    }
  }

  // ---------------- SEGMENTATION ----------------
  Future<String?> segmentImage(File image) async {
    String? accessToken = await getAccessToken();
    if (accessToken == null) return null;

    Future<http.StreamedResponse> _sendRequest(String token) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/segment/'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      return request.send();
    }

    http.StreamedResponse response = await _sendRequest(accessToken);

    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (!refreshed) {
        await logout();
        return null;
      }
      accessToken = await getAccessToken();
      if (accessToken == null) return null;
      response = await _sendRequest(accessToken);
    }

    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(body);
      final String relativeUrl = data['segmented_image'];
      return '$host$relativeUrl';
    } else {
      print(
        'Segmentation API failed. Status: ${response.statusCode}, Body: $body',
      );
      return null;
    }
  }

  Future<bool> deleteSegmentedImage(String segmentedUrl) async {
    final token = await getAccessToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete-segmented/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'url': segmentedUrl}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting segmented image: $e');
      return false;
    }
  }

  // ---------------- CLIP AUTH ----------------
  Future<bool> checkIfClothing(File image) async {
    final token = await getAccessToken();
    if (token == null) return false;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai/authenticate-clothing/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(body)['is_clothing'] == true;
    }

    return false;
  }

  // ---------------- METADATA EXTRACTION ----------------
  Future<Map<String, dynamic>> extractMetadata(String segmentedUrl) async {
    // Use the helper you wrote to handle 401 errors automatically
    final response = await _postWithRefresh('$baseUrl/ai/extract-metadata/', {
      'segmented_image': segmentedUrl,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print(
        'Failed to extract metadata: ${response.statusCode} ${response.body}',
      );
      return {};
    }
  }

  // ---------------- SAVE CLOTHING ----------------
  Future<bool> saveClothing(Map<String, dynamic> data) async {
    final token = await getAccessToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/clothing/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 201;
  }

  // ---------------- SAVE NON-CLOTHING ----------------
  Future<bool> saveNonClothing(Map<String, dynamic> data) async {
    final token = await getAccessToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/non-clothing/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 201;
  }
}
