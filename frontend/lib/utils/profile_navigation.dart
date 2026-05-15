/// Applique le retour de [ProfileScreen] sur l’état du tableau de bord.
class ProfileNavigationResult {
  ProfileNavigationResult({this.avatarUrl, this.cacheEpoch, this.updated = false});

  final String? avatarUrl;
  final int? cacheEpoch;
  final bool updated;

  static ProfileNavigationResult? fromDynamic(dynamic result) {
    if (result is Map) {
      return ProfileNavigationResult(
        avatarUrl: result['avatar_url']?.toString(),
        cacheEpoch: result['cache_epoch'] is int
            ? result['cache_epoch'] as int
            : int.tryParse(result['cache_epoch']?.toString() ?? ''),
        updated: result['updated'] == true,
      );
    }
    if (result == true) {
      return ProfileNavigationResult(updated: true);
    }
    return null;
  }
}
