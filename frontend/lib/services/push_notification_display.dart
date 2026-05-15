import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Affiche une notification locale à partir d’un message FCM (premier plan ou arrière-plan).
class PushNotificationDisplay {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'mechassist_high',
    'MechAssist',
    description: 'Demandes et messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static void Function(NotificationResponse)? onTap;

  static Future<void> requestAndroidPostNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await ensureInitialized();
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    if (_ready) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
    _ready = true;
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final n = message.notification;
    final data = message.data;
    final title = n?.title ?? data['title']?.toString() ?? data['sender_name']?.toString() ?? 'MechAssist';
    final body = n?.body ??
        data['body']?.toString() ??
        data['message_preview']?.toString() ??
        'Nouvelle alerte';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _local.show(
        message.hashCode.abs(),
        title,
        body,
        details,
        payload: jsonEncode(data),
      );
    } catch (e, st) {
      assert(() {
        debugPrint('PushNotificationDisplay: $e $st');
        return true;
      }());
    }
  }
}
