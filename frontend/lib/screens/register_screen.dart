import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  static const Color primary = Color(0xFF1A1A2E);
  static const Color accent  = Color(0xFFE94560);

  Future<void> _register() async {
    if ([nameCtrl, emailCtrl, phoneCtrl, passwordCtrl]
        .any((c) => c.text.isEmpty)) {
      _showSnack('Remplis tous les champs', isError: true);
      return;
    }
    setState(() => isLoading = true);
    final res = await ApiService.register(
      nameCtrl.text.trim(), emailCtrl.text.trim(),
      phoneCtrl.text.trim(), passwordCtrl.text, role,
    );
    setState(() => isLoading = false);

    if (res['status'] == 201 || res['token'] != null) {
      _showSnack('Compte créé avec succès ✓');
      Future.delayed(const Duration(seconds: 1),
          () => Navigator.pop(context));
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
    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Créer un compte',
              style: TextStyle(color: Colors.white,
                  fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Rejoins MechAssist dès maintenant',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 32),

            _buildLabel('Nom complet'),
            _buildField(nameCtrl, Icons.person_outline, hint: 'Jean Dupont'),
            const SizedBox(height: 16),

            _buildLabel('Email'),
            _buildField(emailCtrl, Icons.email_outlined,
                hint: 'exemple@mail.com',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),

            _buildLabel('Téléphone'),
            _buildField(phoneCtrl, Icons.phone_outlined,
                hint: '+228 90 00 00 00',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),

            _buildLabel('Mot de passe'),
            _buildField(passwordCtrl, Icons.lock_outline,
                hint: '••••••••', obscure: obscure,
                suffix: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38, size: 20),
                  onPressed: () => setState(() => obscure = !obscure),
                )),
            const SizedBox(height: 16),

            _buildLabel('Type de compte'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: role,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38),
                  items: const [
                    DropdownMenuItem(value: 'client',
                        child: Text('🧑 Client')),
                    DropdownMenuItem(value: 'mecanicien',
                        child: Text('🔧 Mécanicien')),
                  ],
                  onChanged: (val) => setState(() => role = val!),
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Créer mon compte',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),
          ],
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