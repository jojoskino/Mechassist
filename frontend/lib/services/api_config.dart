import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL de base Laravel **sans** le suffixe `/api` (ex. `http://192.168.1.10:8000`).
/// L’URL réelle vient de `--dart-define=API_BASE_URL` (scripts `run_*.ps1` / ngrok auto).
class ApiConfig {
  ApiConfig._();

  static const String _legacyRenderOrigin = 'https://mechassist-api.onrender.com';

  static const String _prefsKey = 'mechassist_api_base_url';
  static const String _defaultSeededKey = 'mechassist_api_default_seeded';

  /// Valeur en mémoire après [load] ou [setBaseUrlOverride].
  static String? _override;

  static String? get baseUrlOverride => _override;

  /// URL compilée via `flutter run --dart-define=API_BASE_URL=...` (scripts run_*.ps1).
  static String? get compiledApiOrigin {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isEmpty) return null;
    return _normalizeStored(fromEnv);
  }

  /// Origine affichée / secours après [load].
  static String get productionOrigin =>
      compiledApiOrigin ?? _override ?? 'http://127.0.0.1:8000';

  /// En-tête requis par ngrok free pour éviter la page d’avertissement navigateur.
  static Map<String, String> ngrokHeadersFor(String origin) {
    try {
      final host = Uri.parse(origin).host.toLowerCase();
      if (host.contains('ngrok')) {
        return const {'ngrok-skip-browser-warning': 'true'};
      }
    } catch (_) {}
    return const {};
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    var normalized = _normalizeStored(raw);
    if (raw != null && raw.trim().isNotEmpty && normalized == null) {
      await prefs.remove(_prefsKey);
    }
    if (normalized == _legacyRenderOrigin) {
      normalized = null;
      await prefs.remove(_prefsKey);
    }
    _override = normalized;
  }

  /// Synchronise l’URL compilée (ngrok auto au lancement) et évite localhost sur mobile.
  static Future<void> ensureProductionDefault() async {
    await load();

    final compiled = compiledApiOrigin;
    if (compiled != null && compiled.isNotEmpty) {
      if (_override != compiled) {
        await setBaseUrlOverride(compiled);
      }
      return;
    }

    if (_override != null && _isEmulatorOnlyHost(_override!)) {
      if (!kIsWeb) {
        await setBaseUrlOverride(null);
      }
      return;
    }

    if (kIsWeb) {
      return;
    }

    if (_override != null && _override!.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_defaultSeededKey) == true) return;
    await prefs.setBool(_defaultSeededKey, true);
  }

  /// Hôtes valides sur émulateur mais pas sur un téléphone physique.
  static bool _isEmulatorOnlyHost(String origin) {
    try {
      final host = Uri.parse(origin).host.toLowerCase();
      return host == '10.0.2.2' ||
          host == '127.0.0.1' ||
          host == 'localhost' ||
          host == '0.0.0.0';
    } catch (_) {
      return false;
    }
  }

  static String? _normalizeStored(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/api')) {
      s = s.substring(0, s.length - 4);
    }
    if (_hostIsZero(s)) {
      return null;
    }
    return s;
  }

  static bool _hostIsZero(String originWithScheme) {
    try {
      return Uri.parse(originWithScheme).host == '0.0.0.0';
    } catch (_) {
      return false;
    }
  }

  /// `true` si l’hôte est 0.0.0.0 (à refuser à la saisie).
  static bool isClientHostInvalid(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    var s = raw.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/api')) {
      s = s.substring(0, s.length - 4);
    }
    return _hostIsZero(s);
  }

  /// [origin] : `http://host:port` sans `/api`. Vide ou null supprime la surcharge.
  static Future<void> setBaseUrlOverride(String? origin) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = origin == null ? null : _normalizeStored(origin);
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_prefsKey);
      _override = null;
      return;
    }
    await prefs.setString(_prefsKey, normalized);
    _override = normalized;
  }
}
