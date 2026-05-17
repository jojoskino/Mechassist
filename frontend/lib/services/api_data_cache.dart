import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache mémoire + disque — affichage instantané sans attendre le réseau.
class ApiDataCache {
  ApiDataCache._();

  static const _requestsKey = 'mechassist_cache_requests';
  static const _mechanicsKey = 'mechassist_cache_mechanics';
  static const _meRequestsKey = 'mechassist_cache_me_requests';
  static const _chatPrefix = 'mechassist_cache_chat_';

  static SharedPreferences? _prefs;
  static List<dynamic>? _clientRequests;
  static List<dynamic>? _mechanicRequests;
  static List<dynamic>? _mechanics;

  static Future<void> preload() async {
    _prefs ??= await SharedPreferences.getInstance();
    _clientRequests = _decodeList(_prefs!.getString(_requestsKey));
    _mechanicRequests = _decodeList(_prefs!.getString(_meRequestsKey));
    _mechanics = _decodeList(_prefs!.getString(_mechanicsKey));
  }

  static List<dynamic>? _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? List<dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic>? requestsSync({required bool mechanic}) =>
      mechanic ? _mechanicRequests : _clientRequests;

  static List<dynamic>? mechanicsSync() => _mechanics;

  static Future<List<dynamic>?> loadRequests({required bool mechanic}) async {
    await preload();
    return requestsSync(mechanic: mechanic);
  }

  static Future<void> saveRequests(List<dynamic> data, {required bool mechanic}) async {
    if (mechanic) {
      _mechanicRequests = List<dynamic>.from(data);
    } else {
      _clientRequests = List<dynamic>.from(data);
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(
      mechanic ? _meRequestsKey : _requestsKey,
      jsonEncode(data),
    );
  }

  static Future<List<dynamic>?> loadMechanics() async {
    await preload();
    return mechanicsSync();
  }

  static Future<void> saveMechanics(List<dynamic> data) async {
    _mechanics = List<dynamic>.from(data);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_mechanicsKey, jsonEncode(data));
  }

  static List<dynamic>? messagesSync(int requestId) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return _decodeList(prefs.getString('$_chatPrefix$requestId'));
  }

  static Future<List<dynamic>?> loadMessages(int requestId) async {
    await preload();
    return messagesSync(requestId);
  }

  static Future<void> saveMessages(int requestId, List<dynamic> data) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('$_chatPrefix$requestId', jsonEncode(data));
  }

  static Future<void> clear() async {
    _clientRequests = null;
    _mechanicRequests = null;
    _mechanics = null;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_requestsKey);
    await prefs.remove(_mechanicsKey);
    await prefs.remove(_meRequestsKey);
    final keys = prefs.getKeys().where((k) => k.startsWith(_chatPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
