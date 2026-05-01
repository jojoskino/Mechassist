import 'package:flutter/material.dart';

import '../widgets/auth_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color accent = Color(0xFF0F4C75);
  static const Color linkOrange = Color(0xFFE67E22);

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Bienvenue',
      subtitle: 'Trouve un mécanicien près de toi, en temps réel.',
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aide : connecte-toi ou crée un compte pour commencer.')),
              );
            },
            child: const Text('Besoin d’aide ?'),
          ),
        ],
      ),
    );
  }
}
