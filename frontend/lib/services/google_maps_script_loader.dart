import 'package:flutter/foundation.dart';

import 'google_maps_script_loader_stub.dart'
    if (dart.library.html) 'google_maps_script_loader_web.dart' as impl;

/// Charge le SDK JS Google Maps (Web uniquement ; no-op ailleurs).
Future<void> loadGoogleMapsScript(String apiKey) async {
  if (!kIsWeb) {
    return;
  }
  return impl.loadGoogleMapsScript(apiKey);
}
