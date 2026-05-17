import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_config.dart';
import '../services/api_service.dart';
import '../widgets/auth_shell.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const Color accent = Color(0xFF0F4C75);
  final TextEditingController _apiOriginCtrl = TextEditingController();
  bool _testingPing = false;

  @override
  void initState() {
    super.initState();
    _apiOriginCtrl.text = ApiService.serverOrigin;
  }

  @override
  void dispose() {
    _apiOriginCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir : $url')),
      );
    }
  }

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copié dans le presse-papiers')),
    );
  }

  Future<void> _testPing() async {
    setState(() => _testingPing = true);
    if (!ApiService.isServerWarm) {
      await ApiService.ensureBackendReady();
    }
    final ok = await ApiService.pingHealth(timeout: const Duration(seconds: 20));
    if (!mounted) return;
    setState(() => _testingPing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (kIsWeb
                  ? 'Connexion OK vers ${ApiService.serverOrigin}.'
                  : 'Connexion OK : le téléphone atteint le serveur.')
              : (kIsWeb
                  ? 'Échec : vérifiez que ngrok et Laravel (port 8000) tournent sur le PC.'
                  : 'Échec : vérifie l’URL ci-dessus, le pare-feu Windows et php artisan serve --host=0.0.0.0'),
        ),
        backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
      ),
    );
  }

  Future<void> _saveApiOrigin() async {
    if (kIsWeb) {
      await _resetApiOrigin();
      return;
    }
    final raw = _apiOriginCtrl.text.trim();
    if (raw.isEmpty) {
      await ApiConfig.setBaseUrlOverride(null);
    } else {
      if (ApiConfig.isClientHostInvalid(raw)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'N’utilise pas 0.0.0.0 : ce n’est pas une adresse valide dans le navigateur ou l’app. '
              'Sur ce PC : http://127.0.0.1:8000 . Depuis un téléphone sur le Wi‑Fi : http://192.168.x.x:8000 (IP du PC, voir ipconfig).',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await ApiConfig.setBaseUrlOverride(raw);
    }
    if (!mounted) return;
    setState(() {
      _apiOriginCtrl.text = ApiService.serverOrigin;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL enregistrée. Rafraîchis l’accueil ou reconnecte-toi.')),
    );
  }

  Future<void> _resetApiOrigin() async {
    if (kIsWeb) {
      await ApiConfig.setBaseUrlOverride(ApiConfig.productionOrigin);
    } else {
      await ApiConfig.setBaseUrlOverride(null);
    }
    if (!mounted) return;
    setState(() {
      _apiOriginCtrl.text = ApiService.serverOrigin;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? 'API tunnel rétablie.'
              : 'URL par défaut rétablie (émulateur / machine locale).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiRoot = ApiService.apiRoot;
    final swagger = ApiService.documentationUrl;

    return AuthShell(
      title: 'Aide',
      subtitle: 'URL de l’API, téléphone physique, documentation.',
      showBack: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kIsWeb ? 'Serveur cloud (Web)' : 'Serveur Laravel (téléphone physique)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      kIsWeb
                          ? 'URL actuelle (ngrok auto via run_web.ps1) :\n${ApiService.serverOrigin}\n\n'
                              'Lance l’app avec .\\run_web.ps1 : ngrok et l’URL sont configurés automatiquement.'
                          : 'Sur un vrai téléphone, l’émulateur par défaut (10.0.2.2) ne marche pas. '
                              'Mets l’IP LAN de ton PC, ex. http://192.168.1.5:8000 puis Enregistrer.\n\n'
                              'Ne mets jamais 0.0.0.0 dans l’app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiOriginCtrl,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'http://192.168.x.x:8000',
                          labelText: 'Origine du serveur (sans /api)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveApiOrigin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Enregistrer'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _resetApiOrigin,
                            child: const Text('Défaut'),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      SelectableText(
                        ApiService.serverOrigin,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _resetApiOrigin,
                        child: const Text('Réinitialiser l’API cloud'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _testingPing ? null : _testPing,
                        icon: _testingPing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F4C75)),
                              )
                            : const Icon(Icons.wifi_tethering, size: 20),
                        label: Text(_testingPing ? 'Test en cours…' : 'Tester la connexion API'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Préfixe API actuel', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SelectableText(apiRoot, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _copy(context, 'URL API', apiRoot),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier l’URL de l’API'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Swagger (tester les routes)', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SelectableText(swagger, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _openUrl(context, swagger),
                      icon: const Icon(Icons.open_in_new, size: 20),
                      label: const Text('Ouvrir la documentation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecte-toi avec POST /api/login, copie le champ « token », puis « Authorize » dans Swagger (Bearer).',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Alternative : compiler avec --dart-define=API_BASE_URL=http://IP_DU_PC:8000',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
