import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
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
  String? _loadWarning;
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
    _loadFromSession();
    _load();
  }

  Future<void> _loadFromSession() async {
    final fields = await AuthStorage.getSessionFields();
    if (!mounted) return;
    final name = fields['name']?.toString();
    if (name != null && name.isNotEmpty) {
      _nameCtrl.text = name;
    }
    _role = fields['role']?.toString() ?? 'client';
    setState(() => _loading = false);
  }

  Future<void> _load() async {
    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _loading = false;
        _loadWarning = 'Session expirée. Reconnectez-vous.';
      });
      return;
    }
    final res = await ApiService.getMe(token, force: true);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      setState(() {
        _loading = false;
        _loadWarning = ApiService.userFacingMessage(
          res,
          fallback: 'Profil partiellement chargé. Vous pouvez quand même modifier vos informations.',
        );
      });
      _pushEnabled = await PushPreferences.isEnabled();
      if (mounted) setState(() {});
      return;
    }
    _applyProfileFromApi(res);
    _loadWarning = null;
    _pushEnabled = await PushPreferences.isEnabled();
    setState(() => _loading = false);
  }

  void _applyProfileFromApi(Map<String, dynamic> res) {
    _role = res['role']?.toString() ?? 'client';
    _email = res['email']?.toString() ?? '';
    _nameCtrl.text = res['name']?.toString() ?? '';
    _phoneCtrl.text = res['phone']?.toString() ?? '';
    _specialtyCtrl.text = res['mechanic_specialty']?.toString() ?? '';
    _avatarUrl = res['avatar_url']?.toString();
    _avatarCacheEpoch = DateTime.now().millisecondsSinceEpoch;
    final av = res['is_available'];
    _mechanicAvailable = av is bool ? av : av == 1 || av?.toString() == '1';
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<bool> _patchProfileFields(Map<String, dynamic> fields) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      _showSnack('Session expirée.', isError: true);
      return false;
    }
    final res = await ApiService.patchProfile(token, fields);
    if (!mounted) return false;
    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    if (!ok) {
      _showSnack(
        ApiService.userFacingMessage(res, fallback: 'Enregistrement impossible'),
        isError: true,
      );
      return false;
    }
    _applyProfileFromApi(res);
    final name = res['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      await AuthStorage.updateName(name);
    }
    _profileDirty = true;
    ProfileSignals.instance.notifyProfilesChanged();
    return true;
  }

  Future<void> _setMechanicAvailability(bool enabled) async {
    final previous = _mechanicAvailable;
    setState(() => _mechanicAvailable = enabled);
    final token = await AuthStorage.getToken();
    if (token == null) {
      setState(() => _mechanicAvailable = previous);
      return;
    }
    final res = await ApiService.updateMechanicAvailability(token, enabled);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      setState(() => _mechanicAvailable = previous);
      _showSnack(
        ApiService.userFacingMessage(res, fallback: 'Impossible de mettre à jour la disponibilité'),
        isError: true,
      );
      return;
    }
    _profileDirty = true;
    ProfileSignals.instance.notifyProfilesChanged();
    if (enabled) {
      unawaited(ApiService.touchPresence(token));
    }
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
      _localAvatarBytes = null;
      _profileDirty = true;
    });
    _applyProfileFromApi(res);
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
              title: Text('Galerie', style: AppFonts.style(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Appareil photo', style: AppFonts.style(fontWeight: FontWeight.w600)),
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

  void _showEmailInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('E-mail', style: AppFonts.style(fontWeight: FontWeight.w700)),
        content: Text(
          _email.isEmpty
              ? 'Votre e-mail de connexion n’est pas disponible pour le moment.'
              : '$_email\n\nL’e-mail de connexion ne peut pas être modifié ici. '
                  'Utilisez « Mot de passe oublié » sur l’écran de connexion si besoin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _editField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    int maxLines = 1,
    required Map<String, dynamic> Function(String trimmed) buildPatch,
  }) async {
    final local = TextEditingController(text: ctrl.text);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(label, style: AppFonts.style(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: local,
            keyboardType: keyboard,
            maxLines: maxLines,
            autofocus: true,
            decoration: InputDecoration(border: const OutlineInputBorder(), labelText: label),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      final trimmed = local.text.trim();
      if (label == 'Nom' && trimmed.isEmpty) {
        _showSnack('Le nom ne peut pas être vide.', isError: true);
        return;
      }
      if (label == 'Téléphone' && trimmed.length > 20) {
        _showSnack('Numéro trop long (20 caractères max).', isError: true);
        return;
      }

      final previous = ctrl.text;
      ctrl.text = trimmed;
      setState(() => _saving = true);
      final saved = await _patchProfileFields(buildPatch(trimmed));
      if (!mounted) return;
      setState(() => _saving = false);
      if (!saved) {
        ctrl.text = previous;
        setState(() {});
        return;
      }
      _showSnack('$label enregistré.');
    } finally {
      local.dispose();
    }
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
    final phone = _phoneCtrl.text.trim();
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': phone.isEmpty ? null : phone,
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
      _showSnack(
        ApiService.userFacingMessage(res, fallback: 'Enregistrement impossible'),
        isError: true,
      );
      return;
    }
    _applyProfileFromApi(res);
    final name = res['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      await AuthStorage.updateName(name);
    }
    if (!mounted) return;
    _showSnack('Profil enregistré.');
    setState(() {
      _profileDirty = true;
      _loadWarning = null;
    });
    ProfileSignals.instance.notifyProfilesChanged();
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
          if (!_loading)
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
          : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_loadWarning != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.info_outline_rounded, color: Colors.orange.shade800),
                            title: Text(
                              _loadWarning!,
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _loadWarning = null;
                                });
                                _load();
                              },
                            ),
                          ),
                        ),
                      ),
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
                        style: AppFonts.style(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Utilisateur MechAssist',
                        style: AppFonts.style(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const MechAssistSectionLabel('Informations personnelles'),
                    MechAssistSectionCard(
                      children: [
                        MechAssistSettingsTile(
                          title: 'Nom complet',
                          subtitle: _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text,
                          onTap: () => _editField(
                            'Nom',
                            _nameCtrl,
                            buildPatch: (v) => <String, dynamic>{'name': v},
                          ),
                        ),
                        MechAssistSettingsTile(
                          title: 'Numéro de téléphone',
                          subtitle: _phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text,
                          onTap: () => _editField(
                            'Téléphone',
                            _phoneCtrl,
                            keyboard: TextInputType.phone,
                            buildPatch: (v) => <String, dynamic>{'phone': v.isEmpty ? null : v},
                          ),
                        ),
                        MechAssistSettingsTile(
                          title: 'E-mail',
                          subtitle: _email.isEmpty ? '—' : _email,
                          onTap: _showEmailInfo,
                        ),
                        if (_role == 'mecanicien')
                          MechAssistSettingsTile(
                            title: 'Spécialités',
                            subtitle: _specialtyCtrl.text.isEmpty ? '—' : _specialtyCtrl.text,
                            onTap: () => _editField(
                              'Spécialités',
                              _specialtyCtrl,
                              maxLines: 3,
                              buildPatch: (v) => <String, dynamic>{'mechanic_specialty': v},
                            ),
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
                            title: Text('Disponible', style: AppFonts.style(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Visible sur la carte'),
                            value: _mechanicAvailable,
                            activeTrackColor: FeuTheme.deepBlue,
                            onChanged: _loading || _saving ? null : _setMechanicAvailability,
                          ),
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_outlined, color: FeuTheme.deepBlue),
                          title: Text('Notifications push', style: AppFonts.style(fontWeight: FontWeight.w600)),
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
