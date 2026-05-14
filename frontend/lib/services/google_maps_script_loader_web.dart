import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

Future<void> loadGoogleMapsScript(String apiKey) async {
  if (apiKey.isEmpty) {
    return;
  }
  if (document.querySelector('script[data-mechassist-gmaps="1"]') != null) {
    return;
  }
  final completer = Completer<void>();
  final script = document.createElement('script') as HTMLScriptElement;
  script.setAttribute('data-mechassist-gmaps', '1');
  script.async = true;
  script.defer = true;
  script.src =
      'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(apiKey)}';

  void onLoad(Event _) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void onError(Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Chargement Google Maps impossible.'));
    }
  }

  script.addEventListener('load', onLoad.toJS);
  script.addEventListener('error', onError.toJS);
  document.head!.appendChild(script);
  await completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw TimeoutException('Google Maps SDK'),
  );
}
