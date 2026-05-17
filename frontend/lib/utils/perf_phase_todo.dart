// PERF: Phase suivante (hors Quick Wins) — ne pas implémenter ici.
//
// - Riverpod / Bloc pour isoler l’état dashboard et chat
// - cached_network_image + resize WebP côté API
// - PostGIS + index SQL (backend)
// - deferred imports (emoji_picker, maps) pour Flutter Web
// - Une seule stack cartographique (Google OU flutter_map)
// - WebSocket / Firestore client pour remplacer le polling chat
// - flutter build web --analyze-size + choix renderer (html vs canvaskit)
// - Android release: minifyEnabled + shrinkResources
