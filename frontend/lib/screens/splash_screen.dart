import 'package:flutter/material.dart';
import '../services/auth_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1)); // splash visuel
    final isLogged = await AuthStorage.isLoggedIn();
    if (!mounted) return;

    if (isLogged) {
      final role = await AuthStorage.getRole();
      Navigator.pushReplacementNamed(
        context,
        role == 'mecanicien' ? '/mecanicien' : '/client',
      );
    } else {
      Navigator.pushReplacementNamed(context, '/welcome'); // ← /welcome au lieu de /login
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_rounded, color: Color(0xFFE94560), size: 64),
            SizedBox(height: 16),
            Text('MechAssist',
              style: TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Chargement...', style: TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}