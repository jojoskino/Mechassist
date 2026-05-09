import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_service.dart';
import '../widgets/intervention_chat_dialog.dart';

class DashboardMecanicien extends StatefulWidget {
  const DashboardMecanicien({super.key});

  @override
  State<DashboardMecanicien> createState() => _DashboardMecanicienState();
}

class _DashboardMecanicienState extends State<DashboardMecanicien> {
  bool available = false;
  bool loading = true;
  List<dynamic> requests = [];
  String currentName = 'Mecanicien';
  String currentRole = 'mecanicien';
  Timer? _refreshTimer;
  Timer? _presenceTimer;
  StreamSubscription<Position>? _positionSub;
  DateTime? _lastLocationPost;
  String? lastError;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh(silent: true));
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _touchPresence());
    _syncPush();
    _bootstrapLocation();
  }

  Future<bool> _ensureLocationPermission() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied && permission != LocationPermission.deniedForever;
  }

  Future<void> _bootstrapLocation() async {
    if (!await _ensureLocationPermission()) {
      return;
    }
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        await _pushLocation(last.latitude, last.longitude, force: true);
      }
    } catch (_) {}
    try {
      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );
      await _pushLocation(pos.latitude, pos.longitude, force: true);
    } catch (_) {}

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kIsWeb ? 0 : 12,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _pushLocation(pos.latitude, pos.longitude);
      },
      onError: (_) {},
    );
  }

  Future<void> _pushLocation(double lat, double lng, {bool force = false}) async {
    final now = DateTime.now();
    final last = _lastLocationPost;
    if (!force && last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    final token = await AuthStorage.getToken();
    if (token == null) return;
    _lastLocationPost = now;
    await ApiService.updateLocation(token, lat, lng);
  }

  Future<void> _touchPresence() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return;
    }
    await ApiService.touchPresence(token);
  }

  Future<void> _syncPush() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final fcm = await PushService.initAndGetToken();
    if (fcm != null && fcm.isNotEmpty) {
      await ApiService.updatePushToken(token, fcm);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _presenceTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  String _mechanicRequestExtraLine(Map<String, dynamic> r) {
    if (r['status']?.toString() != 'completed') return '';
    final parts = <String>[];
    final o = r['outcome']?.toString();
    if (o == 'fixed') parts.add('Client : panne réglée');
    if (o == 'not_fixed') parts.add('Client : panne non réglée');
    final rt = r['rating'];
    if (rt is Map && rt['stars'] != null) {
      parts.add('Note client : ${rt['stars']}/5');
      final c = rt['comment']?.toString();
      if (c != null && c.trim().isNotEmpty) {
        parts.add('« $c »');
      }
    }
    return parts.join(' · ');
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() => loading = true);
    }
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        lastError = 'Session invalide, reconnecte-toi.';
      });
      return;
    }

    String? errorMsg;
    try {
      final me = await ApiService.getMe(token);
      final ms = me['status'] as int?;
      if (ms != null && ms >= 200 && ms < 300) {
        final rawAvail = me['is_available'];
        available = rawAvail is bool
            ? rawAvail
            : rawAvail == 1 || rawAvail == true || rawAvail?.toString() == '1';
        currentName = me['name']?.toString() ?? 'Mecanicien';
        currentRole = me['role']?.toString() ?? 'mecanicien';
        await _touchPresence();
      } else {
        errorMsg = me['message']?.toString() ?? 'Session invalide ou API injoignable (${me['status']}).';
      }

      final reqs = await ApiService.listRequests(token);
      final rs = reqs['status'] as int?;
      if (rs != null && rs >= 200 && rs < 300 && reqs['data'] is List) {
        requests = reqs['data'] as List;
      } else {
        requests = [];
        errorMsg ??= reqs['message']?.toString() ?? 'Impossible de charger les demandes (${reqs['status']}).';
      }
    } catch (_) {
      errorMsg ??= 'Impossible de charger les données. Vérifie ta connexion et que l’API tourne (port 8000).';
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      lastError = errorMsg;
    });
  }

  Future<void> _setAvailability(bool value) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final res = await ApiService.updateMechanicAvailability(token, value);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (ok) {
      setState(() => available = value);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Erreur disponibilité')),
      );
    }
  }

  Future<void> _processRequest(int id, bool accept) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final res = accept ? await ApiService.acceptRequest(token, id) : await ApiService.declineRequest(token, id);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Action impossible')),
      );
    }
    await _refresh(silent: true);
  }

  Future<void> _openChat(int requestId) async {
    if (!mounted) return;
    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;
    await showInterventionChatDialog(context: context, authToken: token, requestId: requestId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4C75),
        foregroundColor: Colors.white,
        title: const Text('MechAssist Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final token = await AuthStorage.getToken();
              if (token != null) {
                await ApiService.logout(token);
              }
              await GoogleSignInService.signOut();
              await AuthStorage.clear();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (lastError != null)
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: Text(lastError!, style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  SwitchListTile(
                    value: available,
                    onChanged: _setAvailability,
                    title: const Text('Disponible'),
                    subtitle: Text(available ? 'Visible par les clients' : 'Hors ligne'),
                  ),
                  const SizedBox(height: 10),
                  const Text('Demandes recues', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (requests.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('Aucune demande recue'),
                        subtitle: Text('Active ton statut pour apparaitre aux clients.'),
                      ),
                    ),
                  ...requests.map((raw) {
                    final r = Map<String, dynamic>.from(raw as Map);
                    final status = r['status']?.toString() ?? '';
                    final canAct = status == 'pending';
                    final id = ApiService.parseIntId(r['id']);
                    final extra = _mechanicRequestExtraLine(r);
                    return Card(
                      child: ListTile(
                        title: Text('${r['vehicle_type']} • $status'),
                        subtitle: Text(
                          '${r['description']?.toString() ?? ''}${extra.isEmpty ? '' : '\n$extra'}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (canAct && id != null)
                              IconButton(
                                onPressed: () => _processRequest(id, true),
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                            if (canAct && id != null)
                              IconButton(
                                onPressed: () => _processRequest(id, false),
                                icon: const Icon(Icons.cancel, color: Colors.red),
                              ),
                            if (status == 'accepted' && id != null)
                              TextButton(
                                onPressed: () => _openChat(id),
                                child: const Text('Chat'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}