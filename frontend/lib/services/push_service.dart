import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firebase_bootstrap.dart';

class PushService {
  static Future<String?> initAndGetToken() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    await FirebaseBootstrap.init();
    if (!FirebaseBootstrap.initialized) {
      return null;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    return messaging.getToken();
  }
}
