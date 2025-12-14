import 'dart:io';
import 'dart:convert';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String host = 'http://127.0.0.1:8000';
  static const String baseUrl = 'http://127.0.0.1:8000/api/auth';

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

  // In ApiService.dart

  Future<String?> segmentImage(File image) async {
    // 1. Get token and check for null
    String? accessToken = await getAccessToken();
    if (accessToken == null) return null;

    // Helper function to send the multipart request
    Future<http.StreamedResponse> _sendRequest(String token) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/segment/'),
      );

      // Set Authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add the file
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      return request.send();
    }

    // --- Attempt 1: Send request with current token ---
    http.StreamedResponse response = await _sendRequest(accessToken);

    // --- Token Refresh Logic (Handling 401) ---
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (!refreshed) {
        await logout();
        return null;
      }

      // Get the newly refreshed token and resend
      accessToken = await getAccessToken();
      if (accessToken == null) return null;

      response = await _sendRequest(accessToken);
    }

    // --- Process Final Response ---
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(body);
      final String relativeUrl =
          data['segmented_image']; // e.g., /media/segmented/image.png

      // 2. FIX: Prepend the full host to the relative URL
      final String fullUrl =
          '$host$relativeUrl'; // e.g., http://127.0.0.1:8000/media/segmented/image.png

      return fullUrl; // <-- Return the absolute URL
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
}
