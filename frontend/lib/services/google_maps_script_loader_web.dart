import 'dart:async';
import 'dart:html' as html;

Future<void> loadGoogleMapsScript(String apiKey) async {
  if (apiKey.isEmpty) {
    return;
  }
  if (html.document.querySelector('script[data-mechassist-gmaps="1"]') != null) {
    return;
  }
  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..setAttribute('data-mechassist-gmaps', '1')
    ..async = true
    ..defer = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(apiKey)}';
  script.onLoad.listen((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Chargement Google Maps impossible.'));
    }
  });
  html.document.head!.append(script);
  return completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw TimeoutException('Google Maps SDK'),
  );
}
