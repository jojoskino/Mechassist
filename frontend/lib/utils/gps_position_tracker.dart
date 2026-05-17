import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Coordonnées GPS pour la carte (ValueNotifier).
class GpsCoords {
  const GpsCoords(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// PERF: Paramètres GPS adaptés Web / mobile (évite Highest + distanceFilter 0).
LocationSettings perfLocationStreamSettings() {
  if (kIsWeb) {
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 30,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 12,
  );
}

/// PERF: Debounce 500 ms + seuil ~25 m — met à jour [position] sans setState global.
class GpsPositionTracker {
  GpsPositionTracker({this.significantMoveMeters = 25});

  final double significantMoveMeters;
  final ValueNotifier<GpsCoords?> position = ValueNotifier(null);

  Timer? _debounce;
  GpsCoords? _lastEmitted;

  /// PERF: Appelé à chaque tick du stream ; [onSignificant] pour API / logique métier.
  void handlePosition(
    Position pos, {
    required void Function(double lat, double lng) onSignificant,
  }) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final lat = pos.latitude;
      final lng = pos.longitude;
      if (!_shouldEmit(lat, lng)) return;
      final coords = GpsCoords(lat, lng);
      _lastEmitted = coords;
      position.value = coords;
      onSignificant(lat, lng);
    });
  }

  bool _shouldEmit(double lat, double lng) {
    final prev = _lastEmitted;
    if (prev == null) return true;
    final meters = Geolocator.distanceBetween(
      prev.latitude,
      prev.longitude,
      lat,
      lng,
    );
    return meters >= significantMoveMeters;
  }

  /// PERF: Première position (bootstrap) — toujours émise.
  void emitImmediate(double lat, double lng) {
    final coords = GpsCoords(lat, lng);
    _lastEmitted = coords;
    position.value = coords;
  }

  void dispose() {
    _debounce?.cancel();
    position.dispose();
  }
}

/// PERF: Intervalle minimum de polling dashboard (foreground).
const Duration perfDashboardPollInterval = Duration(seconds: 45);

/// PERF: Intervalle chat (écran visible).
const Duration perfChatPollInterval = Duration(seconds: 15);

/// PERF: Splash — attente max non bloquante du backend.
const Duration perfSplashBackendMaxWait = Duration(seconds: 3);
