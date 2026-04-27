import 'package:flutter/material.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';

class DashboardMecanicien extends StatelessWidget {
  const DashboardMecanicien({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Espace Mécanicien', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final token = await AuthStorage.getToken();
              if (token != null) {
                await ApiService.logout(token);
              }
              await AuthStorage.clear();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Bienvenue Mécanicien 🔧',
            style: TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }
}