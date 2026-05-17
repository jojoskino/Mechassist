import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_storage.dart';

/// Aligne le rôle affiché avec celui du serveur (PostgreSQL / Sanctum).
class SessionRole {
  SessionRole._();

  static String? roleFromMe(Map<String, dynamic> me) {
    final st = me['status'] as int?;
    if (st == null || st < 200 || st >= 300) return null;
    final role = me['role']?.toString().trim().toLowerCase();
    if (role == null || role.isEmpty) return null;
    return role;
  }

  static Future<String?> fetchApiRole(String token, {bool force = false}) async {
    final me = await ApiService.getMe(token, force: force);
    return roleFromMe(me);
  }

  /// Sur l’écran client : vérifie que le jeton correspond bien à un compte `client`.
  static Future<bool> ensureClientOnDashboard(BuildContext context) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;

    final apiRole = await fetchApiRole(token, force: true);
    if (apiRole == null) return true;

    final session = await AuthStorage.getSessionFields();
    final name = session['name'] ?? '';

    if (apiRole == 'mecanicien') {
      await AuthStorage.save(token: token, role: 'mecanicien', name: name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce compte est enregistré comme mécanicien. Redirection vers l’espace mécanicien.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacementNamed(context, '/mecanicien');
      }
      return false;
    }

    if (apiRole == 'client' && session['role'] != 'client') {
      await AuthStorage.save(token: token, role: 'client', name: name);
    }
    return true;
  }

  /// Sur l’écran mécanicien : vérifie le rôle `mecanicien`.
  static Future<bool> ensureMechanicOnDashboard(BuildContext context) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;

    final apiRole = await fetchApiRole(token, force: true);
    if (apiRole == null) return true;

    final session = await AuthStorage.getSessionFields();
    final name = session['name'] ?? '';

    if (apiRole == 'client') {
      await AuthStorage.save(token: token, role: 'client', name: name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce compte est enregistré comme client. Redirection vers l’espace client.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacementNamed(context, '/client');
      }
      return false;
    }

    if (apiRole == 'mecanicien' && session['role'] != 'mecanicien') {
      await AuthStorage.save(token: token, role: 'mecanicien', name: name);
    }
    return true;
  }
}
