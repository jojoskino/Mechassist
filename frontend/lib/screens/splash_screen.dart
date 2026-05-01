import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/push_service.dart';

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
    if (!mounted) return;
    final isLogged = await AuthStorage.isLoggedIn();
    if (!mounted) return;

    if (isLogged) {
      final token = await AuthStorage.getToken();
      if (token != null) {
        final me = await ApiService.getMe(token);
        final ok = (me['status'] as int?) != null && (me['status'] as int) >= 200 && (me['status'] as int) < 300;
        if (!ok) {
          await AuthStorage.clear();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/welcome');
          return;
        }
        final fcm = await PushService.initAndGetToken();
        if (fcm != null && fcm.isNotEmpty) {
          await ApiService.updatePushToken(token, fcm);
        }
      }
      final role = await AuthStorage.getRole();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        role == 'mecanicien' ? '/mecanicien' : '/client',
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F4C75),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.miscellaneous_services_rounded, color: Color(0xFF0F4C75), size: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'MechAssist',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}