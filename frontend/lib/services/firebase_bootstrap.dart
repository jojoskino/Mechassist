import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Initialise Firebase uniquement quand une config existe pour la plateforme
/// (évite un crash au démarrage sur Windows/Web/iOS tant que FlutterFire n’est pas configuré).
class FirebaseBootstrap {
  static bool initialized = false;

  static Future<void> init() async {
    if (initialized || kIsWeb) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      initialized = true;
    } catch (e, st) {
      assert(() {
        debugPrint('Firebase init ignorée: $e');
        debugPrint('$st');
        return true;
      }());
    }
  }
}
