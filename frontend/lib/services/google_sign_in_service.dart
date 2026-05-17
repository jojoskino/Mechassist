import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'client_config_cache.dart';

/// Récupère un id_token Google pour l’API Laravel (audience = client Web).
class GoogleSignInService {
  static String? _cachedServerClientId;
  static GoogleSignIn? _googleSignIn;

  static Future<String?> _serverClientId() async {
    if (_cachedServerClientId != null && _cachedServerClientId!.isNotEmpty) {
      return _cachedServerClientId;
    }
    final cfg = await ClientConfigCache.get();
    final status = cfg['status'];
    if (status is! int || status < 200 || status >= 300) {
      final msg = cfg['message']?.toString() ?? 'réponse serveur invalide';
      throw StateError(
        'Impossible de charger la config Google ($status): $msg. '
        'Vérifie que l’API tourne et que GOOGLE_CLIENT_ID est défini.',
      );
    }
    final id = cfg['google_client_id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError(
        'GOOGLE_CLIENT_ID manquant sur le serveur. Ajoute-le dans backend/.env et GET /api/client-config.',
      );
    }
    _cachedServerClientId = id;
    return id;
  }

  static Future<GoogleSignIn> _ensureClient() async {
    final serverId = await _serverClientId();
    if (serverId == null || serverId.isEmpty) {
      throw StateError('Client Google OAuth indisponible.');
    }
    _googleSignIn ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: serverId,
      clientId: kIsWeb ? serverId : null,
    );
    return _googleSignIn!;
  }

  /// Retourne l’id_token ou null si annulé / erreur.
  static Future<String?> signInForIdToken() async {
    final googleSignIn = await _ensureClient();

    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signInSilently();
    } catch (_) {
      account = null;
    }
    account ??= await googleSignIn.signIn();
    if (account == null) {
      return null;
    }

    final auth = await account.authentication;
    final token = auth.idToken;
    if (token == null || token.isEmpty) {
      throw StateError(
        'id_token vide. Vérifie la config OAuth (client Web + SHA-1 Android) et serverClientId.',
      );
    }
    return token;
  }

  /// À appeler à la déconnexion MechAssist pour pouvoir choisir un autre compte Google ensuite.
  static Future<void> signOut() async {
    final g = _googleSignIn;
    if (g == null) return;
    try {
      await g.signOut();
    } catch (_) {
      // Ignorer si aucune session Google locale.
    }
  }

  static void clearCachedClientId() {
    _cachedServerClientId = null;
    _googleSignIn = null;
  }
}
