/// Filtre texte local (insensible à la casse) sur plusieurs champs.
bool matchesListSearch(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return true;
  }
  for (final raw in fields) {
    final s = raw?.trim().toLowerCase() ?? '';
    if (s.isNotEmpty && s.contains(q)) {
      return true;
    }
  }
  return false;
}
