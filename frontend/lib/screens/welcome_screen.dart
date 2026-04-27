import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on,
                size: 80, color: Color(0xFF1E3A8A)),
            const SizedBox(height: 20),
            const Text(
              "Trouve un mécanicien proche rapidement",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text("Se connecter"),
            ),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text("Créer un compte"),
            ),
          ],
        ),
      ),
    );
  }
}