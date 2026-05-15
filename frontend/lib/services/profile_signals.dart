import 'package:flutter/foundation.dart';

/// Signale aux écrans (dashboards, chat…) que les données profil / avatars ont peut‑être changé.
/// Rafraîchir depuis l’API suffit pour que tout le monde voie les nouvelles photos.
class ProfileSignals extends ChangeNotifier {
  ProfileSignals._();
  static final ProfileSignals instance = ProfileSignals._();

  /// Incrémenté à chaque action utilisateur qui doit pousser un refresh réseau.
  int generation = 0;

  void notifyProfilesChanged() {
    generation++;
    notifyListeners();
  }
}
