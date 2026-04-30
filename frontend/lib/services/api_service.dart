import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// URL de l’API Laravel. Sur émulateur Android, l’hôte de la machine est 10.0.2.2.
/// Sur un téléphone physique, remplacez par l’IP LAN de votre PC (ex. http://192.168.1.10:8000).
class ApiService {
  static String get _apiRoot {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static Map<String, dynamic> _parseBody(http.Response response) {
    final raw = response.body;
    if (raw.isEmpty) {
      return {'status': response.statusCode};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return {...decoded, 'status': response.statusCode};
      }
      if (decoded is Map) {
        return {
          ...Map<String, dynamic>.from(decoded),
          'status': response.statusCode,
        };
      }
      return {'status': response.statusCode, 'message': raw};
    } catch (_) {
      return {
        'status': response.statusCode,
        'message': raw.isNotEmpty ? raw : 'Réponse invalide du serveur',
      };
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
    String? fcmToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
        }),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String phone,
    String password,
    String role,
    String? fcmToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': password,
          'role': role,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
        }),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiRoot/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Map<String, String> _authHeaders(String token, {bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> updateLocation(
    String token,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/location'),
        headers: _authHeaders(token),
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> nearbyMechanics(
    String token,
    double latitude,
    double longitude, {
    double radiusKm = 30,
  }) async {
    try {
      final uri = Uri.parse('$_apiRoot/mechanics/nearby').replace(queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radius_km': '$radiusKm',
      });
      final response = await http.get(uri, headers: _authHeaders(token, json: false));
      return {'status': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> createRequest({
    required String token,
    required int mechanicId,
    required String vehicleType,
    required String description,
    required double clientLat,
    required double clientLng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/requests'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'mechanic_id': mechanicId,
          'vehicle_type': vehicleType,
          'description': description,
          'client_lat': clientLat,
          'client_lng': clientLng,
        }),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> listRequests(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiRoot/requests'),
        headers: _authHeaders(token, json: false),
      );
      return {'status': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> updateMechanicAvailability(
    String token,
    bool isAvailable,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiRoot/profile'),
        headers: _authHeaders(token),
        body: jsonEncode({'is_available': isAvailable}),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> acceptRequest(String token, int id) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/requests/$id/accept'),
        headers: _authHeaders(token),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> declineRequest(String token, int id) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/requests/$id/decline'),
        headers: _authHeaders(token),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> listMessages(String token, int requestId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiRoot/requests/$requestId/messages'),
        headers: _authHeaders(token, json: false),
      );
      return {'status': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
    String token,
    int requestId,
    String body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/requests/$requestId/messages'),
        headers: _authHeaders(token),
        body: jsonEncode({'body': body}),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> updatePushToken(
    String token,
    String? fcmToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiRoot/push/token'),
        headers: _authHeaders(token),
        body: jsonEncode({'fcm_token': fcmToken}),
      );
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }
}
