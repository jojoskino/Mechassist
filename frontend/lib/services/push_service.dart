import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import 'auth_storage.dart';
import 'firebase_bootstrap.dart';

/// FCM sur Android : permission, token, notifications en premier plan (canal local).
class PushService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _handlersBound = false;
  static bool _localReady = false;

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'mechassist_high',
    'MechAssist',
    description: 'Demandes et messages',
    importance: Importance.high,
  );

  static Future<void> _ensureLocalNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (_localReady) {
      return;
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    _localReady = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode && response.payload != null) {
      debugPrint('Notification tap payload: ${response.payload}');
    }
  }

  static Future<void> _bindListenersOnce() async {
    if (_handlersBound || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!FirebaseBootstrap.initialized) {
      return;
    }
    _handlersBound = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _ensureLocalNotifications();
      final n = message.notification;
      final title = n?.title ?? 'MechAssist';
      final body = n?.body ?? message.data['body']?.toString() ?? 'Nouvelle alerte';
      try {
        await _local.show(
          message.hashCode.abs(),
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      } catch (e, st) {
        assert(() {
          debugPrint('Notification locale: $e $st');
          return true;
        }());
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final auth = await AuthStorage.getToken();
      if (auth != null) {
        await ApiService.updatePushToken(auth, newToken);
      }
    });
  }

  /// À appeler après connexion ou au démarrage si session valide : enregistre les listeners et retourne le jeton FCM.
  static Future<String?> initAndGetToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    await FirebaseBootstrap.init();
    if (!FirebaseBootstrap.initialized) {
      return null;
    }
    await _ensureLocalNotifications();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _bindListenersOnce();
    return messaging.getToken();
  }
}
