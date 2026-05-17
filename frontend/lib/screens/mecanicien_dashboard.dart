import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/api_data_cache.dart';
import '../services/api_response_cache.dart';
import '../services/client_config_cache.dart';
import '../services/refresh_coordinator.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_sync.dart';
import '../screens/full_screen_image_page.dart';
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
import '../services/live_sync.dart';
import '../services/profile_signals.dart';
import '../screens/history_screen.dart';
import '../screens/notifications_panel.dart';
import '../widgets/mechassist_bottom_nav.dart';
import '../widgets/mechassist_light_app_bar.dart';
import '../widgets/mechanic_stats_header.dart';
import '../screens/help_screen.dart';

class DashboardMecanicien extends StatefulWidget {
  const DashboardMecanicien({super.key});

  @override
  State<DashboardMecanicien> createState() => _DashboardMecanicienState();
}

class _DashboardMecanicienState extends State<DashboardMecanicien> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool available = false;
  bool loading = false;
  bool _availabilityBusy = false;
  List<dynamic> requests = [];
  String currentName = 'Mecanicien';
  String currentRole = 'mecanicien';
  String? _myAvatarUrl;
  int? _myAvatarCacheEpoch;
  int _clientAvatarEpoch = 0;
  String _cachedClientAvatarSig = '';
  Timer? _refreshTimer;
  Timer? _presenceTimer;
  Timer? _liveSyncDebounce;
  String _requestsSig = '';
  DateTime? _lastRequestsFetch;
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
  final _refreshCoordinator = RefreshCoordinator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppNotificationHub.instance.addListener(_onNotificationsChanged);
    ProfileSignals.instance.addListener(_onProfilesExternallyUpdated);
    LiveSync.instance.addListener(_onLiveSync);
    _applyMemoryCacheInstant();
    _requestsSig = _signatureForRequests(requests);
    unawaited(_loadPublicConfig());
    unawaited(_refresh(silent: true));
    _scheduleRefreshTimer();
    _schedulePresenceTimer();
    _syncPush();
    _bootstrapLocation();
  }

  void _scheduleRefreshTimer() {
    _refreshTimer?.cancel();
    final hasWork = _activeRequests.isNotEmpty;
    final interval = hasWork
        ? const Duration(seconds: 4)
        : (available ? const Duration(seconds: 8) : const Duration(seconds: 20));
    _refreshTimer = Timer.periodic(interval, (_) => _onPeriodicRefresh());
  }

  void _schedulePresenceTimer() {
    _presenceTimer?.cancel();
    final interval = available ? const Duration(seconds: 45) : const Duration(minutes: 2);
    _presenceTimer = Timer.periodic(interval, (_) => _touchPresence());
  }

  void _onPeriodicRefresh() {
    if (!mounted) return;
    unawaited(_refreshRequestsOnly(silent: true));
  }

  void _onLiveSync() {
    _liveSyncDebounce?.cancel();
    _liveSyncDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      unawaited(_refreshRequestsOnly(silent: true, forceNetwork: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ApiService.warmServer(wait: false));
      unawaited(_refreshRequestsOnly(silent: true, forceNetwork: true));
    }
  }

  String _signatureForRequests(List<dynamic> list) {
    final buf = StringBuffer();
    for (final raw in list) {
      final r = raw is Map ? raw : const <String, dynamic>{};
      buf.write('${r['id']}:${r['status']};');
    }
    return buf.toString();
  }

  bool _applyRequestsList(List<dynamic> next) {
    final sig = _signatureForRequests(next);
    if (sig == _requestsSig) return false;
    _requestsSig = sig;
    requests = next;
    _scheduleRefreshTimer();
    return true;
  }

  void _patchRequestStatusLocally(int id, String status) {
    final idx = requests.indexWhere((raw) {
      final r = raw is Map ? raw : const <String, dynamic>{};
      return ApiService.parseIntId(r['id']) == id;
    });
    if (idx < 0) return;
    final copy = Map<String, dynamic>.from(requests[idx] as Map);
    copy['status'] = status;
    final next = List<dynamic>.from(requests);
    next[idx] = copy;
    _applyRequestsList(next);
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

  void _applyMemoryCacheInstant() {
    final cached = ApiDataCache.requestsSync(mechanic: true);
    if (cached == null || cached.isEmpty) {
      loading = true;
      return;
    }
    requests = cached;
    loading = false;
    lastError = null;
  }

  void _scheduleSilentRetry() {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      if (!ApiService.isServerWarm) {
        await ApiService.ensureBackendReady(maxWait: const Duration(seconds: 60));
      }
      if (!mounted) return;
      _refresh(silent: true, refreshProfile: false);
    });
  }

  String? _messageIfRealError(Map<String, dynamic> res, String fallback) {
    if (ApiService.isTransientFailure(res)) return null;
    return res['message']?.toString() ?? fallback;
  }

  Future<void> _loadPublicConfig() async {
    await ClientConfigCache.get();
    if (!mounted) return;
    setState(() => _googleMapsWebKey = ClientConfigCache.googleMapsWebKey());
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
    final minGap = available ? const Duration(seconds: 15) : const Duration(seconds: 45);
    if (!force && last != null && now.difference(last) < minGap) {
      return;
    }
    final token = await AuthStorage.getToken();
    if (token == null) return;
    _lastLocationPost = now;
    ApiService.postLocation(token, lat, lng);
  }

  Future<void> _touchPresence() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return;
    }
    await ApiService.touchPresence(token);
  }

  Future<void> _syncPush() async {
    Future<void>.microtask(() => PushSync.syncToken());
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
    unawaited(_refreshRequestsOnly(silent: true, forceNetwork: true));
  }

  void _onProfilesExternallyUpdated() {
    if (mounted) setState(() {});
    unawaited(_refreshRequestsOnly(silent: true, forceNetwork: true));
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
    WidgetsBinding.instance.removeObserver(this);
    AppNotificationHub.instance.removeListener(_onNotificationsChanged);
    ProfileSignals.instance.removeListener(_onProfilesExternallyUpdated);
    LiveSync.instance.removeListener(_onLiveSync);
    _refreshTimer?.cancel();
    _presenceTimer?.cancel();
    _liveSyncDebounce?.cancel();
    _positionSub?.cancel();
    _requestSearchCtrl.dispose();
    super.dispose();
  }

  int get _pendingIncomingCount {
    return requests.where((raw) => (raw is Map ? raw['status'] : null)?.toString() == 'pending').length;
  }

  int get _acceptedCount {
    return requests.where((raw) => (raw is Map ? raw['status'] : null)?.toString() == 'accepted').length;
  }

  /// Demandes encore en cours (carte + compteurs).
  List<dynamic> get _activeRequests {
    return requests.where((raw) {
      final s = (raw is Map ? raw['status'] : null)?.toString();
      return s == 'pending' || s == 'accepted';
    }).toList();
  }

  List<dynamic> get _requestsForStatusFilter {
    if (_requestStatusFilter == null) return requests;
    return requests.where((raw) {
      final s = (raw is Map ? raw['status'] : null)?.toString();
      return s == _requestStatusFilter;
    }).toList();
  }

  int get _completedThisMonth {
    final now = DateTime.now();
    return requests.where((raw) {
      if (raw is! Map) return false;
      if (raw['status']?.toString() != 'completed') return false;
      final at = raw['completed_at']?.toString() ?? raw['updated_at']?.toString();
      if (at == null || at.isEmpty) return true;
      final d = DateTime.tryParse(at);
      if (d == null) return true;
      return d.year == now.year && d.month == now.month;
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
    return _requestsForStatusFilter.where((raw) {
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
    for (final raw in _activeRequests) {
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
    await ApiDataCache.clear();
    ApiResponseCache.clear();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _refresh({bool silent = false, bool refreshProfile = true}) async {
    await _refreshCoordinator.run(() => _refreshBody(silent: silent, refreshProfile: refreshProfile));
  }

  Future<void> _refreshRequestsOnly({bool silent = true, bool forceNetwork = false}) async {
    final now = DateTime.now();
    if (!forceNetwork &&
        _lastRequestsFetch != null &&
        now.difference(_lastRequestsFetch!) < const Duration(seconds: 4)) {
      return;
    }
    await _refreshCoordinator.run(() async {
      final token = await AuthStorage.getToken();
      if (token == null) return;
      _lastRequestsFetch = DateTime.now();
      final reqs = await ApiService.listRequests(token, force: forceNetwork);
      if (!mounted) return;
      final rs = reqs['status'] as int?;
      if (rs != null && rs >= 200 && rs < 300 && reqs['data'] is List) {
        final changed = _applyRequestsList(List<dynamic>.from(reqs['data'] as List));
        if (changed) {
          unawaited(ApiDataCache.saveRequests(requests, mechanic: true));
          final nextSig = _clientAvatarSignature();
          if (nextSig != _cachedClientAvatarSig) {
            _cachedClientAvatarSig = nextSig;
            _clientAvatarEpoch++;
          }
          setState(() {
            loading = false;
            lastError = null;
          });
        }
      } else if (!ApiService.isTransientFailure(reqs)) {
        setState(() {
          lastError = _messageIfRealError(reqs, 'Impossible de charger les demandes (${reqs['status']}).');
        });
      }
    });
  }

  Future<void> _refreshBody({bool silent = false, bool refreshProfile = true}) async {
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
      if (!ApiService.isServerWarm) {
        await ApiService.ensureBackendReady(
          maxWait: kIsWeb ? const Duration(seconds: 60) : const Duration(seconds: 25),
        );
      }
      final results = await Future.wait<dynamic>([
        refreshProfile ? ApiService.getMe(token) : Future<Map<String, dynamic>>.value({}),
        ApiService.listRequests(token, force: true),
      ]);
      final me = results[0] as Map<String, dynamic>;
      final reqs = results[1] as Map<String, dynamic>;

      final ms = me['status'] as int?;
      if (refreshProfile && ms != null && ms >= 200 && ms < 300) {
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
      } else if (!ApiService.isTransientFailure(me)) {
        errorMsg = _messageIfRealError(me, 'Session invalide (${me['status']}).');
      } else {
        _scheduleSilentRetry();
      }

      final rs = reqs['status'] as int?;
      if (rs != null && rs >= 200 && rs < 300 && reqs['data'] is List) {
        _applyRequestsList(List<dynamic>.from(reqs['data'] as List));
        _lastRequestsFetch = DateTime.now();
        unawaited(ApiDataCache.saveRequests(requests, mechanic: true));
      } else if (!ApiService.isTransientFailure(reqs)) {
        requests = [];
        errorMsg ??= _messageIfRealError(reqs, 'Impossible de charger les demandes (${reqs['status']}).');
      } else {
        _scheduleSilentRetry();
      }
    } catch (_) {
      if (requests.isEmpty) _scheduleSilentRetry();
    }

    if (!mounted) return;
    final nextSig = _clientAvatarSignature();
    if (nextSig != _cachedClientAvatarSig) {
      _cachedClientAvatarSig = nextSig;
      _clientAvatarEpoch++;
    }
    setState(() {
      loading = false;
      if (errorMsg != null &&
          requests.isEmpty &&
          ApiService.isTransientFailure({'status': 0, 'message': errorMsg})) {
        lastError = null;
      } else {
        lastError = errorMsg;
      }
    });
  }

  Future<void> _publishLocationForDiscovery() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    if (lat != null && lng != null) {
      await ApiService.updateLocation(token, lat!, lng!);
      await ApiService.touchPresence(token);
      return;
    }
    if (!await _ensureLocationPermission()) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));
      _applyCoords(pos.latitude, pos.longitude);
      await ApiService.updateLocation(token, pos.latitude, pos.longitude);
      await ApiService.touchPresence(token);
    } catch (_) {}
  }

  Future<void> _setAvailability(bool value) async {
    if (_availabilityBusy) return;
    final token = await AuthStorage.getToken();
    if (token == null) return;
    final previous = available;
    setState(() {
      _availabilityBusy = true;
      available = value;
    });
    final res = await ApiService.updateMechanicAvailability(token, value);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      setState(() {
        available = previous;
        _availabilityBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Erreur disponibilité')),
      );
      return;
    }
    if (value) {
      await _publishLocationForDiscovery();
    } else {
      unawaited(ApiService.touchPresence(token));
    }
    if (!mounted) return;
    setState(() => _availabilityBusy = false);
    _scheduleRefreshTimer();
    _schedulePresenceTimer();
  }

  Future<void> _processRequest(int id, bool accept, Map<String, dynamic> request) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    _patchRequestStatusLocally(id, accept ? 'accepted' : 'declined');
    if (mounted) setState(() {});
    final res = accept ? await ApiService.acceptRequest(token, id) : await ApiService.declineRequest(token, id);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.userFacingMessage(res, fallback: 'Action impossible'))),
      );
      await _refreshRequestsOnly(silent: true, forceNetwork: true);
      return;
    }
    if (accept) {
      setState(() => _requestStatusFilter = 'accepted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande acceptée — client visible sur la carte.')),
      );
    } else {
      setState(() => _requestStatusFilter = null);
    }
    await _refreshRequestsOnly(silent: true, forceNetwork: true);
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

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final mapTab = _tabIndex == 0;
    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: FeuTheme.charcoal.withValues(alpha: 0.08)),
          ),
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: FeuTheme.pageGrey,
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: FeuTheme.deepBlue),
                  title: const Text('Mon profil'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _tabIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined, color: FeuTheme.deepBlue),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    _openNotifications();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: FeuTheme.deepBlue),
                  title: const Text('Aide'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HelpScreen()));
                  },
                ),
              ],
            ),
          ),
        ),
        appBar: mapTab
            ? null
            : MechAssistLightAppBar(
                onMenu: _openDrawer,
                onProfile: () => setState(() => _tabIndex = 2),
                profileInitial: currentName,
                profileAvatarUrl: _myAvatarUrl,
                profileAvatarCacheEpoch: _myAvatarCacheEpoch,
                actions: [
                  IconButton(
                    onPressed: _openNotifications,
                    icon: Badge(
                      isLabelVisible: AppNotificationHub.instance.unreadCount > 0,
                      label: Text('${AppNotificationHub.instance.unreadCount}'),
                      child: const Icon(Icons.notifications_outlined, color: FeuTheme.deepBlue),
                    ),
                  ),
                ],
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
        bottomNavigationBar: MechAssistBottomNav(
          variant: MechAssistNavVariant.mechanic,
          currentIndex: _tabIndex,
          badges: {
            if (_pendingIncomingCount + _acceptedCount > 0)
              0: _pendingIncomingCount + _acceptedCount,
          },
          onTap: (i) => setState(() => _tabIndex = i),
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
          onTap: () => setState(() => _requestStatusFilter = e.$1),
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

  void _openRequestPhoto(String url, {String? title}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FullScreenImagePage(imageUrl: url, title: title ?? 'Photo de la panne'),
      ),
    );
  }

  void _showMechanicRequestDetail(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString().trim();
    final id = ApiService.parseIntId(r['id']);
    final rawPhoto = r['photo_url']?.toString();
    final hasPhoto = rawPhoto != null && rawPhoto.trim().isNotEmpty;
    final client = r['client'];
    String? clientPhone;
    if (client is Map) {
      clientPhone = client['phone']?.toString();
    }
    final canDial = normalizePhoneForDial(clientPhone) != null;
    final canAct = status == 'pending';
    final canMarkDone = status == 'accepted' &&
        (r['mechanic_completed_at'] == null ||
            r['mechanic_completed_at'].toString().trim().isEmpty ||
            r['mechanic_completed_at'].toString() == 'null');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Demande #${id ?? '—'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (client is Map)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    name: client['name']?.toString() ?? 'C',
                    avatarUrl: client['avatar_url']?.toString(),
                    cacheEpoch: _clientAvatarCacheEpoch,
                    radius: 24,
                  ),
                  title: Text(client['name']?.toString() ?? 'Client'),
                  subtitle: Text(client['phone']?.toString() ?? ''),
                ),
              Text('Véhicule : ${r['vehicle_type'] ?? '—'}'),
              const SizedBox(height: 6),
              Text('Statut : $status'),
              const SizedBox(height: 8),
              Text(r['description']?.toString() ?? ''),
              if (hasPhoto) ...[
                const SizedBox(height: 12),
                Text('Photo de la panne', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openRequestPhoto(rawPhoto);
                  },
                  child: PublicNetworkImage(
                    url: rawPhoto,
                    width: double.infinity,
                    height: 200,
                    borderRadius: BorderRadius.circular(12),
                    icon: Icons.broken_image_outlined,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openRequestPhoto(rawPhoto);
                  },
                  icon: const Icon(Icons.zoom_in_rounded),
                  label: const Text('Agrandir la photo'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          if (canDial && (status == 'pending' || status == 'accepted'))
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                launchTelDialer(context, clientPhone);
              },
              icon: const Icon(Icons.call_rounded),
              label: const Text('Appeler'),
            ),
          if (canAct && id != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processRequest(id, true, r);
              },
              child: const Text('Accepter'),
            ),
          if (status == 'accepted' && id != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openChat(id);
              },
              child: const Text('Chat'),
            ),
          if (canMarkDone && id != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _markMechanicComplete(id);
              },
              child: const Text('Terminée'),
            ),
        ],
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
                  GestureDetector(
                    onTap: () => _openRequestPhoto(rawPhoto),
                    child: Stack(
                      children: [
                        PublicNetworkImage(
                          url: rawPhoto,
                          width: 72,
                          height: 72,
                          borderRadius: BorderRadius.circular(10),
                          icon: Icons.broken_image_outlined,
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
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
                      TextButton(
                        onPressed: () => _showMechanicRequestDetail(r),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          hasPhoto ? 'Voir détail et photo' : 'Voir le détail',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: FeuTheme.deepBlue),
                        ),
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
    final bottomInset = kBottomNavigationBarHeight + MediaQuery.paddingOf(context).bottom + 12;
    return MapsDiscoveryShell(
      map: _buildMechanicMapLayer(),
      loading: loading,
      bottomInset: bottomInset,
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
      onMenuTap: _openDrawer,
      sheetTitle: 'Zone d\'intervention',
      sheetSubtitle: lat != null
          ? '${_activeRequests.length} intervention(s) active(s) · ${_jobSitesForMap().length} sur la carte'
          : 'GPS requis',
      subtitleAccent: available && lat != null,
      onSheetRefresh: _refresh,
      sheetHeaderExtra: MechanicStatsHeader(
        isOnline: available,
        onOnlineChanged: _availabilityBusy ? (_) {} : _setAvailability,
        completedThisMonth: _completedThisMonth,
        pendingCount: _pendingIncomingCount,
      ),
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
                      'GPS actif · ${_activeRequests.length} intervention(s) · ${_jobSitesForMap().length} point(s) carte',
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
                    : _requestStatusFilter == 'pending' && _acceptedCount > 0
                        ? 'Aucune en attente. $_acceptedCount acceptée(s) — onglet « Acceptées ».'
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
          onChanged: _availabilityBusy ? null : _setAvailability,
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