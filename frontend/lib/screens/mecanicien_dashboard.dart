import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/push_service.dart';
import '../theme/feu_theme.dart';
import '../utils/phone_launch.dart';

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
  /// Filtre API `?status=` (null = toutes).
  String? _requestStatusFilter;
  int _tabIndex = 0;

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
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 6),
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
        appBar: FeuTheme.fireAppBar(
          title: _tabIndex == 0 ? 'MechAssist Pro' : 'Compte',
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              tooltip: 'Mon profil',
              onPressed: () async {
                final changed = await Navigator.pushNamed(context, '/profile');
                if (!mounted) return;
                if (changed == true) {
                  await _refresh(silent: true);
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
              onPressed: _refresh,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Déconnexion',
              onPressed: () => _confirmLogout(context),
            )
          ],
        ),
        body: IndexedStack(
          index: _tabIndex,
          children: [
            _buildRequestsTab(),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Demandes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts),
              label: 'Compte',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: FeuTheme.ember));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
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
          Text(
            'Demandes reçues',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: FeuTheme.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in <(String?, String)>[
                  (null, 'Toutes'),
                  ('pending', 'En attente'),
                  ('accepted', 'Acceptées'),
                  ('completed', 'Terminées'),
                  ('declined', 'Refusées'),
                  ('cancelled', 'Annulées'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(e.$2),
                      selected: _requestStatusFilter == e.$1,
                      onSelected: (_) {
                        setState(() => _requestStatusFilter = e.$1);
                        _refresh(silent: true);
                      },
                      selectedColor: FeuTheme.ember.withValues(alpha: 0.28),
                      checkmarkColor: FeuTheme.deepBlue,
                      labelStyle: TextStyle(
                        color: _requestStatusFilter == e.$1 ? FeuTheme.charcoal : Colors.grey.shade800,
                        fontWeight: _requestStatusFilter == e.$1 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (requests.isEmpty)
            Card(
              child: ListTile(
                title: Text(_requestStatusFilter == null ? 'Aucune demande reçue' : 'Aucune demande pour ce filtre'),
                subtitle: Text(
                  _requestStatusFilter == null
                      ? 'Active ton statut pour apparaitre aux clients.'
                      : 'Essaie un autre filtre ou rafraîchis.',
                ),
              ),
            ),
          ...requests.map((raw) {
            final r = raw is Map<String, dynamic>
                ? Map<String, dynamic>.from(raw)
                : Map<String, dynamic>.from(raw as Map);
            final status = (r['status'] ?? '').toString().trim();
            final canAct = status == 'pending';
            final canMarkDone = status == 'accepted' &&
                (r['mechanic_completed_at'] == null ||
                    r['mechanic_completed_at'].toString().trim().isEmpty ||
                    r['mechanic_completed_at'].toString() == 'null');
            final id = ApiService.parseIntId(r['id']);
            final extra = _mechanicRequestExtraLine(r);
            final rawPhoto = r['photo_url']?.toString();
            final hasPhoto =
                rawPhoto != null && rawPhoto.trim().isNotEmpty;
            final client = r['client'];
            String? clientPhone;
            if (client is Map) {
              clientPhone = client['phone']?.toString();
            }
            final canDialClient = normalizePhoneForDial(clientPhone) != null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasPhoto)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ApiService.resolvePublicUrl(rawPhoto),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined, size: 48),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.build_circle_outlined, size: 40),
                          ),
                        if (hasPhoto) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['vehicle_type']} • $status',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              if (client is Map) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Client : ${client['name']?.toString() ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: FeuTheme.deepBlue,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${r['description']?.toString() ?? ''}${extra.isEmpty ? '' : '\n$extra'}',
                                style: TextStyle(height: 1.35, color: Colors.grey.shade800),
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
                          label: const Text('Appeler le client'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FeuTheme.ember,
                            side: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.85)),
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.start,
                      children: [
                        if (canAct && id != null) ...[
                          FilledButton.icon(
                            onPressed: () => _processRequest(id, true),
                            icon: const Icon(Icons.check_circle, size: 20),
                            label: const Text('Accepter'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                          ),
                          FilledButton.icon(
                            onPressed: () => _processRequest(id, false),
                            icon: const Icon(Icons.cancel, size: 20),
                            label: const Text('Refuser'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                          ),
                        ],
                        if (status == 'accepted' && canMarkDone && id != null)
                          FilledButton.icon(
                            onPressed: () => _markMechanicComplete(id),
                            icon: const Icon(Icons.task_alt, size: 20),
                            label: const Text('Intervention terminée'),
                            style: FilledButton.styleFrom(
                              backgroundColor: FeuTheme.deepBlue,
                            ),
                          ),
                        if (status == 'accepted' && id != null)
                          FilledButton.icon(
                            onPressed: () => _openChat(id),
                            icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                            label: const Text('Chat'),
                            style: FilledButton.styleFrom(
                              backgroundColor: FeuTheme.ember,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
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
          subtitle: Text(available ? 'Visible par les clients' : 'Hors ligne'),
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
        ListTile(
          leading: Icon(Icons.help_outline_rounded, color: FeuTheme.deepBlue.withValues(alpha: 0.9)),
          title: const Text('Aide & URL du serveur'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.pushNamed(context, '/help'),
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