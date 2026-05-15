import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_service.dart';
import '../theme/feu_theme.dart';
import '../utils/gps_helper.dart';
import '../utils/list_search.dart';
import '../utils/phone_launch.dart';
import '../widgets/intervention_locations_map.dart';
import '../widgets/maps_discovery_shell.dart';
import '../widgets/maps_sheet_banner.dart';
import '../widgets/public_network_image.dart';
import '../screens/trip_navigation_screen.dart';
import '../screens/user_profile_page.dart';
import '../widgets/user_avatar.dart';
import '../utils/profile_navigation.dart';
import '../services/app_notification_hub.dart';
import '../services/profile_signals.dart';
import '../screens/history_screen.dart';
import '../screens/notifications_panel.dart';
import '../widgets/dashboard_brand_bar.dart';

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
  String? _myAvatarUrl;
  int? _myAvatarCacheEpoch;
  int _clientAvatarEpoch = 0;
  String _cachedClientAvatarSig = '';
  Timer? _refreshTimer;
  Timer? _presenceTimer;
  StreamSubscription<Position>? _positionSub;
  DateTime? _lastLocationPost;
  String? lastError;
  /// Filtre API `?status=` (null = toutes).
  String? _requestStatusFilter;
  int _tabIndex = 0;
  double? lat;
  double? lng;
  bool _locationReady = false;
  String? _googleMapsWebKey;
  final TextEditingController _requestSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppNotificationHub.instance.addListener(_onNotificationsChanged);
    ProfileSignals.instance.addListener(_onProfilesExternallyUpdated);
    _loadPublicConfig();
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

  Future<void> _loadPublicConfig() async {
    final c = await ApiService.getClientConfig();
    if (!mounted) return;
    final raw = c['google_maps_web_api_key'];
    final s = raw?.toString().trim();
    setState(() {
      _googleMapsWebKey = (s != null && s.isNotEmpty && s != 'null') ? s : null;
    });
  }

  void _applyCoords(double latitude, double longitude) {
    if (!mounted) return;
    setState(() {
      lat = latitude;
      lng = longitude;
      _locationReady = true;
    });
  }

  Future<void> _bootstrapLocation() async {
    if (!await _ensureLocationPermission()) {
      if (mounted) setState(() => _locationReady = false);
      return;
    }
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _applyCoords(last.latitude, last.longitude);
        await _pushLocation(last.latitude, last.longitude, force: true);
      }
    } catch (_) {}
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );
      _applyCoords(pos.latitude, pos.longitude);
      await _pushLocation(pos.latitude, pos.longitude, force: true);
    } catch (_) {}

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kIsWeb ? 0 : 12,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _applyCoords(pos.latitude, pos.longitude);
        _pushLocation(pos.latitude, pos.longitude);
      },
      onError: (_) {},
    );
  }

  Future<void> _refreshGpsNow() async {
    final pos = await GpsHelper.bestPosition();
    if (pos != null) {
      _applyCoords(pos.latitude, pos.longitude);
      await _pushLocation(pos.latitude, pos.longitude, force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position mise à jour.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('GPS indisponible. Vérifie que la localisation est activée.'),
        action: SnackBarAction(
          label: 'Réglages',
          onPressed: () => GpsHelper.openSettingsIfNeeded(),
        ),
      ),
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
    Future<void>.microtask(() async {
      try {
        final token = await AuthStorage.getToken();
        if (token == null) return;
        final fcm = await PushService.initAndGetToken();
        if (fcm != null && fcm.isNotEmpty) {
          await ApiService.updatePushToken(token, fcm);
        }
      } catch (_) {}
    });
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _onProfilesExternallyUpdated() {
    if (mounted) setState(() {});
    _refresh(silent: true);
  }

  int get _clientAvatarCacheEpoch => Object.hash(_clientAvatarEpoch, ProfileSignals.instance.generation);

  String _clientAvatarSignature() {
    final parts = <String>[];
    for (final raw in requests) {
      final r = raw is Map<String, dynamic>
          ? Map<String, dynamic>.from(raw)
          : Map<String, dynamic>.from(raw as Map);
      final c = r['client'];
      if (c is Map) parts.add(c['avatar_url']?.toString() ?? '');
    }
    return parts.join('\x1e');
  }

  @override
  void dispose() {
    AppNotificationHub.instance.removeListener(_onNotificationsChanged);
    ProfileSignals.instance.removeListener(_onProfilesExternallyUpdated);
    _refreshTimer?.cancel();
    _presenceTimer?.cancel();
    _positionSub?.cancel();
    _requestSearchCtrl.dispose();
    super.dispose();
  }

  int get _pendingRequestsCount {
    return requests.where((raw) {
      final s = (raw is Map ? raw['status'] : null)?.toString();
      return s == 'pending';
    }).length;
  }

  void _openNotifications() {
    AppNotificationHub.instance.markAllRead();
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  List<dynamic> get _filteredRequests {
    final q = _requestSearchCtrl.text;
    return requests.where((raw) {
      final r = raw is Map<String, dynamic>
          ? Map<String, dynamic>.from(raw)
          : Map<String, dynamic>.from(raw as Map);
      final client = r['client'];
      final clientName = client is Map ? client['name']?.toString() : null;
      return matchesListSearch(q, [
        r['vehicle_type']?.toString(),
        r['description']?.toString(),
        r['client_address']?.toString(),
        r['status']?.toString(),
        clientName,
        r['id']?.toString(),
      ]);
    }).toList();
  }

  List<MapJobSite> _jobSitesForMap() {
    final sites = <MapJobSite>[];
    final seen = <String>{};
    for (final raw in requests) {
      final r = raw is Map<String, dynamic>
          ? Map<String, dynamic>.from(raw)
          : Map<String, dynamic>.from(raw as Map);
      final clat = (r['client_lat'] as num?)?.toDouble();
      final clng = (r['client_lng'] as num?)?.toDouble();
      if (clat == null || clng == null) continue;
      final id = r['id']?.toString() ?? '${clat}_$clng';
      if (seen.contains(id)) continue;
      seen.add(id);
      final client = r['client'];
      final name = client is Map ? client['name']?.toString() : null;
      final status = r['status']?.toString() ?? '';
      sites.add(MapJobSite(
        lat: clat,
        lng: clng,
        label: '${name ?? 'Client'} · $status',
        id: id,
      ));
    }
    return sites;
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

  Future<void> _confirmLogout(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FeuTheme.deepBlue),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final token = await AuthStorage.getToken();
    if (token != null) {
      await ApiService.logout(token);
    }
    await GoogleSignInService.signOut();
    await AuthStorage.clear();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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
      final results = await Future.wait<dynamic>([
        ApiService.getMe(token),
        ApiService.listRequests(token, status: _requestStatusFilter),
      ]);
      final me = results[0] as Map<String, dynamic>;
      final reqs = results[1] as Map<String, dynamic>;

      final ms = me['status'] as int?;
      if (ms != null && ms >= 200 && ms < 300) {
        final rawAvail = me['is_available'];
        available = rawAvail is bool
            ? rawAvail
            : rawAvail == 1 || rawAvail == true || rawAvail?.toString() == '1';
        currentName = me['name']?.toString() ?? 'Mecanicien';
        currentRole = me['role']?.toString() ?? 'mecanicien';
        _myAvatarUrl = me['avatar_url']?.toString();
        _myAvatarCacheEpoch = DateTime.now().millisecondsSinceEpoch;
        final mlat = (me['latitude'] as num?)?.toDouble();
        final mlng = (me['longitude'] as num?)?.toDouble();
        if (mlat != null && mlng != null) {
          lat = mlat;
          lng = mlng;
          _locationReady = true;
        }
        Future<void>.microtask(() => _touchPresence());
      } else {
        errorMsg = me['message']?.toString() ?? 'Session invalide ou API injoignable (${me['status']}).';
      }

      final rs = reqs['status'] as int?;
      if (rs != null && rs >= 200 && rs < 300 && reqs['data'] is List) {
        requests = reqs['data'] as List;
      } else {
        requests = [];
        errorMsg ??= reqs['message']?.toString() ?? 'Impossible de charger les demandes (${reqs['status']}).';
      }
    } catch (_) {
      errorMsg ??= 'Impossible de charger les données. Vérifie ta connexion.';
    }

    if (!mounted) return;
    final nextSig = _clientAvatarSignature();
    if (nextSig != _cachedClientAvatarSig) {
      _cachedClientAvatarSig = nextSig;
      _clientAvatarEpoch++;
    }
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

  Future<void> _processRequest(int id, bool accept, Map<String, dynamic> request) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final res = accept ? await ApiService.acceptRequest(token, id) : await ApiService.declineRequest(token, id);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Action impossible')),
      );
      await _refresh(silent: true);
      return;
    }
    await _refresh(silent: true);
    if (!accept || !mounted) return;

    final clat = (request['client_lat'] as num?)?.toDouble();
    final clng = (request['client_lng'] as num?)?.toDouble();
    if (clat == null || clng == null) return;

    final client = request['client'];
    final clientMap = client is Map ? Map<String, dynamic>.from(client) : <String, dynamic>{};
  final clientName = clientMap['name']?.toString() ?? 'Client';

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TripNavigationScreen(
          requestId: id,
          clientName: clientName,
          clientLat: clat,
          clientLng: clng,
          clientPhone: clientMap['phone']?.toString(),
          clientAddress: request['client_address']?.toString(),
          clientUser: clientMap.isEmpty ? null : clientMap,
        ),
      ),
    );
  }

  void _openClientProfile(Map<String, dynamic> r) {
    final client = r['client'];
    if (client is! Map) return;
    final user = Map<String, dynamic>.from(client);
    user['role'] = 'client';
    final id = ApiService.parseIntId(r['id']);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          user: user,
          subtitle: id != null ? 'Demande #$id' : null,
          onNavigate: () {
            final clat = (r['client_lat'] as num?)?.toDouble();
            final clng = (r['client_lng'] as num?)?.toDouble();
            if (clat == null || clng == null || id == null) return;
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TripNavigationScreen(
                  requestId: id,
                  clientName: user['name']?.toString() ?? 'Client',
                  clientLat: clat,
                  clientLng: clng,
                  clientPhone: user['phone']?.toString(),
                  clientAddress: r['client_address']?.toString(),
                  clientUser: user,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _markMechanicComplete(int id) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final res = await ApiService.mechanicMarkRequestComplete(token, id);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Intervention marquée terminée. Le client peut clôturer.' : (res['message']?.toString() ?? 'Action impossible')),
        backgroundColor: ok ? null : Colors.red.shade800,
      ),
    );
    await _refresh(silent: true);
  }

  Future<void> _openChat(int requestId) async {
    if (!mounted) return;
    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;
    await Navigator.pushNamed(context, '/intervention-chat', arguments: requestId);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.14)),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: FeuTheme.paper,
        appBar: DashboardBrandBar(
          pendingRequestsCount: _pendingRequestsCount,
          unreadNotificationsCount: AppNotificationHub.instance.unreadCount,
          onOpenNotifications: _openNotifications,
          onOpenRequests: () => setState(() => _tabIndex = 0),
          trailing: _tabIndex == 2
              ? [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    tooltip: 'Déconnexion',
                    onPressed: () => _confirmLogout(context),
                  ),
                ]
              : null,
        ),
        body: IndexedStack(
          index: _tabIndex,
          children: [
            _buildRequestsTab(),
            HistoryScreen(
              requests: requests,
              onRefresh: () => _refresh(silent: true),
              mechanicNameFor: (r) {
                final c = r['client'];
                if (c is Map) return c['name']?.toString() ?? 'Client';
                return 'Client';
              },
            ),
            _buildAccountTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: FeuTheme.ember,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Carte',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Historique',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts),
              label: 'Compte',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _mechanicFilterChips() {
    return [
      for (final e in <(String?, String)>[
        (null, 'Toutes'),
        ('pending', 'En attente'),
        ('accepted', 'Acceptées'),
        ('completed', 'Terminées'),
        ('declined', 'Refusées'),
        ('cancelled', 'Annulées'),
      ])
        MapsFilterChip(
          label: e.$2,
          selected: _requestStatusFilter == e.$1,
          onTap: () {
            setState(() => _requestStatusFilter = e.$1);
            _refresh(silent: true);
          },
        ),
    ];
  }

  Widget _buildMechanicMapLayer() {
    if (lat != null && lng != null) {
      return InterventionLocationsMap(
        mechanicLat: lat!,
        mechanicLng: lng!,
        jobSites: _jobSitesForMap(),
        googleMapsWebApiKey: _googleMapsWebKey,
      );
    }
    return ColoredBox(
      color: const Color(0xFFE8ECEF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 48, color: FeuTheme.deepBlue.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text(
                'Active le GPS pour voir les clients sur la carte.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _refreshGpsNow,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Activer la position'),
                style: FilledButton.styleFrom(backgroundColor: FeuTheme.deepBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMechanicRequestCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString().trim();
    final canAct = status == 'pending';
    final canMarkDone = status == 'accepted' &&
        (r['mechanic_completed_at'] == null ||
            r['mechanic_completed_at'].toString().trim().isEmpty ||
            r['mechanic_completed_at'].toString() == 'null');
    final id = ApiService.parseIntId(r['id']);
    final extra = _mechanicRequestExtraLine(r);
    final rawPhoto = r['photo_url']?.toString();
    final hasPhoto = rawPhoto != null && rawPhoto.trim().isNotEmpty;
    final client = r['client'];
    String? clientPhone;
    if (client is Map) {
      clientPhone = client['phone']?.toString();
    }
    final canDialClient = normalizePhoneForDial(clientPhone) != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhoto)
                  PublicNetworkImage(
                    url: rawPhoto,
                    width: 52,
                    height: 52,
                    borderRadius: BorderRadius.circular(8),
                  )
                else if (client is Map)
                  UserAvatar(
                    name: client['name']?.toString() ?? 'C',
                    avatarUrl: client['avatar_url']?.toString(),
                    cacheEpoch: _clientAvatarCacheEpoch,
                    radius: 26,
                    onTap: () => _openClientProfile(r),
                  )
                else
                  const Icon(Icons.person_pin_circle_outlined, size: 44, color: FeuTheme.deepBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['vehicle_type']} · $status',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (client is Map) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _openClientProfile(r),
                          child: Text(
                            client['name']?.toString() ?? 'Client',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FeuTheme.deepBlue,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${r['description']?.toString() ?? ''}${extra.isEmpty ? '' : '\n$extra'}',
                        style: TextStyle(fontSize: 13.5, height: 1.35, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (canDialClient && (status == 'pending' || status == 'accepted'))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => launchTelDialer(context, clientPhone),
                  icon: const Icon(Icons.call_rounded, size: 20),
                  label: const Text('Appeler'),
                  style: OutlinedButton.styleFrom(foregroundColor: FeuTheme.ember),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (canAct && id != null) ...[
                  FilledButton.icon(
                    onPressed: () => _processRequest(id, true, r),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Accepter'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  ),
                  FilledButton.icon(
                    onPressed: () => _processRequest(id, false, r),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Refuser'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                  ),
                ],
                if (status == 'accepted' && canMarkDone && id != null)
                  FilledButton.icon(
                    onPressed: () => _markMechanicComplete(id),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Terminée'),
                    style: FilledButton.styleFrom(backgroundColor: FeuTheme.deepBlue),
                  ),
                if (status == 'accepted' && id != null)
                  FilledButton.icon(
                    onPressed: () => _openChat(id),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: const Text('Chat'),
                    style: FilledButton.styleFrom(backgroundColor: FeuTheme.ember),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return MapsDiscoveryShell(
      map: _buildMechanicMapLayer(),
      loading: loading,
      searchController: _requestSearchCtrl,
      searchHint: 'Client, véhicule…',
      onSearch: () => setState(() {}),
      onRecenter: _refreshGpsNow,
      onPrimaryFab: _refresh,
      primaryFabIcon: Icons.refresh_rounded,
      profileInitial: currentName,
      profileAvatarUrl: _myAvatarUrl,
      profileAvatarCacheEpoch: _myAvatarCacheEpoch,
      onProfileTap: () async {
        final result = await Navigator.pushNamed(context, '/profile');
        if (!mounted) return;
        final parsed = ProfileNavigationResult.fromDynamic(result);
        if (parsed != null) {
          setState(() {
            if (parsed.avatarUrl != null && parsed.avatarUrl!.isNotEmpty) {
              _myAvatarUrl = parsed.avatarUrl;
              _myAvatarCacheEpoch = parsed.cacheEpoch ?? DateTime.now().millisecondsSinceEpoch;
            }
            _tabIndex = 2;
          });
          if (parsed.updated) {
            await _refresh(silent: true);
          }
        } else {
          setState(() => _tabIndex = 2);
        }
      },
      filterChips: _mechanicFilterChips(),
      sheetTitle: 'Demandes reçues',
      sheetSubtitle: available
          ? 'Disponible · ${_filteredRequests.length} affichée(s)'
          : 'Hors ligne · active-toi dans Compte',
      subtitleAccent: available,
      onSheetRefresh: _refresh,
      topBanner: lastError != null ? MapsSheetBanner(message: lastError!) : null,
      buildSheetBody: () {
        return [
          if (lat != null && lng != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    _locationReady ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                    color: FeuTheme.ember,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS actif · ${_jobSitesForMap().length} client(s) sur la carte',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          if (_filteredRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                requests.isEmpty
                    ? 'Aucune demande. Passe en disponible dans Compte.'
                    : 'Aucun résultat pour ce filtre ou cette recherche.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ),
          ..._filteredRequests.map((raw) {
            final r = raw is Map<String, dynamic>
                ? Map<String, dynamic>.from(raw)
                : Map<String, dynamic>.from(raw as Map);
            return _buildMechanicRequestCard(r);
          }),
        ];
      },
    );
  }

  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: FeuTheme.ember.withValues(alpha: 0.22),
                  foregroundColor: FeuTheme.deepBlue,
                  child: const Icon(Icons.build_circle_rounded, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentRole == 'mecanicien' ? 'Mécanicien' : currentRole,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (lastError != null)
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: Text(lastError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ),
        SwitchListTile(
          value: available,
          onChanged: loading ? null : _setAvailability,
          title: const Text('Disponible'),
          subtitle: Text(
            available ? 'Visible par les clients' : 'Hors ligne',
            style: TextStyle(
              color: available ? const Color(0xFF2E7D32) : Colors.grey.shade700,
              fontWeight: available ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          activeTrackColor: Colors.green.shade600,
          activeColor: Colors.white,
          inactiveThumbColor: Colors.grey.shade400,
          inactiveTrackColor: Colors.grey.shade300,
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.person_outline_rounded, color: FeuTheme.deepBlue.withValues(alpha: 0.9)),
          title: const Text('Mon profil'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final changed = await Navigator.pushNamed(context, '/profile');
            if (!mounted) return;
            if (changed == true) {
              await _refresh(silent: true);
            }
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Se déconnecter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FeuTheme.deepBlue,
            side: BorderSide(color: FeuTheme.deepBlue.withValues(alpha: 0.45)),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}