import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_sync.dart';

/// Notifications in-app (historique + compteur non lues), persistantes + API.
class AppNotificationHub extends ChangeNotifier {
  AppNotificationHub._();
  static final AppNotificationHub instance = AppNotificationHub._();

  static const _prefsKey = 'mechassist_notification_items_v1';

  final List<AppNotificationItem> items = [];
  int unreadCount = 0;
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final e in list) {
        if (e is! Map) continue;
        final item = AppNotificationItem.fromJson(Map<String, dynamic>.from(e));
        if (!_hasId(item.id)) {
          items.add(item);
        }
      }
      _recomputeUnread();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final slice = items.take(80).map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(slice));
  }

  bool _hasId(String id) => items.any((e) => e.id == id);

  void _recomputeUnread() {
    unreadCount = items.where((e) => !e.read).length;
  }

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
    final id = data['message_id']?.toString() ??
        'fcm-${DateTime.now().microsecondsSinceEpoch}';

    ingest(
      id: id,
      title: title,
      body: body,
      type: type,
      requestId: requestId,
      data: Map<String, dynamic>.from(data),
    );
  }

  /// Aligne le hub avec l'API : nouveaux non-lus + retrait si deja lus cote serveur.
  void syncUnreadFromApi(List<dynamic> rows) {
    final apiIds = <String>{};
    for (final row in rows) {
      if (row is Map) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) apiIds.add(id);
      }
    }
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      final n = items[i];
      if (n.type == 'chat_message' && !n.read && !apiIds.contains(n.id)) {
        items[i] = n.copyWith(read: true);
        changed = true;
      }
    }
    final added = _ingestApiRowsInternal(rows);
    if (changed || added) {
      if (items.length > 80) {
        items.removeRange(80, items.length);
      }
      _recomputeUnread();
      notifyListeners();
      unawaited(_persist());
      if (added) LiveSync.instance.pulse();
    }
  }

  void ingestApiRows(List<dynamic> rows) {
    if (_ingestApiRowsInternal(rows)) {
      if (items.length > 80) {
        items.removeRange(80, items.length);
      }
      _recomputeUnread();
      notifyListeners();
      unawaited(_persist());
      LiveSync.instance.pulse();
    }
  }

  bool _ingestApiRowsInternal(List<dynamic> rows) {
    var added = false;
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final id = map['id']?.toString();
      if (id == null || id.isEmpty || _hasId(id)) continue;
      final requestId = int.tryParse(map['request_id']?.toString() ?? '');
      DateTime receivedAt = DateTime.now();
      final created = map['created_at']?.toString();
      if (created != null && created.isNotEmpty) {
        receivedAt = DateTime.tryParse(created) ?? receivedAt;
      }
      items.insert(
        0,
        AppNotificationItem(
          id: id,
          title: map['title']?.toString() ?? 'MechAssist',
          body: map['body']?.toString() ?? '',
          type: map['type']?.toString() ?? 'general',
          requestId: requestId,
          receivedAt: receivedAt,
          data: map['data'] is Map
              ? Map<String, dynamic>.from(map['data'] as Map)
              : const {},
          read: false,
        ),
      );
      added = true;
    }
    return added;
  }

  void ingest({
    required String id,
    required String title,
    required String body,
    required String type,
    int? requestId,
    Map<String, dynamic> data = const {},
    bool read = false,
  }) {
    if (_hasId(id)) return;
    items.insert(
      0,
      AppNotificationItem(
        id: id,
        title: title,
        body: body,
        type: type,
        requestId: requestId,
        receivedAt: DateTime.now(),
        data: data,
        read: read,
      ),
    );
    if (items.length > 80) {
      items.removeRange(80, items.length);
    }
    _recomputeUnread();
    notifyListeners();
    unawaited(_persist());
    LiveSync.instance.pulse();
  }

  void ingestChatMessage({
    required int messageId,
    required int requestId,
    required String senderName,
    required String preview,
    required Map<String, dynamic> data,
  }) {
    ingest(
      id: 'msg-$messageId',
      title: senderName,
      body: preview,
      type: 'chat_message',
      requestId: requestId,
      data: data,
    );
  }

  void markAllRead() {
    for (var i = 0; i < items.length; i++) {
      if (!items[i].read) {
        items[i] = items[i].copyWith(read: true);
      }
    }
    unreadCount = 0;
    notifyListeners();
    unawaited(_persist());
  }

  void markReadAt(int index) {
    if (index < 0 || index >= items.length) return;
    if (!items[index].read) {
      items[index] = items[index].copyWith(read: true);
      if (unreadCount > 0) unreadCount--;
      notifyListeners();
      unawaited(_persist());
    }
  }

  void clear() {
    items.clear();
    unreadCount = 0;
    notifyListeners();
    unawaited(_persist());
  }

  /// Retire les notifications de chat pour une demande (apres lecture).
  void clearChatForRequest(int requestId) {
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      final n = items[i];
      if (n.requestId == requestId && n.type == 'chat_message' && !n.read) {
        items[i] = n.copyWith(read: true);
        changed = true;
      }
    }
    if (changed) {
      _recomputeUnread();
      notifyListeners();
      unawaited(_persist());
    }
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
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime receivedAt;
  final int? requestId;
  final Map<String, dynamic> data;
  final bool read;

  AppNotificationItem copyWith({bool? read}) {
    return AppNotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      receivedAt: receivedAt,
      requestId: requestId,
      data: data,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'received_at': receivedAt.toIso8601String(),
        'request_id': requestId,
        'data': data,
        'read': read,
      };

  static AppNotificationItem fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      requestId: int.tryParse(json['request_id']?.toString() ?? ''),
      receivedAt: DateTime.tryParse(json['received_at']?.toString() ?? '') ?? DateTime.now(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : const {},
      read: json['read'] == true,
    );
  }
}
