import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import '../services/auth_storage.dart';
import '../services/push_service.dart';
import '../widgets/auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool isLoading = false;
  bool obscure = true;

  static const Color accent = Color(0xFF0F4C75);

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }


  Future<void> _login() async {
    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack('Remplis tous les champs', isError: true);
      return;
    }
    setState(() => isLoading = true);
    final fcmToken = await PushService.initAndGetToken();
    final res = await ApiService.login(emailCtrl.text.trim(), passwordCtrl.text, fcmToken);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (res['status'] == 200 && res['token'] != null) {
      final user = res['user'] as Map<String, dynamic>? ?? {};

      await AuthStorage.save(
        token: res['token'].toString(),
        role:  user['role']?.toString() ?? 'client',
        name:  user['name']?.toString() ?? '',
      );
      await ApiService.updatePushToken(res['token'].toString(), fcmToken);
      if (!mounted) return;

      _navigateByRole(user['role']?.toString() ?? 'client');
    } else {
      _showSnack(res['message']?.toString() ?? 'Identifiants incorrects', isError: true);
    }
  }


  void _navigateByRole(String role) {
    Navigator.pushReplacementNamed(
      context,
      role == 'mecanicien' ? '/mecanicien' : '/client',
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? accent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Connexion',
      showBack: true,
      child: Column(
        children: [
          _buildField(
            emailCtrl,
            Icons.mail_outline_rounded,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size.fromHeight(52),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Se connecter'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Vous n'avez pas de compte ? ", style: TextStyle(color: Colors.black54)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Creer un compte', style: TextStyle(color: Color(0xFFE67E22))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, IconData icon,
      {String hint = '', bool obscure = false,
       TextInputType? keyboardType, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black54, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
      ),
    );
  }
}