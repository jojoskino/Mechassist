import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Prépare un numéro pour `tel:` : conserve un `+` initial, supprime espaces / tirets / points.
String? normalizePhoneForDial(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '+' && sb.isEmpty) {
      sb.write(ch);
      continue;
    }
    final code = ch.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) {
      sb.write(ch);
    }
  }
  final o = sb.toString();
  if (o.isEmpty || o == '+') return null;
  return o;
}

/// Ouvre le composeur téléphonique (`tel:`). Ne dépend pas de [canLaunchUrl] seul (souvent faux sur Android 11+ / iOS sans queries).
Future<void> launchTelDialer(BuildContext context, String? raw) async {
  final normalized = normalizePhoneForDial(raw);
  if (normalized == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numéro de téléphone indisponible ou invalide.')),
    );
    return;
  }
  final uri = Uri.parse('tel:$normalized');
  try {
    final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    var ok = await launchUrl(uri, mode: mode);
    if (!ok && !kIsWeb) {
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’ouvrir le composeur. Sur Android, vérifie qu’une app Téléphone est installée.',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appel impossible : $e')),
      );
    }
  }
}
