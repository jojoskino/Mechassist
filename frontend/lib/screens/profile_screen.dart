import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/feu_theme.dart';

/// Compte connecté : nom, téléphone, spécialité et disponibilité (mécano). Aplats, charte feu.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String _role = 'client';
  String _email = '';
  bool _mechanicAvailable = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _loading = false;
        _loadError = 'Session expirée.';
      });
      return;
    }
    final res = await ApiService.getMe(token);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      setState(() {
        _loading = false;
        _loadError = res['message']?.toString() ?? 'Impossible de charger le profil.';
      });
      return;
    }
    _role = res['role']?.toString() ?? 'client';
    _email = res['email']?.toString() ?? '';
    _nameCtrl.text = res['name']?.toString() ?? '';
    _phoneCtrl.text = res['phone']?.toString() ?? '';
    _specialtyCtrl.text = res['mechanic_specialty']?.toString() ?? '';
    final av = res['is_available'];
    _mechanicAvailable = av is bool ? av : av == 1 || av?.toString() == '1';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom ne peut pas être vide.')),
      );
      return;
    }
    final token = await AuthStorage.getToken();
    if (token == null || !mounted) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    };
    if (_role == 'mecanicien') {
      body['mechanic_specialty'] = _specialtyCtrl.text.trim();
      body['is_available'] = _mechanicAvailable;
    }
    final res = await ApiService.patchProfile(token, body);
    if (!mounted) return;
    setState(() => _saving = false);
    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Enregistrement impossible')),
      );
      return;
    }
    final name = res['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      await AuthStorage.updateName(name);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil enregistré.')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeuTheme.paper,
      appBar: FeuTheme.fireAppBar(
        title: 'Mon profil',
        actions: [
          if (!_loading && _loadError == null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FeuTheme.ember))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_loadError!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Text(
                      'Compte',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FeuTheme.charcoal.withValues(alpha: 0.55),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.14)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('E-mail', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Text(_email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(
                              'L’e-mail ne peut pas être modifié ici.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Informations',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FeuTheme.charcoal.withValues(alpha: 0.55),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.14)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom affiché',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                                border: OutlineInputBorder(),
                                hintText: '+33…',
                              ),
                            ),
                            if (_role == 'mecanicien') ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: _specialtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Spécialités (mécanicien)',
                                  border: OutlineInputBorder(),
                                  hintText: 'Ex. moteur, batterie…',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Visible comme disponible'),
                                subtitle: const Text('Les clients te voient sur la carte quand c’est activé.'),
                                value: _mechanicAvailable,
                                onChanged: (v) => setState(() => _mechanicAvailable = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: FeuTheme.deepBlue,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enregistrer les modifications'),
                    ),
                  ],
                ),
    );
  }
}
