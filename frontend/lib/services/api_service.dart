import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(response.body);
      return {'status': response.statusCode, ...data};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String phone,
      String password, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': password,
          'role': role,
        }),
      );
      final data = jsonDecode(response.body);
      return {'status': response.statusCode, ...data};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      return {'status': response.statusCode, ...data};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      return {'status': response.statusCode, ...data};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }
}
