import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/profile_signals.dart';
import '../services/push_preferences.dart';
import '../services/push_sync.dart';
import '../theme/feu_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/mechassist_section_card.dart';

/// Compte connecté : photo, nom, téléphone, spécialité et disponibilité (mécano).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _loadError;
  String _role = 'client';
  String _email = '';
  String? _avatarUrl;
  Uint8List? _localAvatarBytes;
  int _avatarCacheEpoch = 0;
  bool _profileDirty = false;
  bool _mechanicAvailable = false;
  bool _pushEnabled = true;

  Map<String, dynamic> _popPayload() => {
        'updated': _profileDirty,
        'avatar_url': _avatarUrl,
        'cache_epoch': _avatarCacheEpoch,
      };

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
    _avatarUrl = res['avatar_url']?.toString();
    _avatarCacheEpoch = DateTime.now().millisecondsSinceEpoch;
    final av = res['is_available'];
    _mechanicAvailable = av is bool ? av : av == 1 || av?.toString() == '1';
    _pushEnabled = await PushPreferences.isEnabled();
    setState(() => _loading = false);
  }

  Future<void> _setPushEnabled(bool enabled) async {
    setState(() => _pushEnabled = enabled);
    await PushPreferences.setEnabled(enabled);
    if (!enabled) {
      await PushSync.syncToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications push désactivées')),
      );
      return;
    }
    final ok = await PushSync.syncToken();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Notifications push activées')),
      );
    } else {
      setState(() => _pushEnabled = false);
      await PushPreferences.setEnabled(false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’activer les notifications. Autorisez-les dans les paramètres Android '
            'et vérifiez que l’app est installée sur un téléphone (pas le navigateur).',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final x = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 88);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _localAvatarBytes = bytes;
      _uploadingPhoto = true;
    });
    final name = x.name.isNotEmpty ? x.name : 'avatar.jpg';
    final res = await ApiService.uploadProfileAvatar(token, bytes, name);
    if (!mounted) return;
    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    if (!ok) {
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Photo impossible')),
      );
      return;
    }
    setState(() {
      _uploadingPhoto = false;
      _avatarUrl = res['avatar_url']?.toString();
      _avatarCacheEpoch = DateTime.now().millisecondsSinceEpoch;
      _profileDirty = true;
    });
    ProfileSignals.instance.notifyProfilesChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo de profil mise à jour.')),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Galerie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Appareil photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editField(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) async {
    final local = TextEditingController(text: ctrl.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: local,
          keyboardType: keyboard,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(border: const OutlineInputBorder(), labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      ctrl.text = local.text;
      setState(() {});
    }
    local.dispose();
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
    setState(() => _profileDirty = true);
    ProfileSignals.instance.notifyProfilesChanged();
    Navigator.pop(context, _popPayload());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_popPayload());
      },
      child: Scaffold(
      backgroundColor: FeuTheme.pageGrey,
      appBar: FeuTheme.fireAppBar(
        title: 'Paramètres & profil',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context, _popPayload()),
        ),
        automaticallyImplyLeading: false,
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          UserAvatar(
                            name: _nameCtrl.text.isEmpty ? 'M' : _nameCtrl.text,
                            avatarUrl: _avatarUrl,
                            memoryBytes: _localAvatarBytes,
                            cacheEpoch: _avatarCacheEpoch,
                            radius: 52,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: FeuTheme.deepBlue,
                              shape: const CircleBorder(),
                              child: IconButton(
                                onPressed: _uploadingPhoto ? null : _showPhotoOptions,
                                icon: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _nameCtrl.text.isEmpty ? 'Profil' : _nameCtrl.text,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Utilisateur MechAssist',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const MechAssistSectionLabel('Informations personnelles'),
                    MechAssistSectionCard(
                      children: [
                        MechAssistSettingsTile(
                          title: 'Nom complet',
                          subtitle: _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text,
                          onTap: () => _editField(context, 'Nom', _nameCtrl),
                        ),
                        MechAssistSettingsTile(
                          title: 'Numéro de téléphone',
                          subtitle: _phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text,
                          onTap: () => _editField(context, 'Téléphone', _phoneCtrl, keyboard: TextInputType.phone),
                        ),
                        MechAssistSettingsTile(
                          title: 'E-mail',
                          subtitle: _email.isEmpty ? '—' : _email,
                        ),
                        if (_role == 'mecanicien')
                          MechAssistSettingsTile(
                            title: 'Spécialités',
                            subtitle: _specialtyCtrl.text.isEmpty ? '—' : _specialtyCtrl.text,
                            onTap: () => _editField(context, 'Spécialités', _specialtyCtrl, maxLines: 3),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const MechAssistSectionLabel('Préférences & sécurité'),
                    MechAssistSectionCard(
                      children: [
                        if (_role == 'mecanicien')
                          SwitchListTile(
                            secondary: const Icon(Icons.online_prediction_rounded, color: FeuTheme.deepBlue),
                            title: Text('Disponible', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Visible sur la carte'),
                            value: _mechanicAvailable,
                            activeTrackColor: FeuTheme.deepBlue,
                            onChanged: (v) => setState(() => _mechanicAvailable = v),
                          ),
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_outlined, color: FeuTheme.deepBlue),
                          title: Text('Notifications push', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Alertes demandes et messages'),
                          value: _pushEnabled,
                          activeTrackColor: FeuTheme.deepBlue,
                          onChanged: kIsWeb ? null : (v) => _setPushEnabled(v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: FeuTheme.deepBlue,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Enregistrer les modifications'),
                    ),
                  ],
                ),
      ),
    );
  }
}
