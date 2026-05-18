import 'package:flutter/foundation.dart';

import 'profile_avatar_session.dart';

/// Signale aux écrans (dashboards, chat…) que les données profil / avatars ont peut‑être changé.
/// Rafraîchir depuis l’API suffit pour que tout le monde voie les nouvelles photos.
class ProfileSignals extends ChangeNotifier {
  ProfileSignals._();
  static final ProfileSignals instance = ProfileSignals._();

  /// Incrémenté à chaque action utilisateur qui doit pousser un refresh réseau.
  int generation = 0;

  String? lastAvatarUrl;

  void notifyProfilesChanged({String? avatarUrl}) {
    generation++;
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      lastAvatarUrl = avatarUrl.trim();
      ProfileAvatarSession.bump(url: lastAvatarUrl);
    } else {
      ProfileAvatarSession.bump();
    }
    notifyListeners();
  }
}
