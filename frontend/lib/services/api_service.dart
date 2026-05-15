import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// URL de l’API Laravel. Sur émulateur Android : `10.0.2.2`. Sur téléphone physique :
/// enregistre l’URL dans **Aide** ([ApiConfig]) ou compile avec `--dart-define=API_BASE_URL=...`.
class ApiService {
  static String get _apiRoot {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      final base = fromEnv.replaceAll(RegExp(r'/+$'), '');
      return '$base/api';
    }
    final stored = ApiConfig.baseUrlOverride;
    if (stored != null && stored.isNotEmpty) {
      return '${stored.replaceAll(RegExp(r'/+$'), '')}/api';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  /// Origine du serveur Laravel (sans le suffixe `/api`), pour résoudre les URLs `/storage/...`.
  static String get serverOrigin {
    final r = _apiRoot;
    if (r.endsWith('/api/')) {
      return r.substring(0, r.length - 5);
    }
    if (r.endsWith('/api')) {
      return r.substring(0, r.length - 4);
    }
    return r;
  }

  /// Préfixe REST (`…/api`), utile pour l’affichage et le débogage.
  static String get apiRoot => _apiRoot;

  /// Interface Swagger (L5-Swagger), même origine que l’API.
  static String get documentationUrl => '$_apiRoot/documentation';

  /// Vérifie que le backend répond (`GET /up`), pour tester l’URL depuis un téléphone.
  static Future<bool> pingHealth({Duration timeout = const Duration(seconds: 8)}) async {
    final origin = serverOrigin.replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await http.get(Uri.parse('$origin/up')).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// URL publique absolue pour un chemin renvoyé par l’API (ex. `photo_url`).
  /// Réécrit `localhost` / `127.0.0.1` vers [serverOrigin] (ex. `10.0.2.2:8000` sur émulateur).
  static String resolvePublicUrl(String? relativeOrAbsolute) {
    if (relativeOrAbsolute == null || relativeOrAbsolute.isEmpty) {
      return '';
    }
    final s = relativeOrAbsolute.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return _rewriteLocalhostHost(s);
    }
    final origin = serverOrigin;
    if (s.startsWith('/')) {
      return '$origin$s';
    }
    return '$origin/$s';
  }

  static String _rewriteLocalhostHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') {
      return url;
    }
    final originUri = Uri.parse(serverOrigin);
    return originUri.replace(
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }

  /// Identifiant entier robuste (JSON `num` / `String`).
  static int? parseIntId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static dynamic _tryJsonDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
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

  /// Sans timeout, une API injoignable bloque l’UI (chargement infini). 25 s max par requête.
  static const Duration _httpTimeout = Duration(seconds: 25);

