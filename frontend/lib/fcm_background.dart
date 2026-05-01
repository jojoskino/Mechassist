import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Handler FCM en tâche de fond (obligatoire : fonction de premier niveau + pragma).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  if (kDebugMode) {
    debugPrint('FCM background: ${message.messageId} data=${message.data}');
  }
}
