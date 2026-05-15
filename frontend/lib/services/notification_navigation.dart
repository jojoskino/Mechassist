import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mechassist/app_navigator.dart';
import 'auth_storage.dart';

/// Interprète les payloads FCM (`type`, `request_id`) et navigue sans dépendre du contexte courant.
class NotificationNavigation {
  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    final raw = <String, dynamic>{};
    message.data.forEach((k, v) {
      raw[k] = v;
    });
    await handleDataMap(raw);
  }

  static Future<void> handlePayloadString(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        await handleDataMap(Map<String, String>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
        ));
      }
    } catch (_) {}
  }

  static Future<void> handleDataMap(Map<String, dynamic> data) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) return;

    final type = data['type']?.toString() ?? '';
    final rid = int.tryParse(data['request_id']?.toString() ?? '');
    final role = await AuthStorage.getRole();

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    if (kDebugMode) {
      debugPrint('NotificationNavigation type=$type request_id=$rid role=$role');
    }

    void goDashboard({int clientTab = 0}) {
      if (role == 'mecanicien') {
        nav.pushNamedAndRemoveUntil('/mecanicien', (r) => false);
      } else {
        nav.pushNamedAndRemoveUntil(
          '/client',
          (r) => false,
          arguments: {'tab': clientTab},
        );
      }
    }

    switch (type) {
      case 'chat_message':
        if (rid == null) {
          goDashboard();
          return;
        }
        goDashboard(clientTab: 1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appNavigatorKey.currentState?.pushNamed(
            '/intervention-chat',
            arguments: rid,
          );
        });
        return;
      case 'request_created':
        goDashboard();
        return;
      case 'request_accepted':
      case 'request_declined':
      case 'mechanic_marked_complete':
      case 'request_cancelled':
        goDashboard(clientTab: 1);
        return;
      case 'request_completed':
      case 'mechanic_rated':
        goDashboard(clientTab: 2);
        return;
      default:
        goDashboard();
    }
  }
}
