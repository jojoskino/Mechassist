import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/auth_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color accent = Color(0xFF0F4C75);
  static const Color linkOrange = Color(0xFFE67E22);

  bool get _showPhoneHint =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Bienvenue',
      subtitle: 'Trouve un mécanicien près de toi, en temps réel.',
      showBack: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showPhoneHint) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Téléphone sur le Wi‑Fi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Sur le PC : php artisan serve --host=0.0.0.0 --port=8000\n'
                        '2. Windows : ouvre le pare-feu (script scripts/open-firewall-laravel-8000.ps1 en PowerShell administrateur)\n'
                        '3. Ici : Aide → URL http://IP_DU_PC:8000 (IPv4 dans ipconfig, sans /api)\n'
                        '4. Test navigateur sur le PC : http://127.0.0.1:8000 — pas http://0.0.0.0:8000 (invalide).',
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/help'),
                        icon: const Icon(Icons.settings_ethernet, size: 20),
                        label: const Text('Configurer l’URL du PC'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Icon(Icons.handyman_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Mise en relation client — mécanicien',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: accent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Créer un compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: linkOrange),
              onPressed: () => Navigator.pushNamed(context, '/help'),
              child: const Text('Aide — URL du serveur (téléphone / Wi‑Fi)'),
            ),
          ],
        ),
      ),
    );
  }
}
