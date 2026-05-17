import 'package:flutter/widgets.dart';

import 'api_service.dart';

/// PERF: Plus de ping périodique — réveil uniquement au besoin (splash, login, reprise app).
class ApiKeepAlive with WidgetsBindingObserver {
  ApiKeepAlive._();
  static final ApiKeepAlive instance = ApiKeepAlive._();

  bool _attached = false;

  /// PERF: Enregistre l’observateur cycle de vie sans timer automatique.
  void start() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// PERF: Splash / login — warm non bloquant.
  void warmOnAuthEntry() {
    if (!ApiService.isServerWarm) {
      ApiService.warmServer(wait: false);
    }
  }

  /// PERF: Reprise app si le backend est froid.
  void warmIfCold() {
    if (!ApiService.isServerWarm) {
      ApiService.warmServer(wait: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      warmIfCold();
    }
  }

  void dispose() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }
}
