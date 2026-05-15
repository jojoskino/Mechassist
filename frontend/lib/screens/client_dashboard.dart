import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/app_notification_hub.dart';
import '../services/profile_signals.dart';
import '../services/push_service.dart';
import '../theme/feu_theme.dart';
import '../utils/gps_helper.dart';
import '../utils/list_search.dart';
import '../utils/phone_launch.dart';
import '../widgets/dashboard_search_bar.dart';
import '../widgets/create_request_sheet.dart';
import '../widgets/maps_discovery_shell.dart';
import '../widgets/mechanic_nearby_map.dart';
import '../widgets/public_network_image.dart';
import '../widgets/request_list_tile.dart';
import '../widgets/mechanic_info_card.dart';
import '../screens/user_profile_page.dart';
import '../utils/online_status.dart';
import '../utils/profile_navigation.dart';
import '../widgets/user_avatar.dart';
import '../screens/history_screen.dart';
import '../screens/notifications_panel.dart';
import '../widgets/dashboard_brand_bar.dart';
import '../utils/recent_addresses.dart';

class DashboardClient extends StatefulWidget {
  const DashboardClient({super.key, this.initialTabIndex = 0});

  /// Onglet initial (0 = Carte, 1 = Demandes, 2 = Historique).
  final int initialTabIndex;

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
  String? _myAvatarUrl;
  int? _myAvatarCacheEpoch;
  /// Incrémenté quand l’API renvoie des URLs d’avatars distantes différentes (évite le cache navigateur).
  int _remoteAvatarEpoch = 0;
  String _cachedRemoteAvatarSig = '';
  late int _tabIndex;
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionSub;
  DateTime? _lastLocationPost;
  String? lastError;
  String? _googleMapsWebKey;
  /// Rayon recherche (km), défaut 5 comme dans le cahier d’analyse.
  double _searchRadiusKm = 5;
  int _minStarsFilter = 0;
  final TextEditingController _specialtyFilterCtrl = TextEditingController();
  final TextEditingController _mechanicKeywordCtrl = TextEditingController();
  final TextEditingController _requestSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 2);
    WidgetsBinding.instance.addObserver(this);
    AppNotificationHub.instance.addListener(_onNotificationsChanged);
    ProfileSignals.instance.addListener(_onProfilesExternallyUpdated);
    _mechanicKeywordCtrl.addListener(_onMechanicSearchChanged);
    _loadPublicConfig();
    _refreshAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshListsOnly());
    _syncPush();
    _startPositionTracking();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _onProfilesExternallyUpdated() {
    if (mounted) setState(() {});
    _refreshAll(silent: true, requireFreshGps: false);
  }

  int get _peerAvatarCacheEpoch => Object.hash(_remoteAvatarEpoch, ProfileSignals.instance.generation);

  String _remoteAvatarSignature() {
    final parts = <String>[];
    for (final m in _apiMechanics) {
      parts.add(m['avatar_url']?.toString() ?? '');
    }
    for (final raw in requests) {
      if (raw is! Map) continue;
      final r = Map<String, dynamic>.from(raw);
      final mech = _mechanicFromRequest(r);
      if (mech != null) parts.add(mech['avatar_url']?.toString() ?? '');
    }
    return parts.join('\x1e');
  }

  void _onMechanicSearchChanged() {
    if (mounted) setState(() {});
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

  /// Liste issue uniquement de l’API (PostgreSQL) — rafraîchie au pull, au timer et au GPS.
  void _recomputeMergedMechanics() {
    mechanics = List<dynamic>.from(_apiMechanics);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _positionSub?.cancel();
    _specialtyFilterCtrl.dispose();
    _mechanicKeywordCtrl.dispose();
    _requestSearchCtrl.dispose();
    AppNotificationHub.instance.removeListener(_onNotificationsChanged);
    ProfileSignals.instance.removeListener(_onProfilesExternallyUpdated);
    _mechanicKeywordCtrl.removeListener(_onMechanicSearchChanged);
    super.dispose();
  }

  List<dynamic> get _displayMechanics {
    final q = _mechanicKeywordCtrl.text;
    return mechanics.where((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return matchesListSearch(q, [
        m['name']?.toString(),
        m['mechanic_specialty']?.toString(),
        m['phone']?.toString(),
      ]);
    }).toList();
  }

  int get _pendingRequestsCount {
    return requests.where((raw) {
      final s = (raw is Map ? raw['status'] : null)?.toString();
      return s == 'pending' || s == 'accepted';
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
      final r = Map<String, dynamic>.from(raw as Map);
      return matchesListSearch(q, [
        r['vehicle_type']?.toString(),
        r['description']?.toString(),
        r['status']?.toString(),
        _mechanicNameFromRequest(r),
        r['id']?.toString(),
      ]);
    }).toList();
  }

  /// Rafraîchit mécaniciens + demandes en réutilisant la position déjà connue (rapide).
  Future<void> _refreshListsOnly() async {
    await _refreshAll(silent: true, requireFreshGps: false);
  }

  Future<void> _refreshAll({bool silent = false, bool requireFreshGps = true}) async {
    if (!silent && _initializing) {
      setState(() => loading = true);
    }
    final session = await AuthStorage.getSessionFields();
    final token = session['token'];
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _initializing = false;
        lastError = 'Session invalide, reconnecte-toi.';
      });
      return;
    }
    currentName = session['name'] ?? 'Client';
    currentRole = session['role'] ?? 'client';
    final me = await ApiService.getMe(token);
    final ms = me['status'] as int?;
    if (ms != null && ms >= 200 && ms < 300) {
      _myAvatarUrl = me['avatar_url']?.toString();
      _myAvatarCacheEpoch = DateTime.now().millisecondsSinceEpoch;
    }

    String? errorMsg;
    try {
      final reuseCoords = lat != null && lng != null && !requireFreshGps;

      late final Map<String, dynamic> reqRes;
      if (reuseCoords) {
        reqRes = await ApiService.listRequests(token);
      } else {
        final parallel = await Future.wait<dynamic>([
          _getPositionBestEffort(),
          ApiService.listRequests(token),
        ]);
        final position = parallel[0] as Position?;
        reqRes = parallel[1] as Map<String, dynamic>;
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      }

      if (lat != null && lng != null) {
        if (requireFreshGps || _lastLocationPost == null) {
          final locFut = ApiService.updateLocation(token, lat!, lng!);
          final minR = _minStarsFilter > 0 ? _minStarsFilter.toDouble() : null;
          final spec = _specialtyFilterCtrl.text.trim();
          final nearbyFut = ApiService.nearbyMechanics(
            token,
            lat!,
            lng!,
            radiusKm: _searchRadiusKm,
            minRating: minR,
            specialty: spec.isEmpty ? null : spec,
          );
          final pair = await Future.wait([locFut, nearbyFut]);
          final loc = pair[0];
          final nearby = pair[1];
          if ((loc['status'] as int?) != null && (loc['status'] as int) >= 400) {
            errorMsg = loc['message']?.toString() ?? 'Erreur mise à jour position.';
          } else {
            _lastLocationPost = DateTime.now();
          }
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
        } else {
          final minR = _minStarsFilter > 0 ? _minStarsFilter.toDouble() : null;
          final spec = _specialtyFilterCtrl.text.trim();
          final nearby = await ApiService.nearbyMechanics(
            token,
            lat!,
            lng!,
            radiusKm: _searchRadiusKm,
            minRating: minR,
            specialty: spec.isEmpty ? null : spec,
          );
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

      final rs = reqRes['status'] as int?;
      if (rs != null && rs >= 200 && rs < 300 && reqRes['data'] is List) {
        requests = reqRes['data'] as List;
      } else {
        requests = [];
        errorMsg ??= reqRes['message']?.toString() ?? 'Impossible de charger tes demandes (code ${reqRes['status']}).';
      }
    } catch (_) {
      errorMsg ??= 'Impossible de charger les données. Vérifie ta connexion.';
    }

    if (!mounted) return;
    final nextSig = _remoteAvatarSignature();
    if (nextSig != _cachedRemoteAvatarSig) {
      _cachedRemoteAvatarSig = nextSig;
      _remoteAvatarEpoch++;
    }
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
  Future<Position?> _getPositionBestEffort() => GpsHelper.bestPosition();

  Future<void> _recenterMap() async {
    final pos = await GpsHelper.bestPosition();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      await _refreshAll(silent: false, requireFreshGps: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position mise à jour.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('GPS indisponible. Active la localisation du téléphone.'),
        action: SnackBarAction(
          label: 'Réglages',
          onPressed: () => GpsHelper.openSettingsIfNeeded(),
        ),
      ),
    );
  }

  Future<void> _createRequest(Map<String, dynamic> mechanic) async {
    if (_sendingRequest) {
      return;
    }

    setState(() => _sendingRequest = true);
    final pos = await GpsHelper.bestPosition();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      final token = await AuthStorage.getToken();
      if (token != null) {
        await ApiService.updateLocation(token, pos.latitude, pos.longitude);
      }
    }
    if (!mounted) return;
    setState(() => _sendingRequest = false);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Position requise pour signaler une panne. Active le GPS.'),
          action: SnackBarAction(
            label: 'Réglages',
            onPressed: () => GpsHelper.openSettingsIfNeeded(),
          ),
        ),
      );
      return;
    }

    final recent = await RecentAddresses.load();
    if (!mounted) return;
    final result = await CreateRequestSheet.show(
      context,
      mechanicName: mechanic['name']?.toString() ?? 'mécanicien',
      pickupLabel: _pickupLabel(),
      recentAddresses: recent,
      onRefreshLocation: _refreshLocationForRequest,
    );

    try {
      if (result == null) {
        return;
      }
      final token = await AuthStorage.getToken();
      if (token == null) {
        return;
      }

      final mechanicId = ApiService.parseIntId(mechanic['id']);
      if (mechanicId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mécanicien invalide.')));
        return;
      }
      final desc = result.description;
      final vehicleType = result.vehicleType;

      Uint8List? photoBytes;
      String? photoFilename;
      if (result.photo != null) {
        try {
          photoBytes = await result.photo!.readAsBytes();
          photoFilename = result.photo!.name;
        } catch (_) {
          photoBytes = null;
          photoFilename = null;
        }
      }

      final addr = result.address?.trim() ?? '';
      setState(() => _sendingRequest = true);
      final res = await ApiService.createRequest(
        token: token,
        mechanicId: mechanicId,
        vehicleType: vehicleType,
        description: desc,
        clientLat: lat!,
        clientLng: lng!,
        clientAddress: addr.isEmpty ? null : addr,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );

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
        final addr = result.address?.trim();
        if (addr != null && addr.isNotEmpty) {
          await RecentAddresses.add(addr);
        }
        await _refreshAll(silent: true, requireFreshGps: false);
        if (mounted) {
          setState(() => _tabIndex = 1);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _sendingRequest = false);
      }
    }
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

  Future<void> _openChat(int requestId) async {
    if (!mounted) return;
    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;
    await Navigator.pushNamed(context, '/intervention-chat', arguments: requestId);
  }

  bool _requestNeedsRating(Map<String, dynamic> r) {
    if (r['status']?.toString() != 'completed') return false;
    final rt = r['rating'];
    if (rt == null) return true;
    if (rt is Map && rt['stars'] == null) return true;
    return false;
  }

  String _mechanicRatingLine(Map<String, dynamic> m) {
    final avg = m['rating_avg'];
    final cnt = m['rating_count'];
    if (avg == null) return '';
    final n = cnt is int ? cnt : (cnt is num ? cnt.toInt() : int.tryParse(cnt.toString()) ?? 0);
    if (n <= 0) return '';
    final a = avg is num ? avg.toDouble() : double.tryParse(avg.toString());
    if (a == null) return '';
    return ' · ${a.toStringAsFixed(1)}★ ($n avis)';
  }

  bool _mechanicMarkedComplete(Map<String, dynamic> r) {
    final v = r['mechanic_completed_at'];
    if (v == null) return false;
    final s = v.toString();
    return s.isNotEmpty && s != 'null';
  }

  String _outcomeLabelFr(dynamic outcome) {
    if (outcome == 'fixed') return 'Panne réglée';
    if (outcome == 'not_fixed') return 'Panne non réglée';
    return outcome?.toString() ?? '—';
  }

  String _requestStatusLine(Map<String, dynamic> r) {
    switch (r['status']?.toString()) {
      case 'pending':
        return 'En attente de réponse';
      case 'accepted':
        if (!_mechanicMarkedComplete(r)) {
          return 'Acceptée — attente fin d’intervention (mécanicien)';
        }
        return 'Acceptée — chat · clôture possible';
      case 'declined':
        return 'Refusée';
      case 'cancelled':
        return 'Annulée par toi';
      case 'completed':
        final o = _outcomeLabelFr(r['outcome']);
        final rt = r['rating'];
        final hasRating = rt is Map && rt['stars'] != null;
        return 'Terminée ($o)${hasRating ? ' · ${rt['stars']}/5 ★' : ''}';
      default:
        return 'Statut : ${r['status']}';
    }
  }

  Color _requestStatusColor(String? status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade600;
      case 'pending':
        return FeuTheme.ember;
      case 'declined':
      case 'cancelled':
        return Colors.red.shade600;
      case 'completed':
        return Colors.grey.shade600;
      default:
        return FeuTheme.deepBlue;
    }
  }

  String? _requestTimeLabel(Map<String, dynamic> r) {
    final raw = r['created_at']?.toString() ?? r['updated_at']?.toString();
    if (raw == null || raw.length < 16) return null;
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length >= 16 ? raw.substring(11, 16) : null;
    }
  }

  Future<void> _promptCancelRequest(int requestId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text(
          'Le mécanicien n’a pas encore répondu. Tu pourras envoyer une nouvelle demande ensuite.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FeuTheme.ember),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = await AuthStorage.getToken();
    if (token == null || !mounted) return;
    final res = await ApiService.cancelClientRequest(token, requestId);
    if (!mounted) return;
    final code = res['status'] as int?;
    final success = code != null && code >= 200 && code < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Demande annulée.' : (res['message']?.toString() ?? 'Erreur')),
        backgroundColor: success ? null : Colors.red.shade800,
      ),
    );
    if (success) await _refreshAll(silent: true, requireFreshGps: false);
  }

  Future<void> _promptCloseIntervention(int requestId) async {
    final outcome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer l’intervention'),
        content: const Text('La panne a-t-elle été réglée ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'not_fixed'), child: const Text('Non réglée')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'fixed'),
            child: const Text('Oui, réglée'),
          ),
        ],
      ),
    );
    if (outcome == null || !mounted) return;
    final token = await AuthStorage.getToken();
    if (token == null || !mounted) return;
    final res = await ApiService.recordRequestOutcome(token, requestId, outcome);
    if (!mounted) return;
    final ok = (res['status'] as int?) != null && (res['status'] as int) >= 200 && (res['status'] as int) < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Intervention clôturée.' : (res['message']?.toString() ?? 'Erreur')),
        backgroundColor: ok ? null : Colors.red.shade800,
      ),
    );
    if (ok) await _refreshAll(silent: true, requireFreshGps: false);
  }

  Future<void> _promptRateMechanic(int requestId) async {
    var stars = 5;
    final commentCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Noter le mécanicien'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Ton appréciation'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final v = i + 1;
                    return IconButton(
                      onPressed: () => setSt(() => stars = v),
                      icon: Icon(
                        v <= stars ? Icons.star : Icons.star_border,
                        size: 36,
                        color: Colors.amber.shade700,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: commentCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Commentaire (optionnel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
          ],
        ),
      ),
    );
    final commentText = commentCtrl.text;
    commentCtrl.dispose();
    if (confirmed != true || !mounted) return;
    final token = await AuthStorage.getToken();
    if (token == null || !mounted) return;
    final res = await ApiService.rateMechanicForRequest(
      token,
      requestId,
      stars: stars,
      comment: commentText.trim().isEmpty ? null : commentText.trim(),
    );
    if (!mounted) return;
    final code = res['status'] as int?;
    final ok = code != null && code >= 200 && code < 300;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Merci pour ta note !' : (res['message']?.toString() ?? 'Erreur')),
        backgroundColor: ok ? null : Colors.red.shade800,
      ),
    );
    if (ok) await _refreshAll(silent: true, requireFreshGps: false);
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
        onOpenRequests: () => setState(() => _tabIndex = 1),
        trailing: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: _initializing && loading && _tabIndex == 0
          ? const Center(child: CircularProgressIndicator(color: FeuTheme.ember))
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(),
                _buildRequestsTab(),
                HistoryScreen(
                  requests: requests,
                  onRefresh: () => _refreshAll(silent: true, requireFreshGps: false),
                  mechanicNameFor: _mechanicNameFromRequest,
                  onOpenRequest: _showRequestDetail,
                ),
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
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Demandes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
        ],
      ),
    ),
    );
  }

  void _cycleSearchRadius() {
    setState(() {
      if (_searchRadiusKm < 5) {
        _searchRadiusKm = 5;
      } else if (_searchRadiusKm < 10) {
        _searchRadiusKm = 10;
      } else if (_searchRadiusKm < 20) {
        _searchRadiusKm = 20;
      } else {
        _searchRadiusKm = 50;
      }
    });
    _refreshAll(silent: true, requireFreshGps: false);
  }

  void _cycleMinStars() {
    setState(() {
      if (_minStarsFilter == 0) {
        _minStarsFilter = 3;
      } else if (_minStarsFilter == 3) {
        _minStarsFilter = 4;
      } else if (_minStarsFilter == 4) {
        _minStarsFilter = 5;
      } else {
        _minStarsFilter = 0;
      }
    });
    _refreshAll(silent: true, requireFreshGps: false);
  }

  List<Widget> _clientFilterChips() {
    return [
      MapsFilterChip(
        label: 'Toutes',
        icon: Icons.grid_view_rounded,
        selected: _minStarsFilter == 0 && _specialtyFilterCtrl.text.trim().isEmpty,
        onTap: () {
          setState(() {
            _minStarsFilter = 0;
            _specialtyFilterCtrl.clear();
            _mechanicKeywordCtrl.clear();
          });
          _refreshAll(silent: true, requireFreshGps: false);
        },
      ),
      MapsFilterChip(
        label: '${_searchRadiusKm.round()} km',
        icon: Icons.radar_rounded,
        onTap: _cycleSearchRadius,
      ),
      MapsFilterChip(
        label: _minStarsFilter == 0 ? 'Toutes notes' : '$_minStarsFilter★+',
        icon: Icons.star_rounded,
        onTap: _cycleMinStars,
      ),
      MapsFilterChip(
        label: 'Spécialité',
        icon: Icons.build_rounded,
        onTap: () => _showSpecialtyFilterSheet(),
      ),
    ];
  }

  void _showSpecialtyFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _specialtyFilterCtrl,
              decoration: const InputDecoration(
                labelText: 'Spécialité',
                hintText: 'Ex. moteur, pneu…',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _refreshAll(silent: true, requireFreshGps: false);
              },
              style: FilledButton.styleFrom(backgroundColor: FeuTheme.ember),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientMapLayer() {
    if (lat != null && lng != null) {
      return MechanicNearbyMap(
        clientLat: lat!,
        clientLng: lng!,
        mechanics: _displayMechanics.map((m) => Map<String, dynamic>.from(m as Map)).toList(),
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
              Text(
                'Active la localisation pour afficher la carte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _refreshAll(silent: false, requireFreshGps: true),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Activer le GPS'),
                style: FilledButton.styleFrom(backgroundColor: FeuTheme.deepBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMechanicProfile(Map<String, dynamic> m) {
    final user = Map<String, dynamic>.from(m);
    user['role'] = 'mecanicien';
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          user: user,
          subtitle: m['distance_km'] != null ? '${m['distance_km']} km' : null,
          onMessage: null,
        ),
      ),
    );
  }

  Widget _buildMechanicResultTile(Map<String, dynamic> m) {
    final phoneRaw = m['phone']?.toString();
    final canDial = normalizePhoneForDial(phoneRaw) != null;
    final name = m['name']?.toString() ?? 'Mécanicien';
    final online = userIsOnline(m);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: () => _openMechanicProfile(m),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(
                  name: name,
                  avatarUrl: m['avatar_url']?.toString(),
                  cacheEpoch: _peerAvatarCacheEpoch,
                  radius: 26,
                  showOnline: true,
                  isOnline: online,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
              ],
            ),
            if (m['mechanic_specialty'] != null && m['mechanic_specialty'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                m['mechanic_specialty'].toString(),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${m['distance_km']} km'
              '${online ? ' · En ligne' : ''}'
              '${_mechanicRatingLine(m)}',
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!canDial || _sendingRequest) ? null : () => launchTelDialer(context, phoneRaw),
                    icon: const Icon(Icons.call_rounded, size: 20),
                    label: const Text('Appeler'),
                    style: OutlinedButton.styleFrom(foregroundColor: FeuTheme.ember),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _sendingRequest ? null : () => _createRequest(m),
                    style: FilledButton.styleFrom(backgroundColor: FeuTheme.ember),
                    child: _sendingRequest
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Demander'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return MapsDiscoveryShell(
      map: _buildClientMapLayer(),
      loading: loading,
      searchController: _mechanicKeywordCtrl,
      searchHint: 'Mécaniciens, spécialité…',
      onSearch: () => setState(() {}),
      onRecenter: _recenterMap,
      onPrimaryFab: () => _refreshAll(silent: true, requireFreshGps: false),
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
          });
          if (parsed.updated) {
            await _refreshAll(silent: true, requireFreshGps: false);
          }
        }
      },
      filterChips: _clientFilterChips(),
      sheetTitle: 'Mécaniciens proches',
      sheetSubtitle: lat == null
          ? 'Localisation requise'
          : '${_displayMechanics.length} résultat(s) · rayon ${_searchRadiusKm.round()} km',
      topBanner: lastError != null
          ? Material(
              color: Colors.red.shade50,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(lastError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.red),
                  onPressed: () => _refreshAll(silent: false, requireFreshGps: false),
                ),
              ),
            )
          : null,
      onSheetRefresh: () => _refreshAll(silent: false, requireFreshGps: true),
      buildSheetBody: () {
        return [
          if (_displayMechanics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                mechanics.isEmpty
                    ? 'Aucun mécanicien dans cette zone. Élargis le rayon ou réessaie.'
                    : 'Aucun résultat pour cette recherche.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ),
          ..._displayMechanics.map((raw) => _buildMechanicResultTile(Map<String, dynamic>.from(raw as Map))),
          if (kIsWeb && _showWebMapHint)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Carte web', style: TextStyle(fontSize: 14)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _showWebMapHint = false),
              ),
            ),
        ];
      },
    );
  }

  String _mechanicNameFromRequest(Map<String, dynamic> r) {
    final m = r['mechanic'];
    if (m is Map) {
      return m['name']?.toString() ?? '—';
    }
    return '—';
  }

  Map<String, dynamic>? _mechanicFromRequest(Map<String, dynamic> r) {
    final m = r['mechanic'];
    if (m is Map) return Map<String, dynamic>.from(m);
    return null;
  }

  Map<String, dynamic>? _activeAcceptedRequest() {
    for (final raw in requests) {
      final r = Map<String, dynamic>.from(raw as Map);
      if (r['status']?.toString() == 'accepted') return r;
    }
    return null;
  }

  String _pickupLabel() {
    if (lat == null || lng == null) return 'Position en cours…';
    return 'Ma position · ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
  }

  Future<String?> _refreshLocationForRequest() async {
    final pos = await GpsHelper.bestPosition();
    if (pos == null || !mounted) return null;
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
    });
    final token = await AuthStorage.getToken();
    if (token != null) {
      await ApiService.updateLocation(token, pos.latitude, pos.longitude);
    }
    return _pickupLabel();
  }

  void _showRequestDetail(Map<String, dynamic> r) {
    final id = ApiService.parseIntId(r['id']);
    final rt = r['rating'];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Demande #${id ?? '—'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_mechanicFromRequest(r) != null) ...[
                MechanicInfoCard(
                  name: _mechanicNameFromRequest(r),
                  phone: _mechanicFromRequest(r)!['phone']?.toString(),
                  specialty: _mechanicFromRequest(r)!['mechanic_specialty']?.toString(),
                  avatarUrl: _mechanicFromRequest(r)!['avatar_url']?.toString(),
                  avatarCacheEpoch: _peerAvatarCacheEpoch,
                  mechanicUser: _mechanicFromRequest(r),
                  isOnline: userIsOnline(_mechanicFromRequest(r)),
                  compact: true,
                  onCall: () => launchTelDialer(context, _mechanicFromRequest(r)!['phone']?.toString()),
                  onChat: id != null && r['status']?.toString() == 'accepted'
                      ? () {
                          Navigator.pop(ctx);
                          _openChat(id);
                        }
                      : null,
                ),
                const SizedBox(height: 8),
              ] else
                Text('Mécanicien : ${_mechanicNameFromRequest(r)}'),
              const SizedBox(height: 8),
              Text('Véhicule : ${r['vehicle_type'] ?? '—'}'),
              const SizedBox(height: 8),
              Text(_requestStatusLine(r)),
              if (r['status']?.toString() == 'completed' && r['outcome'] != null) ...[
                const SizedBox(height: 8),
                Text('Résultat : ${_outcomeLabelFr(r['outcome'])}'),
              ],
              if (rt is Map && rt['stars'] != null) ...[
                const SizedBox(height: 8),
                Text('Ta note : ${rt['stars']}/5 ★'),
                if (rt['comment'] != null && rt['comment'].toString().trim().isNotEmpty)
                  Text('« ${rt['comment']} »', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Text(r['description']?.toString() ?? ''),
              if (r['client_address'] != null && r['client_address'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Repère : ${r['client_address']}', style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              ],
              if (r['status']?.toString() == 'accepted' && !_mechanicMarkedComplete(r)) ...[
                const SizedBox(height: 8),
                Text(
                  'Le mécanicien doit marquer l’intervention comme terminée avant que tu puisses clôturer.',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                ),
              ],
              if (r['photo_url'] != null && r['photo_url'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                PublicNetworkImage(
                  url: r['photo_url'].toString(),
                  width: double.infinity,
                  height: 160,
                  borderRadius: BorderRadius.circular(8),
                  icon: Icons.broken_image_outlined,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          if (r['status']?.toString() == 'pending' && id != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _promptCancelRequest(id);
              },
              child: Text('Annuler la demande', style: TextStyle(color: Colors.red.shade800)),
            ),
          if (r['status']?.toString() == 'accepted' && id != null) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openChat(id);
              },
              child: const Text('Chat'),
            ),
            if (_mechanicMarkedComplete(r))
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _promptCloseIntervention(id);
                },
                child: const Text('Clôturer'),
              ),
          ],
          if (id != null && _requestNeedsRating(r))
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _promptRateMechanic(id);
              },
              child: const Text('Noter'),
            ),
        ],
      ),
    );
  }

  /// Évite un `Wrap` vide (erreur de layout) quand aucune action rapide.
  Widget? _buildRequestListTrailing(Map<String, dynamic> r, int? id) {
    final showChat = r['status']?.toString() == 'accepted' && id != null;
    final showRate = _requestNeedsRating(r) && id != null;
    final showCancel = r['status']?.toString() == 'pending' && id != null;
    if (!showChat && !showRate && !showCancel) {
      return const Icon(Icons.chevron_right);
    }
    return Wrap(
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showCancel)
          TextButton(
            onPressed: () => _promptCancelRequest(id),
            child: Text('Annuler', style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
          ),
        if (showChat)
          TextButton(
            onPressed: () => _openChat(id),
            child: const Text('Chat'),
          ),
        if (showRate)
          TextButton(
            onPressed: () => _promptRateMechanic(id),
            child: const Text('Noter'),
          ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final active = _activeAcceptedRequest();
    final mechanic = active != null ? _mechanicFromRequest(active) : null;
    final activeId = active != null ? ApiService.parseIntId(active['id']) : null;

    return RefreshIndicator(
      onRefresh: () => _refreshAll(silent: true, requireFreshGps: false),
      color: FeuTheme.ember,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Mes demandes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FeuTheme.charcoal,
              ),
            ),
          ),
          if (mechanic != null && activeId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MechanicInfoCard(
                name: mechanic['name']?.toString() ?? 'Mécanicien',
                phone: mechanic['phone']?.toString(),
                specialty: mechanic['mechanic_specialty']?.toString(),
                avatarUrl: mechanic['avatar_url']?.toString(),
                avatarCacheEpoch: _peerAvatarCacheEpoch,
                mechanicUser: mechanic,
                isOnline: userIsOnline(mechanic),
                onCall: () => launchTelDialer(context, mechanic['phone']?.toString()),
                onChat: () => _openChat(activeId),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DashboardSearchBar(
              controller: _requestSearchCtrl,
              hintText: 'Véhicule, mécanicien, statut…',
              loading: loading,
              onChanged: () => setState(() {}),
            ),
          ),
          if (_filteredRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    requests.isEmpty ? 'Aucune demande pour le moment' : 'Aucun résultat',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    requests.isEmpty
                        ? 'Envoie une demande depuis l’onglet Carte.'
                        : 'Modifie la recherche.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ..._filteredRequests.map((raw) {
            final r = Map<String, dynamic>.from(raw as Map);
            final id = ApiService.parseIntId(r['id']);
            final status = r['status']?.toString();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RequestListTile(
                  mechanicName: _mechanicNameFromRequest(r),
                  vehicleType: r['vehicle_type']?.toString() ?? '—',
                  preview: r['description']?.toString() ?? '—',
                  statusLine: _requestStatusLine(r),
                  statusColor: _requestStatusColor(status),
                  timeLabel: _requestTimeLabel(r),
                  onTap: () => _showRequestDetail(r),
                  trailing: _buildRequestListTrailing(r, id),
                ),
                Divider(height: 1, indent: 72, color: Colors.grey.shade200),
              ],
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}