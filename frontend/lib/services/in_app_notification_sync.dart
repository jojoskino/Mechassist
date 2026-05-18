import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'app_notification_hub.dart';
import 'auth_storage.dart';

/// Synchronise le panneau notifications via l'API (indispensable sur Web sans FCM).
class InAppNotificationSync {
  InAppNotificationSync._();
  static final InAppNotificationSync instance = InAppNotificationSync._();

  Timer? _timer;
  bool _busy = false;

  static const _pollInterval = Duration(seconds: 4);

  Future<void> start() async {
    await AppNotificationHub.instance.ensureLoaded();
    _timer?.cancel();
    await _tick();
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _tick();

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) return;
      final res = await ApiService.listNotifications(token);
      final st = res['status'] as int?;
      if (st == null || st < 200 || st >= 300) return;
      final data = res['data'];
      if (data is List) {
        AppNotificationHub.instance.syncUnreadFromApi(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('InAppNotificationSync: $e');
      }
    } finally {
      _busy = false;
    }
  }
}
