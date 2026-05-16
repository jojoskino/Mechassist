import 'api_service.dart';
import 'auth_storage.dart';
import 'push_preferences.dart';
import 'push_service.dart';

/// Enregistre ou retire le jeton FCM selon la préférence utilisateur.
class PushSync {
  /// `true` si le jeton a été enregistré côté serveur.
  static Future<bool> syncToken() async {
    final auth = await AuthStorage.getToken();
    if (auth == null) return false;

    final enabled = await PushPreferences.isEnabled();
    if (!enabled) {
      await ApiService.updatePushToken(auth, null);
      return true;
    }

    final fcm = await PushService.initAndGetToken();
    if (fcm == null || fcm.isEmpty) {
      return false;
    }
    final res = await ApiService.updatePushToken(auth, fcm);
    final code = res['status'] as int?;
    return code != null && code >= 200 && code < 300;
  }
}
