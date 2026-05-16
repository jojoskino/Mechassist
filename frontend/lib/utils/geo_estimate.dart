import 'dart:math' as math;

/// Distance en km (formule haversine).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// Estimation temps de trajet (ville) à [avgSpeedKmh] km/h.
Duration estimateDriveDuration(double distanceKm, {double avgSpeedKmh = 32}) {
  if (distanceKm <= 0 || avgSpeedKmh <= 0) return Duration.zero;
  final hours = distanceKm / avgSpeedKmh;
  return Duration(minutes: (hours * 60).ceil().clamp(1, 999));
}

String formatEta(Duration d) {
  if (d.inHours >= 1) {
    final m = d.inMinutes % 60;
    return m > 0 ? '${d.inHours} h $m min' : '${d.inHours} h';
  }
  return '${d.inMinutes} min';
}
