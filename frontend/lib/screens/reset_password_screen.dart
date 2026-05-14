import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/auth_shell.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController emailCtrl;
  final tokenCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final password2Ctrl = TextEditingController();
  bool obscure1 = true;
  bool obscure2 = true;
  bool loading = false;

  static const Color accent = Color(0xFF0F4C75);

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController(text: widget.initialEmail?.trim() ?? '');
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    tokenCtrl.dispose();
    passwordCtrl.dispose();
    password2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    final token = tokenCtrl.text.trim();
    final p1 = passwordCtrl.text;
    final p2 = password2Ctrl.text;
    if (email.isEmpty || token.isEmpty || p1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplis e-mail, code et nouveau mot de passe.')),
      );
      return;
    }
    if (p1.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit faire au moins 6 caractères.')),
      );
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les deux mots de passe ne correspondent pas.')),
      );
      return;
    }
    setState(() => loading = true);
    final res = await ApiService.resetPassword(
      email: email,
      token: token,
      password: p1,
      passwordConfirmation: p2,
    );
    if (!mounted) return;
    setState(() => loading = false);

    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? (res['message']?.toString() ?? 'Mot de passe mis à jour.') : (res['message']?.toString() ?? 'Échec.'),
        ),
        backgroundColor: ok ? null : Colors.red.shade800,
      ),
    );
    if (ok && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Nouveau mot de passe',
      subtitle:
          'Colle le jeton reçu par e-mail (souvent dans l’URL du lien sous forme de longue chaîne).',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'E-mail',
              prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.black45, size: 22),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tokenCtrl,
            decoration: const InputDecoration(
              hintText: 'Jeton / code de réinitialisation',
              prefixIcon: Icon(Icons.vpn_key_outlined, color: Colors.black45, size: 22),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordCtrl,
            obscureText: obscure1,
            decoration: InputDecoration(
              hintText: 'Nouveau mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.black45, size: 22),
              suffixIcon: IconButton(
                icon: Icon(obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => obscure1 = !obscure1),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password2Ctrl,
            obscureText: obscure2,
            decoration: InputDecoration(
              hintText: 'Confirmer le mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.black45, size: 22),
              suffixIcon: IconButton(
                icon: Icon(obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => obscure2 = !obscure2),
              ),
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
                  : const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
