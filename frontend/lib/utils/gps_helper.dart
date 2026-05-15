import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Récupération GPS robuste : dernière position connue puis précision haute / basse.
class GpsHelper {
  static Future<bool> ensurePermission() async {
    if (!kIsWeb) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return false;
      }
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<Position?> bestPosition({
    Duration timeout = const Duration(seconds: 18),
  }) async {
    if (!await ensurePermission()) {
      return null;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return last;
      }
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(timeout);
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  static Future<void> openSettingsIfNeeded() async {
    if (kIsWeb) return;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.deniedForever || p == LocationPermission.denied) {
      await Geolocator.openAppSettings();
    }
  }
}
