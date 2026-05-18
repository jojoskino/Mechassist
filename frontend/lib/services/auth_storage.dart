import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session : jeton API chiffré (secure storage), rôle/nom en préférences.
class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';
  static const _nameKey = 'user_name';
  static const _avatarUrlKey = 'user_avatar_url';
  static const _avatarEpochKey = 'user_avatar_epoch';
  static const _legacyTokenKey = 'auth_token';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<void> save({
    required String token,
    required String role,
    required String name,
    String? avatarUrl,
    int? avatarCacheEpoch,
  }) async {
    await _secure.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
    await prefs.setString(_nameKey, name);
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      await prefs.setString(_avatarUrlKey, avatarUrl.trim());
    }
    if (avatarCacheEpoch != null) {
      await prefs.setInt(_avatarEpochKey, avatarCacheEpoch);
    }
    await prefs.remove(_legacyTokenKey);
  }

  static Future<void> updateAvatar(String? avatarUrl, {int? cacheEpoch}) async {
    final prefs = await SharedPreferences.getInstance();
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      await prefs.remove(_avatarUrlKey);
    } else {
      await prefs.setString(_avatarUrlKey, avatarUrl.trim());
    }
    await prefs.setInt(_avatarEpochKey, cacheEpoch ?? DateTime.now().millisecondsSinceEpoch);
  }

  static Future<({String? avatarUrl, int avatarEpoch})> getAvatarFields() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      avatarUrl: prefs.getString(_avatarUrlKey),
      avatarEpoch: prefs.getInt(_avatarEpochKey) ?? 0,
    );
  }

  static Future<String?> getToken() async {
    var token = await _secure.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_legacyTokenKey);
    if (token != null && token.isNotEmpty) {
      await _secure.write(key: _tokenKey, value: token);
      await prefs.remove(_legacyTokenKey);
    }
    return token;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  static Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
  }

  static Future<void> clear() async {
    await _secure.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_avatarUrlKey);
    await prefs.remove(_avatarEpochKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String?>> getSessionFields() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': await getToken(),
      'role': prefs.getString(_roleKey),
      'name': prefs.getString(_nameKey),
    };
  }
}
