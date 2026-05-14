import 'package:shared_preferences/shared_preferences.dart';

/// URL de base Laravel **sans** le suffixe `/api` (ex. `http://192.168.1.10:8000`).
/// Sur téléphone physique, `10.0.2.2` (émulateur) ne fonctionne pas : l’utilisateur peut
/// enregistrer l’IP du PC ici (écran Aide).
class ApiConfig {
  ApiConfig._();

  static const String _prefsKey = 'mechassist_api_base_url';

  /// Valeur en mémoire après [load] ou [setBaseUrlOverride].
  static String? _override;

  static String? get baseUrlOverride => _override;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    var normalized = _normalizeStored(raw);
    if (raw != null && raw.trim().isNotEmpty && normalized == null) {
      await prefs.remove(_prefsKey);
    }
    _override = normalized;
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
    // 0.0.0.0 = bind « toutes interfaces » côté serveur ; invalide dans navigateur / app.
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
