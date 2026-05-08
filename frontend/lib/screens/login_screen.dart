import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_service.dart';
import '../widgets/auth_shell.dart';
import 'register_screen.dart';

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
  bool rememberMe = false;

  static const Color accent = Color(0xFF0F4C75);
  static const Color linkOrange = Color(0xFFE67E22);

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    // Ne plus conserver le mot de passe (anciennes installs) : on ne garde que l’email.
    await prefs.remove('mechassist_saved_password');
    final saved = prefs.getBool('mechassist_remember_me') ?? false;
    final em = prefs.getString('mechassist_saved_email');
    if (!mounted) return;
    setState(() {
      rememberMe = saved;
      if (em != null && em.isNotEmpty) {
        emailCtrl.text = em;
      }
    });
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _persistRemember() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mechassist_saved_password');
    if (rememberMe) {
      await prefs.setBool('mechassist_remember_me', true);
      await prefs.setString('mechassist_saved_email', emailCtrl.text.trim());
    } else {
      await prefs.remove('mechassist_remember_me');
      await prefs.remove('mechassist_saved_email');
    }
  }

  /// Après Google : enregistre l’email si « Se souvenir de moi » est coché (sans mot de passe).
  Future<void> _persistRememberEmailFromUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mechassist_saved_password');
    if (!rememberMe) {
      await prefs.remove('mechassist_remember_me');
      await prefs.remove('mechassist_saved_email');
      return;
    }
    final em = user['email']?.toString().trim() ?? '';
    if (em.isEmpty) return;
    await prefs.setBool('mechassist_remember_me', true);
    await prefs.setString('mechassist_saved_email', em);
  }

  Future<void> _googleLogin() async {
    setState(() => isLoading = true);
    try {
      final idToken = await GoogleSignInService.signInForIdToken();
      if (!mounted) return;
      if (idToken == null) {
        setState(() => isLoading = false);
        return;
      }
      final fcmToken = await PushService.initAndGetToken();
      final res = await ApiService.googleLogin(idToken: idToken, fcmToken: fcmToken);
      if (!mounted) return;
      setState(() => isLoading = false);

      if (res['status'] == 200 && res['token'] != null) {
        final user = res['user'] as Map<String, dynamic>? ?? {};
        await _persistRememberEmailFromUser(user);
        await AuthStorage.save(
          token: res['token'].toString(),
          role: user['role']?.toString() ?? 'client',
          name: user['name']?.toString() ?? '',
        );
        await ApiService.updatePushToken(res['token'].toString(), fcmToken);
        if (!mounted) return;
        _navigateByRole(user['role']?.toString() ?? 'client');
      } else {
        _showSnack(res['message']?.toString() ?? 'Connexion Google impossible', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack(e.toString(), isError: true);
    }
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
      await _persistRemember();
      await AuthStorage.save(
        token: res['token'].toString(),
        role: user['role']?.toString() ?? 'client',
        name: user['name']?.toString() ?? '',
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
      backgroundColor: isError ? accent : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Connexion',
      subtitle: 'Accède à ton espace MechAssist.',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (v) => setState(() => rememberMe = v ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => rememberMe = !rememberMe),
                  child: const Text(
                    'Se souvenir de moi (email)',
                    style: TextStyle(fontSize: 15, color: Color(0xFF10324A)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _login,
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
                  : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                "Vous n'avez pas encore de compte ? ",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: linkOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Créer un compte', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: isLoading ? null : _googleLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10324A),
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: accent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Se connecter avec Google', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
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
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black45, size: 22),
        suffixIcon: suffix,
      ),
    );
  }
}
