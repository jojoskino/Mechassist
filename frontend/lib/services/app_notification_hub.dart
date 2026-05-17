import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'live_sync.dart';

/// Notifications in-app (historique + compteur non lues).
class AppNotificationHub extends ChangeNotifier {
  AppNotificationHub._();
  static final AppNotificationHub instance = AppNotificationHub._();

  final List<AppNotificationItem> items = [];
  int unreadCount = 0;

  void ingestRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ??
        data['title']?.toString() ??
        data['sender_name']?.toString() ??
        'MechAssist';
    final body = message.notification?.body ??
        data['body']?.toString() ??
        data['message_preview']?.toString() ??
        '';
    final type = data['type']?.toString() ?? 'general';
    final requestId = int.tryParse(data['request_id']?.toString() ?? '');

    items.insert(
      0,
      AppNotificationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: type,
        requestId: requestId,
        receivedAt: DateTime.now(),
        data: Map<String, dynamic>.from(data),
      ),
    );
    if (items.length > 80) {
      items.removeRange(80, items.length);
    }
    unreadCount++;
    notifyListeners();
    LiveSync.instance.pulse();
  }

  void markAllRead() {
    unreadCount = 0;
    notifyListeners();
  }

  void markReadAt(int index) {
    if (unreadCount > 0) unreadCount--;
    notifyListeners();
  }

  void clear() {
    items.clear();
    unreadCount = 0;
    notifyListeners();
  }
}

class AppNotificationItem {
  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.requestId,
    this.data = const {},
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime receivedAt;
  final int? requestId;
  final Map<String, dynamic> data;
}
