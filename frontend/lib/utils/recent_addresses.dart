import 'package:shared_preferences/shared_preferences.dart';

/// Repères récents pour le formulaire de demande (style « destinations récentes »).
class RecentAddresses {
  static const _key = 'recent_request_addresses';
  static const _max = 8;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> add(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.removeWhere((e) => e.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    if (list.length > _max) {
      list.removeRange(_max, list.length);
    }
    await prefs.setStringList(_key, list);
  }
}
