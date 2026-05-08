import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';

/// Récupère un id_token Google pour l’API Laravel (audience = client Web).
class GoogleSignInService {
  static String? _cachedServerClientId;

  static Future<String?> _serverClientId() async {
    if (_cachedServerClientId != null && _cachedServerClientId!.isNotEmpty) {
      return _cachedServerClientId;
    }
    final cfg = await ApiService.getClientConfig();
    final id = cfg['google_client_id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }
    _cachedServerClientId = id;
    return id;
  }

  /// Retourne l’id_token ou null si annulé / erreur.
  static Future<String?> signInForIdToken() async {
    final serverId = await _serverClientId();
    if (serverId == null || serverId.isEmpty) {
      throw StateError(
        'GOOGLE_CLIENT_ID manquant sur le serveur. Ajoute-le dans backend/.env et GET /api/client-config.',
      );
    }

    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: serverId,
      clientId: kIsWeb ? serverId : null,
    );

    final account = await googleSignIn.signIn();
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

  static void clearCachedClientId() {
    _cachedServerClientId = null;
  }
}
