import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'services/app_notification_hub.dart';
import 'services/push_notification_display.dart';

/// Handler FCM en tâche de fond : affiche la notification même si l’app est minimisée.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  if (kDebugMode) {
    debugPrint('FCM background: ${message.messageId} data=${message.data}');
  }
  AppNotificationHub.instance.ingestRemoteMessage(message);
  await PushNotificationDisplay.showFromRemoteMessage(message);
}
