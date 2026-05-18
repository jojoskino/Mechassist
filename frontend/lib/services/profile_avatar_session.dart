import 'auth_storage.dart';

/// Avatar du compte connecté : URL API + epoch pour bust cache navigateur.
class ProfileAvatarSession {
  ProfileAvatarSession._();

  static String? avatarUrl;
  static int cacheEpoch = 0;

  static void applyFromApi(Map<String, dynamic> user) {
    final url = user['avatar_url']?.toString().trim();
    if (url != null && url.isNotEmpty) {
      avatarUrl = url;
      cacheEpoch = DateTime.now().millisecondsSinceEpoch;
    }
  }

  static void bump({String? url}) {
    if (url != null && url.trim().isNotEmpty) {
      avatarUrl = url.trim();
    }
    cacheEpoch = DateTime.now().millisecondsSinceEpoch;
  }

  static int? epochForUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (avatarUrl != null && url == avatarUrl) return cacheEpoch;
    return null;
  }

  static Future<void> persistFromUser(Map<String, dynamic> user) async {
    applyFromApi(user);
    await AuthStorage.updateAvatar(avatarUrl, cacheEpoch: cacheEpoch);
  }
}
