/// Indique si un utilisateur est actuellement connecté / joignable (activité < 5 min).
bool userIsOnline(Map<String, dynamic>? user) {
  if (user == null) return false;
  final explicit = user['is_online'];
  if (explicit is bool) return explicit;
  if (explicit == 1 || explicit?.toString() == '1' || explicit?.toString() == 'true') {
    return true;
  }
  if (explicit == false || explicit == 0 || explicit?.toString() == '0') {
    return false;
  }
  final available = user['is_available'];
  if (available == false || available == 0) return false;
  final seenRaw = user['last_seen_at']?.toString() ?? user['last_location_at']?.toString();
  if (seenRaw == null || seenRaw.length < 16) return false;
  try {
    final seen = DateTime.parse(seenRaw);
    return DateTime.now().difference(seen) <= const Duration(minutes: 5);
  } catch (_) {
    return false;
  }
}
