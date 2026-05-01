import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import '../widgets/intervention_chat_dialog.dart';

class DashboardClient extends StatefulWidget {
  const DashboardClient({super.key});

  @override
  State<DashboardClient> createState() => _DashboardClientState();
}

class _DashboardClientState extends State<DashboardClient> {
  List<dynamic> mechanics = [];
  List<dynamic> requests = [];
  bool loading = true;
  double? lat;
  double? lng;
  String currentName = 'Client';
  String currentRole = 'client';
  int _tabIndex = 0;
  Timer? _refreshTimer;
  String? lastError;

  bool get _mapsSupported => true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _refreshAll(silent: true));
    _syncPush();
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
    super.dispose();
  }

  Future<void> _refreshAll({bool silent = false}) async {
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
    currentName = (await AuthStorage.getName()) ?? 'Client';
    currentRole = (await AuthStorage.getRole()) ?? 'client';

    String? errorMsg;
    try {
      final position = await _getPosition();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        final loc = await ApiService.updateLocation(token, lat!, lng!);
        if ((loc['status'] as int?) != null && (loc['status'] as int) >= 400) {
          errorMsg = loc['message']?.toString() ?? 'Erreur mise à jour position.';
        }
        final nearby = await ApiService.nearbyMechanics(token, lat!, lng!);
        final ns = nearby['status'] as int?;
        if (ns != null && ns >= 200 && ns < 300 && nearby['data'] is List) {
          mechanics = nearby['data'] as List;
        } else {
          mechanics = [];
          errorMsg ??=
              nearby['message']?.toString() ?? 'Impossible de charger les mécaniciens (code ${nearby['status']}).';
        }
      } else {
        mechanics = [];
        if (kIsWeb) {
          errorMsg ??=
              'Géolocalisation indisponible sur le navigateur. Lance l’app sur Android ou un émulateur pour tester la carte.';
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
      lastError = errorMsg;
    });
  }

  Future<Position?> _getPosition() async {
    if (kIsWeb) {
      return null;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition().timeout(const Duration(seconds: 8), onTimeout: () => throw TimeoutException('GPS timeout'));
  }

  Future<void> _createRequest(Map<String, dynamic> mechanic) async {
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

    if (confirmed != true || lat == null || lng == null) return;
    final token = await AuthStorage.getToken();
    if (token == null) return;

    final mechanicId = ApiService.parseIntId(mechanic['id']);
    if (mechanicId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mécanicien invalide.')));
      return;
    }
    final desc = descCtrl.text.trim();
    if (desc.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoute une description de la panne.')));
      return;
    }

    final res = await ApiService.createRequest(
      token: token,
      mechanicId: mechanicId,
      vehicleType: vehicleType,
      description: desc,
      clientLat: lat!,
      clientLng: lng!,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['status'] == 201 ? 'Demande envoyée' : (res['message']?.toString() ?? 'Erreur'))),
    );
    await _refreshAll(silent: true);
  }

  Future<void> _openChat(int requestId) async {
    if (!mounted) return;
    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;
    await showInterventionChatDialog(context: context, authToken: token, requestId: requestId);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[_buildHomeTab(), _buildRequestsTab()];

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
            onPressed: _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final token = await AuthStorage.getToken();
              if (token != null) {
                await ApiService.logout(token);
              }
              await AuthStorage.clear();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pages[_tabIndex],
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
      onRefresh: _refreshAll,
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
                  if (lat != null && lng != null && _mapsSupported)
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat!, lng!),
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.mechassist',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat!, lng!),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(Icons.my_location, color: Color(0xFF0F4C75), size: 28),
                                ),
                                ...mechanics.map((m) {
                                  final map = Map<String, dynamic>.from(m as Map);
                                  final ml = (map['latitude'] as num?)?.toDouble();
                                  final mg = (map['longitude'] as num?)?.toDouble();
                                  if (ml == null || mg == null) {
                                    return null;
                                  }
                                  return Marker(
                                    point: LatLng(ml, mg),
                                    width: 32,
                                    height: 32,
                                    child: const Icon(Icons.build_circle, color: Colors.red, size: 26),
                                  );
                                }).whereType<Marker>(),
                              ],
                            ),
                          ],
                ),
              ),
            ),
          if (lat != null && lng != null && !_mapsSupported)
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Google Maps visible sur Android/iOS'),
            ),
          const SizedBox(height: 10),
          if (mechanics.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Aucun mecanicien disponible'),
                subtitle: Text('Essaie de rafraichir ou elargir la zone.'),
              ),
            ),
          ...mechanics.map((m) => Card(
                color: Colors.white,
                child: ListTile(
                  title: Text(m['name']?.toString() ?? '-'),
                  subtitle: Text('${m['distance_km']} km • ${m['phone'] ?? ''}'),
                  trailing: ElevatedButton(
                    onPressed: () => _createRequest(Map<String, dynamic>.from(m as Map)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C75)),
                    child: const Text('Demander'),
                  ),
                ),
              )),
          if (kIsWeb)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Geolocalisation limitee sur Web'),
                subtitle: Text('Teste la carte/geolocalisation surtout sur Android.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Mes demandes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Aucune demande pour le moment'),
              subtitle: Text('Envoie une demande a un mecanicien proche.'),
            ),
          ),
        ...requests.map((r) => Card(
              child: ListTile(
                title: Text('${r['vehicle_type']} • ${r['status']}'),
                subtitle: Text(r['description']?.toString() ?? ''),
                trailing: r['status']?.toString() == 'accepted'
                    ? TextButton(
                        onPressed: () {
                          final id = ApiService.parseIntId(r['id']);
                          if (id != null) _openChat(id);
                        },
                        child: const Text('Chat'),
                      )
                    : Text(
                        switch (r['status']?.toString()) {
                          'pending' => 'En attente',
                          'declined' => 'Refusée',
                          _ => 'Statut: ${r['status']}',
                        },
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
              ),
            )),
      ],
    );
  }
}