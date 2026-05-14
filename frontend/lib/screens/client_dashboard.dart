import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_service.dart';
import '../theme/feu_theme.dart';
import '../utils/phone_launch.dart';
import '../widgets/mechanic_nearby_map.dart';

class DashboardClient extends StatefulWidget {
  const DashboardClient({super.key, this.initialTabIndex = 0});

  /// Onglet initial (0 = Proches, 1 = Demandes), ex. depuis une notification.
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

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 1);
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
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 6),
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
    final addressCtrl = TextEditingController();
    String vehicleType = 'voiture';
    XFile? pickedPhoto;
    final picker = ImagePicker();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: Text('Demande à ${mechanic['name']}'),
          content: Column(
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
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Adresse ou lieu-dit (optionnel)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Photo (optionnel)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final x = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 2048,
                        maxHeight: 2048,
                        imageQuality: 85,
                      );
                      if (x != null) {
                        setInnerState(() => pickedPhoto = x);
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galerie'),
                  ),
                  if (!kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 2048,
                          maxHeight: 2048,
                          imageQuality: 85,
                        );
                        if (x != null) {
                          setInnerState(() => pickedPhoto = x);
                        }
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Appareil photo'),
                    ),
                  if (pickedPhoto != null)
                    TextButton(
                      onPressed: () => setInnerState(() => pickedPhoto = null),
                      child: const Text('Retirer la photo'),
                    ),
                ],
              ),
              if (pickedPhoto != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    pickedPhoto!.name,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );

    try {
      if (confirmed != true) {
        return;
      }
      if (lat == null || lng == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position indisponible. Autorise la géolocalisation puis réessaie.')),
        );
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
      final desc = descCtrl.text.trim();
      if (desc.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoute une description de la panne.')));
        return;
      }

      Uint8List? photoBytes;
      String? photoFilename;
      if (pickedPhoto != null) {
        try {
          photoBytes = await pickedPhoto!.readAsBytes();
          photoFilename = pickedPhoto!.name;
        } catch (_) {
          photoBytes = null;
          photoFilename = null;
        }
      }

      final addr = addressCtrl.text.trim();
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
        await _refreshAll(silent: true, requireFreshGps: false);
        if (mounted) {
          setState(() => _tabIndex = 1);
        }
      }
    } finally {
      descCtrl.dispose();
      addressCtrl.dispose();
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
      appBar: FeuTheme.fireAppBar(
        title: 'MechAssist',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Mon profil',
            onPressed: () async {
              final changed = await Navigator.pushNamed(context, '/profile');
              if (!mounted) return;
              if (changed == true) {
                await _refreshAll(silent: true, requireFreshGps: false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aide',
            onPressed: () => Navigator.pushNamed(context, '/help'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshAll(silent: false, requireFreshGps: true),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _confirmLogout(context),
          )
        ],
      ),
      body: _initializing && loading
          ? const Center(child: CircularProgressIndicator(color: FeuTheme.ember))
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
        backgroundColor: Colors.white,
        selectedItemColor: FeuTheme.ember,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.near_me_outlined), activeIcon: Icon(Icons.near_me), label: 'Proches'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Demandes'),
        ],
      ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text(lastError!, style: const TextStyle(color: Colors.red)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/help'),
                      child: const Text('Configurer l’URL du serveur (Wi‑Fi / PC)'),
                    ),
                  ),
                ],
              ),
            ),
          const Text('Mécaniciens proches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (lat != null && lng != null)
            SizedBox(
              height: 280,
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
          if (lat == null || lng == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Active la localisation pour voir la carte et les mécaniciens.',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Affiner la recherche', style: TextStyle(fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      Text('Rayon ${_searchRadiusKm.round()} km', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                      Expanded(
                        child: Slider(
                          value: _searchRadiusKm.clamp(1, 50),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '${_searchRadiusKm.round()} km',
                          onChanged: (v) => setState(() => _searchRadiusKm = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Note min. '),
                      DropdownButton<int>(
                        value: _minStarsFilter,
                        items: List.generate(
                          6,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(i == 0 ? '—' : '$i★ et +'),
                          ),
                        ),
                        onChanged: (v) => setState(() => _minStarsFilter = v ?? 0),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _specialtyFilterCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Spécialité (contient…)',
                      isDense: true,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _refreshAll(silent: true, requireFreshGps: false),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (mechanics.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Aucun mecanicien disponible'),
                subtitle: Text('Essaie de rafraichir ou elargir la zone.'),
              ),
            ),
          ...mechanics.map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            final phoneRaw = m['phone']?.toString();
            final canDial = normalizePhoneForDial(phoneRaw) != null;
            return Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      m['name']?.toString() ?? 'Mécanicien',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    if (m['mechanic_specialty'] != null && m['mechanic_specialty'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        m['mechanic_specialty'].toString(),
                        style: TextStyle(fontSize: 14, height: 1.25, color: Colors.grey.shade800),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${m['distance_km']} km'
                            '${m['is_online'] == true ? ' · En ligne' : ''}'
                            '${_mechanicRatingLine(m)}',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (canDial) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_rounded, size: 20, color: FeuTheme.ember),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              (phoneRaw ?? '').trim(),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        'Pas de numéro renseigné pour ce mécanicien.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (!canDial || _sendingRequest)
                                ? null
                                : () => launchTelDialer(context, phoneRaw),
                            icon: const Icon(Icons.call_rounded, size: 20),
                            label: const Text('Appeler'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FeuTheme.ember,
                              side: BorderSide(color: FeuTheme.ember.withValues(alpha: canDial ? 1 : 0.35)),
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _sendingRequest ? null : () => _createRequest(m),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FeuTheme.ember,
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
                        ),
                      ],
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiService.resolvePublicUrl(r['photo_url'].toString()),
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Text('Image indisponible'),
                  ),
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
            final id = ApiService.parseIntId(r['id']);
            return Card(
              child: ListTile(
                title: Text('${r['vehicle_type'] ?? '—'} • ${_mechanicNameFromRequest(r)}'),
                subtitle: Text(
                  '${r['description']?.toString() ?? ''}\n${_requestStatusLine(r)}',
                ),
                isThreeLine: true,
                onTap: () => _showRequestDetail(r),
                trailing: _buildRequestListTrailing(r, id),
              ),
            );
          }),
        ],
      ),
    );
  }
}