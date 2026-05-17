import 'api_service.dart';

/// Config publique (`/api/client-config`) — une seule requête, réutilisée partout.
class ClientConfigCache {
  ClientConfigCache._();

  static Map<String, dynamic>? _data;
  static DateTime? _loadedAt;
  static Future<Map<String, dynamic>>? _inFlight;

  static const _ttl = Duration(hours: 12);

  static Future<Map<String, dynamic>> get({bool force = false}) async {
    if (!force &&
        _data != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _ttl) {
      return Map<String, dynamic>.from(_data!);
    }
    if (!force && _inFlight != null) {
      return Map<String, dynamic>.from(await _inFlight!);
    }
    _inFlight = _fetch();
    try {
      final fresh = await _inFlight!;
      return Map<String, dynamic>.from(fresh);
    } finally {
      _inFlight = null;
    }
  }

  static Future<Map<String, dynamic>> _fetch() async {
    final res = await ApiService.getClientConfig();
    _data = res;
    _loadedAt = DateTime.now();
    return res;
  }

  static String? googleMapsWebKey() {
    final raw = _data?['google_maps_web_api_key'];
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty || s == 'null') return null;
    return s;
  }

  static void clear() {
    _data = null;
    _loadedAt = null;
    _inFlight = null;
  }
}
