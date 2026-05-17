import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_response_cache.dart';
import 'live_sync.dart';

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
    // Web + mobile : API Render par défaut (localhost uniquement si surcharge dans Aide ou dart-define).
    return '${ApiConfig.productionOrigin}/api';
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

  static final http.Client _client = http.Client();

  static bool _serverWarm = false;
  static Future<bool>? _warming;

  /// Réveille Render. [wait] : attendre que le serveur réponde (splash / login).
  static Future<bool> warmServer({bool wait = true}) {
    if (_serverWarm && !wait) return Future.value(true);
    _warming ??= _doWarm();
    final f = _warming!;
    if (!wait) return f;
    return f;
  }

  static Future<bool> _doWarm() async {
    for (var i = 0; i < 3; i++) {
      if (await pingHealth(timeout: const Duration(seconds: 6))) {
        _serverWarm = true;
        _warming = null;
        return true;
      }
      if (i < 2) await Future<void>.delayed(Duration(milliseconds: 400 + i * 300));
    }
    _warming = null;
    return false;
  }

  /// Vérifie que le backend répond (`/api/health` puis `/up`).
  static Future<bool> pingHealth({Duration timeout = const Duration(seconds: 5)}) async {
    final origin = serverOrigin.replaceAll(RegExp(r'/+$'), '');
    for (final path in ['/api/health', '/up']) {
      try {
        final response = await _client.get(Uri.parse('$origin$path')).timeout(timeout);
        if (response.statusCode == 200) {
          _serverWarm = true;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Message lisible pour l’utilisateur (validation Laravel, réseau, etc.).
  static String userFacingMessage(
    Map<String, dynamic> res, {
    String fallback = 'Une erreur est survenue.',
  }) {
    final errors = res['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) {
          return v.first.toString();
        }
        if (v != null) return v.toString();
      }
    }
    final msg = res['message']?.toString().trim();
    if (msg != null && msg.isNotEmpty && msg.length < 400) {
      return msg;
    }
    final status = res['status'] as int? ?? res['http_status'] as int?;
    if (status == 401 || status == 403) {
      return 'Session expirée. Reconnectez-vous.';
    }
    if (status == 422) {
      return 'Vérifiez les informations saisies.';
    }
    if (isTransientFailure(res)) {
      return 'Connexion lente. Réessayez dans quelques secondes.';
    }
    return fallback;
  }

  /// Erreur réseau transitoire (cold start Render) — ne pas afficher à l’utilisateur.
  static bool isTransientFailure(Map<String, dynamic> res) {
    final status = res['status'] as int? ?? res['http_status'] as int?;
    if (status == 408 || status == 0 || status == 502 || status == 503 || status == 504) {
      return true;
    }
    final msg = (res['message'] ?? '').toString().toLowerCase();
    return msg.contains('délai') ||
        msg.contains('delai') ||
        msg.contains('temps') ||
        msg.contains('injoignable') ||
        msg.contains('timeout');
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

  static const Duration _httpTimeoutWarm = Duration(seconds: 18);
  static const Duration _httpTimeoutCold = Duration(seconds: 35);
  static const Duration _uploadTimeoutWarm = Duration(seconds: 45);
  static const Duration _uploadTimeoutCold = Duration(seconds: 60);

  static const _transientBody = '{"message":"","transient":true}';

  static Future<http.Response> _tw(Future<http.Response> Function() request) async {
    final attempts = _serverWarm ? 1 : 2;
    final timeout = _serverWarm ? _httpTimeoutWarm : _httpTimeoutCold;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        unawaited(warmServer(wait: false));
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      try {
        final response = await request().timeout(timeout);
        if (_shouldRetryStatus(response.statusCode) && attempt < attempts - 1) {
          continue;
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _serverWarm = true;
        }
        return response;
      } on TimeoutException {
        if (attempt < attempts - 1) continue;
      }
    }
    return http.Response(_transientBody, 408, headers: {'content-type': 'application/json'});
  }

  static bool _shouldRetryStatus(int code) =>
      code == 408 || code == 502 || code == 503 || code == 504;

  static Future<http.Response> _twMultipart(http.BaseRequest request) async {
    final attempts = _serverWarm ? 2 : 3;
    final timeout = _serverWarm ? _uploadTimeoutWarm : _uploadTimeoutCold;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        unawaited(warmServer(wait: false));
        await Future<void>.delayed(Duration(milliseconds: 500 + attempt * 300));
      }
      try {
        final streamed = await _client.send(request).timeout(timeout);
        final response = await http.Response.fromStream(streamed).timeout(timeout);
        if (_shouldRetryStatus(response.statusCode) && attempt < attempts - 1) {
          continue;
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _serverWarm = true;
        }
        return response;
      } on TimeoutException {
        if (attempt < attempts - 1) continue;
      }
    }
    return http.Response(_transientBody, 408, headers: {'content-type': 'application/json'});
  }

  /// Mise à jour position sans bloquer l’UI.
  static void postLocation(String token, double latitude, double longitude) {
    unawaited(updateLocation(token, latitude, longitude));
  }

  static Future<Map<String, dynamic>> getClientConfig() async {
    try {
      final response = await _tw(() => _client.get(
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
      final response = await _tw(() => _client.post(
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
      final response = await _tw(() => _client.post(
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
      final response = await _tw(() => _client.post(
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
      final response = await _tw(() => _client.post(
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

  static Future<Map<String, dynamic>> getMe(String token, {bool force = false}) async {
    if (!force) {
      final cached = ApiResponseCache.meIfFresh(token);
      if (cached != null) return cached;
    }
    try {
      final response = await _tw(() => _client.get(
        Uri.parse('$_apiRoot/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        ApiResponseCache.putMe(token, body);
      }
      return body;
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
      final response = await _tw(() => _client.post(
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
      final response = await _tw(() => _client.get(uri, headers: _authHeaders(token, json: false)));
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
      await warmServer(wait: true);
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
        final body = _normalizeApiResult(_parseBody(await _twMultipart(request)));
        final stPhoto = body['status'] as int?;
        if (stPhoto != null && stPhoto >= 200 && stPhoto < 300) {
          _afterRequestMutation();
        }
        return body;
      }

      final response = await _tw(() => _client.post(
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
      final body = _normalizeApiResult(_parseBody(response));
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        _afterRequestMutation();
      }
      return body;
    } catch (e) {
      return _networkFailure(e);
    }
  }

  static Map<String, dynamic> _normalizeApiResult(Map<String, dynamic> body) {
    final status = body['status'] as int?;
    if (status == 408 && body['transient'] == true) {
      return {
        ...body,
        'message': userFacingMessage(body, fallback: 'Le serveur met du temps à répondre. Réessayez.'),
      };
    }
    return body;
  }

  static Map<String, dynamic> _networkFailure(Object e) {
    final origin = serverOrigin;
    return {
      'status': 0,
      'message': 'Connexion impossible ($origin). Vérifiez le réseau ou l’URL dans Aide. Détail : $e',
    };
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _tw(() => _client.post(
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
      final response = await _tw(() => _client.post(
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

  static void _afterRequestMutation() {
    ApiResponseCache.invalidateRequestLists();
    LiveSync.instance.pulse();
  }

  static Future<Map<String, dynamic>> listRequests(
    String token, {
    String? status,
    bool force = false,
  }) async {
    try {
      if (!force) {
        final cached = ApiResponseCache.requestListIfFresh(token, status: status);
        if (cached != null) {
          return {'status': 200, 'data': cached};
        }
      }
      var uri = Uri.parse('$_apiRoot/requests');
      if (status != null && status.trim().isNotEmpty) {
        uri = uri.replace(queryParameters: {'status': status.trim()});
      }
      final response = await _tw(() => _client.get(
        uri,
        headers: _authHeaders(token, json: false),
      ));
      final decoded = _tryJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is List) {
        ApiResponseCache.putRequestList(token, decoded, status: status);
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
  static Future<Map<String, dynamic>> getInterventionRequest(
    String token,
    int id, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = ApiResponseCache.requestIfFresh(id);
      if (cached != null) return cached;
    }
    try {
      final response = await _tw(() => _client.get(
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
      final out = {
        ...decoded,
        'http_status': code,
      };
      ApiResponseCache.putRequest(id, out);
      return out;
    } catch (e) {
      return {'http_status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> patchProfile(
    String token,
    Map<String, dynamic> fields,
  ) async {
    try {
      final response = await _tw(() => _client.patch(
        Uri.parse('$_apiRoot/profile'),
        headers: _authHeaders(token),
        body: jsonEncode(fields),
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        ApiResponseCache.invalidateMe();
      }
      return body;
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
      final response = await _tw(() => _client.post(
        Uri.parse('$_apiRoot/requests/$id/cancel'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        _afterRequestMutation();
      }
      return body;
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> acceptRequest(String token, int id) async {
    try {
      final response = await _tw(() => _client.post(
        Uri.parse('$_apiRoot/requests/$id/accept'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        _afterRequestMutation();
      }
      return body;
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> declineRequest(String token, int id) async {
    try {
      final response = await _tw(() => _client.post(
        Uri.parse('$_apiRoot/requests/$id/decline'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        _afterRequestMutation();
      }
      return body;
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Le mécanicien indique que l’intervention sur place est terminée (avant clôture client).
  static Future<Map<String, dynamic>> mechanicMarkRequestComplete(String token, int id) async {
    try {
      final response = await _tw(() => _client.post(
        Uri.parse('$_apiRoot/requests/$id/mechanic-complete'),
        headers: _authHeaders(token),
        body: jsonEncode(<String, dynamic>{}),
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        _afterRequestMutation();
      }
      return body;
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
      final response = await _tw(() => _client.post(
        Uri.parse('$_apiRoot/requests/$requestId/outcome'),
        headers: _authHeaders(token),
        body: jsonEncode({'outcome': outcome}),
      ));
      final body = _parseBody(response);
      final st = body['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        _afterRequestMutation();
      }
      return body;
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
      final response = await _tw(() => _client.post(
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

  static Future<Map<String, dynamic>> listMessages(
    String token,
    int requestId, {
    bool markRead = false,
    bool force = false,
  }) async {
    if (!force && !markRead) {
      final cached = ApiResponseCache.messagesIfFresh(requestId);
      if (cached != null) {
        return {'status': 200, 'data': cached};
      }
    }
    try {
      final uri = markRead
          ? Uri.parse('$_apiRoot/requests/$requestId/messages').replace(
              queryParameters: const {'mark_read': '1'},
            )
          : Uri.parse('$_apiRoot/requests/$requestId/messages');
      final response = await _tw(() => _client.get(
        uri,
        headers: _authHeaders(token, json: false),
      ));
      final decoded = _tryJsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) {
          ApiResponseCache.putMessages(requestId, decoded);
        }
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
      final parsed = _parseBody(response);
      final st = parsed['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        ApiResponseCache.invalidateMessages(requestId);
      }
      return parsed;
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
      final response = await _tw(() => _client.post(
        Uri.parse('$_apiRoot/requests/$requestId/messages'),
        headers: _authHeaders(token),
        body: jsonEncode({'body': body}),
      ));
      final parsed = _parseBody(response);
      final st = parsed['status'] as int?;
      if (st != null && st >= 200 && st < 300) {
        ApiResponseCache.invalidateMessages(requestId);
      }
      return parsed;
    } catch (e) {
      return {'status': 0, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> touchPresence(String token) async {
    try {
      final response = await _tw(() => _client.post(
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
      final response = await _tw(() => _client.post(
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
