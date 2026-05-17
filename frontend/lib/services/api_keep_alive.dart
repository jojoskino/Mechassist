import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api_service.dart';

/// Garde Render éveillé (plan gratuit ~15 min d’inactivité).
class ApiKeepAlive with WidgetsBindingObserver {
  ApiKeepAlive._();
  static final ApiKeepAlive instance = ApiKeepAlive._();

  Timer? _timer;
  bool _foreground = true;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _schedule();
    unawaited(ApiService.warmServer(wait: false));
  }

  void _schedule() {
    _timer?.cancel();
    if (!_foreground) return;
    final interval = kIsWeb ? const Duration(seconds: 90) : const Duration(minutes: 2);
    _timer = Timer.periodic(interval, (_) {
      unawaited(ApiService.warmServer(wait: false));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(ApiService.warmServer(wait: false));
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }
}
