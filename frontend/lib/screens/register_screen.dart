import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/push_sync.dart';
import '../widgets/auth_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final passwordConfirmCtrl = TextEditingController();
  final specialtyCtrl = TextEditingController();
  String role = 'client';
  bool isLoading = false;
  bool obscure = true;
  bool obscureConfirm = true;

  static const Color accent = Color(0xFF0F4C75);
  static const Color linkOrange = Color(0xFFE67E22);

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passwordCtrl.dispose();
    passwordConfirmCtrl.dispose();
    specialtyCtrl.dispose();
    super.dispose();
  }

  /// FCM peut prendre plusieurs secondes : ne bloque pas l’auth ; le tableau de bord rappelle aussi `updatePushToken`.
  void _syncPushTokenInBackground(String apiToken) {
    Future<void>.microtask(() => PushSync.syncToken());
  }

  Future<void> _register() async {
    if ([nameCtrl, emailCtrl, phoneCtrl, passwordCtrl, passwordConfirmCtrl].any((c) => c.text.isEmpty)) {
      _showSnack('Remplis tous les champs', isError: true);
      return;
    }
    if (passwordCtrl.text != passwordConfirmCtrl.text) {
      _showSnack('Les mots de passe ne correspondent pas.', isError: true);
      return;
    }
    if (passwordCtrl.text.length < 6) {
      _showSnack('Le mot de passe doit contenir au moins 6 caractères.', isError: true);
      return;
    }
    setState(() => isLoading = true);
    unawaited(ApiService.warmServer(wait: false));
    final res = await ApiService.register(
      nameCtrl.text.trim(),
      emailCtrl.text.trim(),
      phoneCtrl.text.trim(),
      passwordCtrl.text,
      passwordConfirmCtrl.text,
      role,
      null,
      mechanicSpecialty: role == 'mecanicien' ? specialtyCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => isLoading = false);

    if (res['status'] == 201 && res['token'] != null) {
      final user = res['user'] as Map<String, dynamic>? ?? {};
      final apiToken = res['token'].toString();
      await AuthStorage.save(
        token: apiToken,
        role: user['role']?.toString() ?? role,
        name: user['name']?.toString() ?? nameCtrl.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Compte créé avec succès');
      Navigator.pushReplacementNamed(
        context,
        (user['role']?.toString() ?? role) == 'mecanicien' ? '/mecanicien' : '/client',
      );
      _syncPushTokenInBackground(apiToken);
    } else {
      final errors = res['errors'];
      var msg = res['message']?.toString() ?? 'Erreur inconnue';
      if (errors is Map) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          msg = first.first.toString();
        }
      }
      _showSnack(msg, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? accent : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Créer un compte',
      subtitle: 'Rejoins MechAssist en quelques étapes.',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(nameCtrl, Icons.person_outline_rounded, hint: 'Nom'),
          const SizedBox(height: 16),
          _buildField(
            emailCtrl,
            Icons.mail_outline_rounded,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildField(
            passwordCtrl,
            Icons.lock_outline_rounded,
            hint: 'Mot de passe',
            obscure: obscure,
            suffix: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            passwordConfirmCtrl,
            Icons.lock_outline_rounded,
            hint: 'Confirmer le mot de passe',
            obscure: obscureConfirm,
            suffix: IconButton(
              icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            phoneCtrl,
            Icons.phone_outlined,
            hint: 'Téléphone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: role,
            items: const [
              DropdownMenuItem(value: 'client', child: Text('Client')),
              DropdownMenuItem(value: 'mecanicien', child: Text('Mécanicien')),
            ],
            onChanged: (val) => setState(() => role = val ?? 'client'),
            decoration: const InputDecoration(
              labelText: 'Type de compte',
              prefixIcon: Icon(Icons.badge_outlined, color: Colors.black45),
            ),
          ),
          if (role == 'mecanicien') ...[
            const SizedBox(height: 16),
            _buildField(
              specialtyCtrl,
              Icons.build_outlined,
              hint: 'Spécialités (ex. moteur, batterie…)',
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Créer le compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                'Vous avez déjà un compte ? ',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: linkOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                child: const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    IconData icon, {
    String hint = '',
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black45, size: 22),
        suffixIcon: suffix,
      ),
    );
  }
}
