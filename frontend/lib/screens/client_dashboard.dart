import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_service.dart';
import '../widgets/intervention_chat_dialog.dart';
import '../widgets/mechanic_nearby_map.dart';

class DashboardClient extends StatefulWidget {
  const DashboardClient({super.key});

  @override
  State<DashboardClient> createState() => _DashboardClientState();
}

class _DashboardClientState extends State<DashboardClient> with WidgetsBindingObserver {
  List<dynamic> mechanics = [];
  List<Map<String, dynamic>> _apiMechanics = [];

  List<dynamic> requests = [];
  bool loading = true;
  /// Premier chargement plein écran uniquement ; ensuite les onglets restent utilisables.
  bool _initializing = true;
  bool _showWebMapHint = true;
  bool _sendingRequest = false;
  double? lat;
  double? lng;
  String currentName = 'Client';
  String currentRole = 'client';
  int _tabIndex = 0;
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionSub;
  DateTime? _lastLocationPost;
  String? lastError;
  String? _googleMapsWebKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPublicConfig();
    _refreshAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshListsOnly());
    _syncPush();
    _startPositionTracking();
  }

  Future<void> _loadPublicConfig() async {
    final c = await ApiService.getClientConfig();
    if (!mounted) {
      return;
    }
    final raw = c['google_maps_web_api_key'];
    final s = raw?.toString().trim();
    setState(() {
      _googleMapsWebKey = (s != null && s.isNotEmpty && s != 'null') ? s : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll(silent: true, requireFreshGps: false);
    }
  }

  Future<void> _syncPush() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final fcm = await PushService.initAndGetToken();
    if (fcm != null && fcm.isNotEmpty) {
      await ApiService.updatePushToken(token, fcm);
    }
  }

  /// Liste issue uniquement de l’API (PostgreSQL) — rafraîchie au pull, au timer et au GPS.
  void _recomputeMergedMechanics() {
    mechanics = List<dynamic>.from(_apiMechanics);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  /// Rafraîchit mécaniciens + demandes en réutilisant la position déjà connue (rapide).
  Future<void> _refreshListsOnly() async {
    await _refreshAll(silent: true, requireFreshGps: false);
  }

  Future<void> _refreshAll({bool silent = false, bool requireFreshGps = true}) async {
    if (!silent && _initializing) {
      setState(() => loading = true);
    }
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _initializing = false;
        lastError = 'Session invalide, reconnecte-toi.';
      });
      return;
    }
    currentName = (await AuthStorage.getName()) ?? 'Client';
    currentRole = (await AuthStorage.getRole()) ?? 'client';

    String? errorMsg;
    try {
      final reuseCoords = lat != null && lng != null && !requireFreshGps;
      if (!reuseCoords) {
        final position = await _getPositionBestEffort();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      }

      if (lat != null && lng != null) {
        if (requireFreshGps || _lastLocationPost == null) {
          final loc = await ApiService.updateLocation(token, lat!, lng!);
          if ((loc['status'] as int?) != null && (loc['status'] as int) >= 400) {
            errorMsg = loc['message']?.toString() ?? 'Erreur mise à jour position.';
          } else {
            _lastLocationPost = DateTime.now();
          }
        }
        final nearby = await ApiService.nearbyMechanics(token, lat!, lng!);
        final ns = nearby['status'] as int?;
        if (ns != null && ns >= 200 && ns < 300 && nearby['data'] is List) {
          _apiMechanics = (nearby['data'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _apiMechanics = [];
          errorMsg ??=
              nearby['message']?.toString() ?? 'Impossible de charger les mécaniciens (code ${nearby['status']}).';
        }
        _recomputeMergedMechanics();
      } else {
        _apiMechanics = [];
        _recomputeMergedMechanics();
        if (kIsWeb) {
          errorMsg ??=
              'Géolocalisation refusée ou indisponible dans le navigateur. Autorise la position pour ce site (icône à gauche de l’URL) puis rafraîchis.';
        } else {
          errorMsg ??=
              'Position GPS indisponible (services désactivés ou permission refusée). Active la localisation puis rafraîchis.';
        }
      }

      final reqRes = await ApiService.listRequests(token);
      final rs = reqRes['status'] as int?;
      if (rs != null && rs >= 200 && rs < 300 && reqRes['data'] is List) {
        requests = reqRes['data'] as List;
      } else {
        requests = [];
        errorMsg ??= reqRes['message']?.toString() ?? 'Impossible de charger tes demandes (code ${reqRes['status']}).';
      }
    } catch (_) {
      errorMsg ??= 'Impossible de charger les données. Vérifie ta connexion et que l’API tourne (port 8000).';
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      _initializing = false;
      lastError = errorMsg;
    });
  }

  Future<void> _startPositionTracking() async {
    if (!await _ensureLocationPermission()) {
      return;
    }
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kIsWeb ? 0 : 12,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        lat = pos.latitude;
        lng = pos.longitude;
        final now = DateTime.now();
        final last = _lastLocationPost;
        if (last == null || now.difference(last) > const Duration(seconds: 10)) {
          _lastLocationPost = now;
          AuthStorage.getToken().then((token) {
            if (token != null) {
              ApiService.updateLocation(token, pos.latitude, pos.longitude);
            }
          });
        }
        _recomputeMergedMechanics();
        if (mounted) {
          setState(() {});
        }
      },
      onError: (_) {},
    );
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

  /// Dernière position connue puis GPS actuel (évite d’attendre à chaque rafraîchissement).
  Future<Position?> _getPositionBestEffort() async {
    if (!await _ensureLocationPermission()) {
      return null;
    }
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return last;
      }
    } catch (_) {}
    try {
      return await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _createRequest(Map<String, dynamic> mechanic) async {
    if (_sendingRequest) {
      return;
    }
    final descCtrl = TextEditingController();
    String vehicleType = 'voiture';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Demande à ${mechanic['name']}'),
        content: StatefulBuilder(
          builder: (context, setInnerState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: vehicleType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'voiture', child: Text('Voiture')),
                  DropdownMenuItem(value: 'moto', child: Text('Moto')),
                  DropdownMenuItem(value: 'autre', child: Text('Autre')),
                ],
                onChanged: (v) => setInnerState(() => vehicleType = v ?? 'voiture'),
              ),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Décris la panne'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );

    if (confirmed != true) {
      descCtrl.dispose();
      return;
    }
    if (lat == null || lng == null) {
      descCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position indisponible. Autorise la géolocalisation puis réessaie.')),
      );
      return;
    }
    final token = await AuthStorage.getToken();
    if (token == null) {
      descCtrl.dispose();
      return;
    }

    final mechanicId = ApiService.parseIntId(mechanic['id']);
    if (mechanicId == null) {
      descCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mécanicien invalide.')));
      return;
    }
    final desc = descCtrl.text.trim();
    if (desc.isEmpty) {
      descCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoute une description de la panne.')));
      return;
    }

    setState(() => _sendingRequest = true);
    final res = await ApiService.createRequest(
      token: token,
      mechanicId: mechanicId,
      vehicleType: vehicleType,
      description: desc,
      clientLat: lat!,
      clientLng: lng!,
    );
    descCtrl.dispose();

    if (!mounted) return;
    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Demande envoyée au mécanicien.' : (res['message']?.toString() ?? 'Erreur (${code ?? '—'})'),
        ),
        backgroundColor: ok ? null : Colors.red.shade800,
      ),
    );
    if (ok) {
      await _refreshAll(silent: true, requireFreshGps: false);
      if (mounted) {
        setState(() => _tabIndex = 1);
      }
    }
    if (mounted) {
      setState(() => _sendingRequest = false);
    }
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
        title: const Text('MechAssist'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshAll(silent: false, requireFreshGps: true),
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
      body: _initializing && loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(),
                _buildRequestsTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: const Color(0xFF0F4C75),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.near_me_outlined), activeIcon: Icon(Icons.near_me), label: 'Proches'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Demandes'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () => _refreshAll(silent: false, requireFreshGps: true),
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
          const Text('Mecaniciens proches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (lat != null && lng != null)
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MechanicNearbyMap(
                  clientLat: lat!,
                  clientLng: lng!,
                  mechanics: mechanics.map((m) => Map<String, dynamic>.from(m as Map)).toList(),
                  googleMapsWebApiKey: _googleMapsWebKey,
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (mechanics.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Aucun mecanicien disponible'),
                subtitle: Text('Essaie de rafraichir ou elargir la zone.'),
              ),
            ),
          ...mechanics.map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            return Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      m['name']?.toString() ?? 'Mécanicien',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m['distance_km']} km • ${m['phone'] ?? ''}'
                      '${m['is_online'] == true ? ' · En ligne' : ''}',
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _sendingRequest ? null : () => _createRequest(m),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C75),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _sendingRequest
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Demander'),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (kIsWeb && _showWebMapHint)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Aide carte (Web)'),
                subtitle: const Text(
                  'Autorise la géolocalisation dans le navigateur. Clé Google Maps optionnelle côté serveur (GOOGLE_MAPS_WEB_API_KEY) ; sinon carte Carto.',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showWebMapHint = false),
                  tooltip: 'Masquer',
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _mechanicNameFromRequest(Map<String, dynamic> r) {
    final m = r['mechanic'];
    if (m is Map) {
      return m['name']?.toString() ?? '—';
    }
    return '—';
  }

  void _showRequestDetail(Map<String, dynamic> r) {
    final id = ApiService.parseIntId(r['id']);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Demande #${id ?? '—'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mécanicien : ${_mechanicNameFromRequest(r)}'),
              const SizedBox(height: 8),
              Text('Véhicule : ${r['vehicle_type'] ?? '—'}'),
              const SizedBox(height: 8),
              Text('Statut : ${r['status'] ?? '—'}'),
              const SizedBox(height: 8),
              Text(r['description']?.toString() ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          if (r['status']?.toString() == 'accepted' && id != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openChat(id);
              },
              child: const Text('Ouvrir le chat'),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: () => _refreshAll(silent: true, requireFreshGps: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Mes demandes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (requests.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Aucune demande pour le moment'),
                subtitle: Text('Envoie une demande depuis l’onglet Proches.'),
              ),
            ),
          ...requests.map((raw) {
            final r = Map<String, dynamic>.from(raw as Map);
            return Card(
              child: ListTile(
                title: Text('${r['vehicle_type'] ?? '—'} • ${_mechanicNameFromRequest(r)}'),
                subtitle: Text(
                  '${r['description']?.toString() ?? ''}\n'
                  '${switch (r['status']?.toString()) {
                    'pending' => 'En attente de réponse',
                    'accepted' => 'Acceptée — touche pour détails ou Chat',
                    'declined' => 'Refusée',
                    _ => 'Statut : ${r['status']}',
                  }}',
                ),
                isThreeLine: true,
                onTap: () => _showRequestDetail(r),
                trailing: r['status']?.toString() == 'accepted'
                    ? TextButton(
                        onPressed: () {
                          final id = ApiService.parseIntId(r['id']);
                          if (id != null) {
                            _openChat(id);
                          }
                        },
                        child: const Text('Chat'),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            );
          }),
        ],
      ),
    );
  }
}