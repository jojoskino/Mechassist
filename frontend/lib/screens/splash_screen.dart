import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/push_sync.dart';
import 'welcome_screen.dart';
import '../widgets/mechassist_logo.dart';

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
    unawaited(ApiService.warmServer(wait: false));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    final session = await AuthStorage.getSessionFields();
    final token = session['token'];
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      final onboarded = await WelcomeScreen.isOnboardingComplete();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, onboarded ? '/login' : '/welcome');
      return;
    }

    // Session locale : le tableau de bord charge le profil (évite un getMe bloquant au démarrage).
    final role = session['role'] ?? 'client';
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      role == 'mecanicien' ? '/mecanicien' : '/client',
    );
    Future<void>.microtask(() => PushSync.syncToken());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F4C75),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MechAssistLogoBadge(size: 120, elevation: 6),
              const SizedBox(height: 28),
              const Text(
                'MechAssist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assistance mécanique à portée de main',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
