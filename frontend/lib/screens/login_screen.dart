import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import '../services/auth_storage.dart';

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

  static const Color primary = Color(0xFF1A1A2E);
  static const Color accent  = Color(0xFFE94560);


  Future<void> _login() async {
    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack('Remplis tous les champs', isError: true);
      return;
    }
    setState(() => isLoading = true);
    final res = await ApiService.login(emailCtrl.text.trim(), passwordCtrl.text);
    setState(() => isLoading = false);

    if (res['status'] == 200 && res['token'] != null) {
      final user = res['user'] as Map<String, dynamic>? ?? {};

      await AuthStorage.save(
        token: res['token'].toString(),
        role:  user['role']?.toString() ?? 'client',
        name:  user['name']?.toString() ?? '',
      );

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
    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              // Logo / Icône
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.build_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 30),
              const Text('Bon retour 👋',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Connexion',
                style: TextStyle(color: Colors.white,
                    fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              _buildLabel('Adresse email'),
              _buildField(emailCtrl, Icons.email_outlined,
                  hint: 'exemple@mail.com',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),

              _buildLabel('Mot de passe'),
              _buildField(passwordCtrl, Icons.lock_outline,
                  hint: '••••••••',
                  obscure: obscure,
                  suffix: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white38, size: 20),
                    onPressed: () => setState(() => obscure = !obscure),
                  )),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Se connecter',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: RichText(text: const TextSpan(
                    text: "Pas encore de compte ? ",
                    style: TextStyle(color: Colors.white54),
                    children: [TextSpan(text: 'Créer un compte',
                        style: TextStyle(color: Color(0xFFE94560),
                            fontWeight: FontWeight.w600))],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(color: Colors.white70,
            fontSize: 13, fontWeight: FontWeight.w500)),
  );

  Widget _buildField(TextEditingController ctrl, IconData icon,
      {String hint = '', bool obscure = false,
       TextInputType? keyboardType, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE94560), width: 1.5)),
      ),
    );
  }
}