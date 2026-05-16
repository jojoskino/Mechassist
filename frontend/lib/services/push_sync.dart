import 'api_service.dart';
import 'auth_storage.dart';
import 'push_preferences.dart';
import 'push_service.dart';

/// Enregistre ou retire le jeton FCM selon la préférence utilisateur.
class PushSync {
  static Future<void> syncToken() async {
    final auth = await AuthStorage.getToken();
    if (auth == null) return;

    final enabled = await PushPreferences.isEnabled();
    if (!enabled) {
      await ApiService.updatePushToken(auth, null);
      return;
    }

    final fcm = await PushService.initAndGetToken();
    if (fcm != null && fcm.isNotEmpty) {
      await ApiService.updatePushToken(auth, fcm);
    }
  }
}
