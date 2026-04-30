import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/push_service.dart';
import '../widgets/auth_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl     = TextEditingController();
  final emailCtrl    = TextEditingController();
  final phoneCtrl    = TextEditingController();
  final passwordCtrl = TextEditingController();
  String role = 'client';
  bool isLoading = false;
  bool obscure = true;

  static const Color accent = Color(0xFF0F4C75);

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if ([nameCtrl, emailCtrl, phoneCtrl, passwordCtrl]
        .any((c) => c.text.isEmpty)) {
      _showSnack('Remplis tous les champs', isError: true);
      return;
    }
    setState(() => isLoading = true);
    final fcmToken = await PushService.initAndGetToken();
    final res = await ApiService.register(
      nameCtrl.text.trim(), emailCtrl.text.trim(),
      phoneCtrl.text.trim(), passwordCtrl.text, role, fcmToken,
    );
    if (!mounted) return;
    setState(() => isLoading = false);

    if (res['status'] == 201 && res['token'] != null) {
      final user = res['user'] as Map<String, dynamic>? ?? {};
      await AuthStorage.save(
        token: res['token'].toString(),
        role: user['role']?.toString() ?? role,
        name: user['name']?.toString() ?? nameCtrl.text.trim(),
      );
      await ApiService.updatePushToken(res['token'].toString(), fcmToken);
      if (!mounted) return;
      _showSnack('Compte créé avec succès ✓');
      Navigator.pushReplacementNamed(
        context,
        (user['role']?.toString() ?? role) == 'mecanicien'
            ? '/mecanicien'
            : '/client',
      );
    } else {
      final errors = res['errors'];
      String msg = res['message'] ?? 'Erreur inconnue';
      if (errors is Map) {
        msg = (errors.values.first as List).first.toString();
      }
      _showSnack(msg, isError: true);
    }
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
      title: 'Creer un compte',
      showBack: true,
      child: Column(
        children: [
          _buildField(nameCtrl, Icons.person_outline_rounded, hint: 'Nom'),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _buildField(
            phoneCtrl,
            Icons.phone_outlined,
            hint: 'Telephone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: role,
            items: const [
              DropdownMenuItem(value: 'client', child: Text('Client')),
              DropdownMenuItem(value: 'mecanicien', child: Text('Mecanicien')),
            ],
            onChanged: (val) => setState(() => role = val ?? 'client'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _register,
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
                  : const Text('Creer un compte'),
            ),
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