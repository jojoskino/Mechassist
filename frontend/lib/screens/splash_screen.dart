import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_keep_alive.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/push_sync.dart';
import '../utils/gps_position_tracker.dart';
import 'welcome_screen.dart';
import '../widgets/mechassist_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Chargement…';
  bool _backendReady = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // PERF: Warm backend en arrière-plan — ne bloque pas la navigation (max 8 s).
    unawaited(_warmBackendInBackground());
    ApiKeepAlive.instance.warmOnAuthEntry();

    await Future<void>.delayed(const Duration(milliseconds: 80));
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

  Future<void> _warmBackendInBackground() async {
    if (mounted) {
      setState(() => _status = 'Connexion au serveur…');
    }
    final ok = await ApiService.ensureBackendReady(maxWait: perfSplashBackendMaxWait);
    if (!mounted) return;
    setState(() {
      _backendReady = ok;
      if (!ok) {
        _status = 'Serveur lent — vous pouvez continuer';
      } else {
        _status = 'Prêt';
      }
    });
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
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              if (!_backendReady && _status.contains('serveur'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'L’application s’ouvre pendant la connexion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
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
