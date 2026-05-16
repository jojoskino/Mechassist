import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_notification_hub.dart';
import 'push_sync.dart';
import 'firebase_bootstrap.dart';
import 'notification_navigation.dart';
import 'push_notification_display.dart';

/// FCM : permission, token, notifications instantanées (premier plan + canal Android).
class PushService {
  static bool _handlersBound = false;

  static void _onNotificationTap(NotificationResponse response) {
    NotificationNavigation.handlePayloadString(response.payload);
  }

  static Future<void> _bindListenersOnce() async {
    if (_handlersBound || kIsWeb) {
      return;
    }
    if (!FirebaseBootstrap.initialized) {
      return;
    }
    _handlersBound = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      AppNotificationHub.instance.ingestRemoteMessage(message);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await PushNotificationDisplay.showFromRemoteMessage(message);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      await PushSync.syncToken();
    });
  }

  /// Après connexion ou au démarrage : listeners + jeton FCM.
  static Future<String?> initAndGetToken() async {
    if (kIsWeb) {
      return null;
    }
    await FirebaseBootstrap.init();
    if (!FirebaseBootstrap.initialized) {
      return null;
    }

    PushNotificationDisplay.onTap = _onNotificationTap;
    await PushNotificationDisplay.ensureInitialized();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await PushNotificationDisplay.requestAndroidPostNotifications();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    await _bindListenersOnce();
    return messaging.getToken();
  }
}