  static Future<http.Response> _tw(Future<http.Response> future) {
    return future.timeout(
      _httpTimeout,
      onTimeout: () => http.Response(
        '{"message":"Délai dépassé : serveur ou réseau injoignable. Vérifie l’URL API (ex. IP du PC, VPN) et que le backend tourne."}',
        408,
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  static Future<http.Response> _twMultipart(http.BaseRequest request) async {
    final client = http.Client();
    try {
      final streamed = await client.send(request).timeout(_httpTimeout);
      return await http.Response.fromStream(streamed).timeout(_httpTimeout);
    } on TimeoutException {
      return http.Response(
        '{"message":"Délai dépassé lors de l’envoi du fichier."}',
        408,
        headers: {'content-type': 'application/json'},
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> getClientConfig() async {
    try {
      final response = await _tw(http.get(
        Uri.parse('$_apiRoot/client-config'),
        headers: const {'Accept': 'application/json'},
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    String? role,
    String? fcmToken,
  }) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
          if (role != null && role.isNotEmpty) 'role': role,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
        }),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
    String? fcmToken,
  ) async {
    try {
      final response = await _tw(http.post(
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
      ));
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
    String passwordConfirmation,
    String role,
    String? fcmToken, {
    String? mechanicSpecialty,
  }) async {
    try {
      final response = await _tw(http.post(
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
          'password_confirmation': passwordConfirmation,
          'role': role,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
          if (mechanicSpecialty != null && mechanicSpecialty.trim().isNotEmpty)
            'mechanic_specialty': mechanicSpecialty.trim(),
        }),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await _tw(http.get(
        Uri.parse('$_apiRoot/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
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
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/location'),
        headers: _authHeaders(token),
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> nearbyMechanics(
    String token,
    double latitude,
    double longitude, {
    double radiusKm = 5,
    double? minRating,
    String? specialty,
  }) async {
    try {
      final q = <String, String>{
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radius_km': '$radiusKm',
      };
      if (minRating != null && minRating > 0) {
        q['min_rating'] = '$minRating';
      }
      if (specialty != null && specialty.trim().isNotEmpty) {
        q['specialty'] = specialty.trim();
      }
      final uri = Uri.parse('$_apiRoot/mechanics/nearby').replace(queryParameters: q);
      final response = await _tw(http.get(uri, headers: _authHeaders(token, json: false)));
      final decoded = _tryJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': response.statusCode, 'data': decoded};
      }
      final msg = decoded is Map ? decoded['message']?.toString() : null;
      return {
        'status': response.statusCode,
        'message': msg ?? 'Impossible de charger les mécaniciens (${response.statusCode}).',
      };
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
    String? clientAddress,
    Uint8List? photoBytes,
    String? photoFilename,
  }) async {
    try {
      final hasPhoto = photoBytes != null && photoBytes.isNotEmpty;
      if (hasPhoto) {
        final request = http.MultipartRequest('POST', Uri.parse('$_apiRoot/requests'));
        request.headers['Accept'] = 'application/json';
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['mechanic_id'] = mechanicId.toString();
        request.fields['vehicle_type'] = vehicleType;
        request.fields['description'] = description;
        request.fields['client_lat'] = clientLat.toString();
        request.fields['client_lng'] = clientLng.toString();
        if (clientAddress != null && clientAddress.trim().isNotEmpty) {
          request.fields['client_address'] = clientAddress.trim();
        }
        final name = (photoFilename != null && photoFilename.trim().isNotEmpty)
            ? photoFilename.trim()
            : 'photo.jpg';
        request.files.add(
          http.MultipartFile.fromBytes('photo', photoBytes, filename: name),
        );
        final response = await _twMultipart(request);
        return _parseBody(response);
      }

      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'mechanic_id': mechanicId,
          'vehicle_type': vehicleType,
          'description': description,
          'client_lat': clientLat,
          'client_lng': clientLng,
          if (clientAddress != null && clientAddress.trim().isNotEmpty) 'client_address': clientAddress.trim(),
        }),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'token': token.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> listRequests(String token, {String? status}) async {
    try {
      var uri = Uri.parse('$_apiRoot/requests');
      if (status != null && status.trim().isNotEmpty) {
        uri = uri.replace(queryParameters: {'status': status.trim()});
      }
      final response = await _tw(http.get(
        uri,
        headers: _authHeaders(token, json: false),
      ));
      final decoded = _tryJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': response.statusCode, 'data': decoded};
      }
      final msg = decoded is Map ? decoded['message']?.toString() : null;
      return {
        'status': response.statusCode,
        'message': msg ?? 'Impossible de charger les demandes (${response.statusCode}).',
      };
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Détail d’une demande : conserve le champ JSON `status` (workflow). Utiliser `http_status` pour le code HTTP.
  static Future<Map<String, dynamic>> getInterventionRequest(String token, int id) async {
    try {
      final response = await _tw(http.get(
        Uri.parse('$_apiRoot/requests/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
      final code = response.statusCode;
      final raw = response.body;
      if (raw.isEmpty) {
        return {'http_status': code, 'message': 'Réponse vide'};
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {'http_status': code, 'message': 'Réponse invalide'};
      }
      if (code < 200 || code >= 300) {
        return {
          ...decoded,
          'http_status': code,
        };
      }
      return {
        ...decoded,
        'http_status': code,
      };
    } catch (e) {
      return {'http_status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> patchProfile(
    String token,
    Map<String, dynamic> fields,
  ) async {
    try {
      final response = await _tw(http.patch(
        Uri.parse('$_apiRoot/profile'),
        headers: _authHeaders(token),
        body: jsonEncode(fields),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Photo de profil (multipart `avatar`).
  static Future<Map<String, dynamic>> uploadProfileAvatar(
    String token,
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest('PATCH', Uri.parse('$_apiRoot/profile'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: filename));
      final response = await _twMultipart(request);
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> updateMechanicAvailability(
    String token,
    bool isAvailable,
  ) async {
    return patchProfile(token, {'is_available': isAvailable});
  }

  static Future<Map<String, dynamic>> cancelClientRequest(String token, int id) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$id/cancel'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> acceptRequest(String token, int id) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$id/accept'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> declineRequest(String token, int id) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$id/decline'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Le mécanicien indique que l’intervention sur place est terminée (avant clôture client).
  static Future<Map<String, dynamic>> mechanicMarkRequestComplete(String token, int id) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$id/mechanic-complete'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  /// [outcome] : `fixed` ou `not_fixed` — clôture une demande acceptée.
  static Future<Map<String, dynamic>> recordRequestOutcome(
    String token,
    int requestId,
    String outcome,
  ) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$requestId/outcome'),
        headers: _authHeaders(token),
        body: jsonEncode({'outcome': outcome}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> rateMechanicForRequest(
    String token,
    int requestId, {
    required int stars,
    String? comment,
  }) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$requestId/rating'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'stars': stars,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        }),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> listMessages(String token, int requestId) async {
    try {
      final response = await _tw(http.get(
        Uri.parse('$_apiRoot/requests/$requestId/messages'),
        headers: _authHeaders(token, json: false),
      ));
      final decoded = _tryJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': response.statusCode, 'data': decoded};
      }
      final msg = decoded is Map ? decoded['message']?.toString() : null;
      return {
        'status': response.statusCode,
        'message': msg ?? 'Impossible de charger les messages (${response.statusCode}).',
      };
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  /// [messageType] : `image` ou `audio` — champ multipart `message_type`.
  static Future<Map<String, dynamic>> sendChatMedia(
    String token,
    int requestId, {
    required String messageType,
    required Uint8List bytes,
    required String filename,
    String? caption,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiRoot/requests/$requestId/messages'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['message_type'] = messageType;
      if (caption != null && caption.trim().isNotEmpty) {
        request.fields['body'] = caption.trim();
      }
      request.files.add(
        http.MultipartFile.fromBytes('media', bytes, filename: filename),
      );
      final response = await _twMultipart(request);
      return _parseBody(response);
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
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/requests/$requestId/messages'),
        headers: _authHeaders(token),
        body: jsonEncode({'body': body}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> touchPresence(String token) async {
    try {
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/presence/touch'),
        headers: _authHeaders(token),
      ));
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
      final response = await _tw(http.post(
        Uri.parse('$_apiRoot/push/token'),
        headers: _authHeaders(token),
        body: jsonEncode({'fcm_token': fcmToken}),
      ));
      return _parseBody(response);
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }
}
