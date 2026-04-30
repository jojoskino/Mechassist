import 'package:flutter/material.dart';
import '../widgets/auth_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Bienvenue',
      subtitle: 'Trouve un mecanicien rapidement.',
      child: Column(
        children: [
          const Icon(Icons.handyman_rounded, size: 84, color: Color(0xFF0F4C75)),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C75),
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Se connecter'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: Color(0xFF0F4C75)),
              ),
              child: const Text('Creer un compte'),
            ),
          ),
        ],
      ),
    );
  }
}