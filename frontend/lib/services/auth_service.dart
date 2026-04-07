import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  AuthService({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String confirmPassword,
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
        'confirm_password': confirmPassword,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );

    if (res.statusCode == 201) {
      return {'success': true, 'errors': <String, String>{}};
    }

    dynamic decoded;
    try {
      decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      decoded = null;
    }

    String flattenError(dynamic value) {
      if (value == null) return '';
      if (value is String) return value.trim();
      if (value is List) {
        return value
            .map(flattenError)
            .where((part) => part.isNotEmpty)
            .join(' ')
            .trim();
      }
      if (value is Map) {
        return value.values
            .map(flattenError)
            .where((part) => part.isNotEmpty)
            .join(' ')
            .trim();
      }
      return value.toString().trim();
    }

    final errors = <String, String>{};
    if (decoded is Map) {
      decoded.forEach((key, value) {
        final text = flattenError(value);
        if (text.isNotEmpty) {
          errors[key.toString()] = text;
        }
      });
    } else {
      final text = flattenError(decoded);
      if (text.isNotEmpty) {
        errors['non_field_errors'] = text;
      }
    }

    if (errors.isEmpty) {
      errors['non_field_errors'] = 'Registration failed. Please try again.';
    }

    return {'success': false, 'errors': errors};
  }

  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'remember_me': rememberMe,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await client.saveTokens(data['access'], data['refresh']);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final refresh = await client.refreshToken();
    try {
      if (refresh != null && refresh.trim().isNotEmpty) {
        await client.post('/auth/logout/', {'refresh': refresh.trim()});
      }
    } catch (_) {
      // Even if server-side logout fails, clear local session to log user out.
    } finally {
      await client.clearTokens();
    }
  }
}
