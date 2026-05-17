import 'package:flutter/foundation.dart';

/// Signal partagé client ↔ mécano : rafraîchir listes après action ou notification push.
class LiveSync extends ChangeNotifier {
  LiveSync._();
  static final LiveSync instance = LiveSync._();

  int generation = 0;

  void pulse() {
    generation++;
    notifyListeners();
  }
}
