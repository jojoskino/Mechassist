import 'package:shared_preferences/shared_preferences.dart';

/// Préférence locale : notifications push activées (profil).
class PushPreferences {
  static const _key = 'push_notifications_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
