import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  bool loading = false;

  static const Color accent = Color(0xFF0F4C75);
  static const Color linkOrange = Color(0xFFE67E22);

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique ton adresse e-mail.')),
      );
      return;
    }
    setState(() => loading = true);
    final res = await ApiService.forgotPassword(email);
    if (!mounted) return;
    setState(() => loading = false);

    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (res['message']?.toString() ?? 'Si un compte existe, un e-mail a été envoyé.')
              : (res['message']?.toString() ?? 'Impossible d’envoyer l’e-mail.'),
        ),
        backgroundColor: ok ? null : Colors.red.shade800,
      ),
    );
    if (ok) {
      Navigator.pushNamed(
        context,
        '/reset-password',
        arguments: {'email': email},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Mot de passe oublié',
      subtitle: 'Nous t’enverrons un lien ou un code par e-mail (selon la config du serveur).',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'E-mail du compte',
              prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.black45, size: 22),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Envoyer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: linkOrange),
            onPressed: () => Navigator.pushNamed(
              context,
              '/reset-password',
              arguments: {'email': emailCtrl.text.trim()},
            ),
            child: const Text('J’ai déjà un code (e-mail)'),
          ),
        ],
      ),
    );
  }
}
