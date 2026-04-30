import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseBootstrap {
  static bool initialized = false;

  static Future<void> init() async {
    if (initialized || kIsWeb) {
      return;
    }
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    initialized = true;
  }
}
