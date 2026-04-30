import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';

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
  String? lastError;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

    final me = await ApiService.getMe(token);
    final reqs = await ApiService.listRequests(token);

    available = (me['is_available'] as bool?) ?? false;
    currentName = me['name']?.toString() ?? 'Mecanicien';
    currentRole = me['role']?.toString() ?? 'mecanicien';
    requests = (reqs['data'] is List) ? (reqs['data'] as List) : [];
    if (!mounted) return;
    setState(() {
      loading = false;
      lastError = null;
    });
  }

  Future<void> _setAvailability(bool value) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    await ApiService.updateMechanicAvailability(token, value);
    setState(() => available = value);
  }

  Future<void> _processRequest(int id, bool accept) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    if (accept) {
      await ApiService.acceptRequest(token, id);
    } else {
      await ApiService.declineRequest(token, id);
    }
    await _refresh(silent: true);
  }

  Future<void> _openChat(int requestId) async {
    if (!mounted) return;
    final token = await AuthStorage.getToken();
    if (token == null) {
      return;
    }
    await _openLegacyChat(requestId, token);
  }

  Future<void> _openLegacyChat(int requestId, String token) async {
    final msgCtrl = TextEditingController();
    List<dynamic> messages = [];
    Timer? pollTimer;

    Future<void> loadMessages(StateSetter setInner) async {
      final res = await ApiService.listMessages(token, requestId);
      messages = (res['data'] as List?) ?? [];
      setInner(() {});
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) {
          if (messages.isEmpty) {
            loadMessages(setInner);
            pollTimer ??= Timer.periodic(
              const Duration(seconds: 3),
              (_) => loadMessages(setInner),
            );
          }
          return AlertDialog(
            title: const Text('Chat'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i] as Map<String, dynamic>;
                        final user = (m['user'] as Map?) ?? {};
                        return ListTile(
                          dense: true,
                          title: Text(user['name']?.toString() ?? 'Utilisateur'),
                          subtitle: Text(m['body']?.toString() ?? ''),
                        );
                      },
                    ),
                  ),
                  TextField(controller: msgCtrl, decoration: const InputDecoration(hintText: 'Message')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => loadMessages(setInner), child: const Text('Rafraichir')),
              ElevatedButton(
                onPressed: () async {
                  await ApiService.sendMessage(token, requestId, msgCtrl.text.trim());
                  msgCtrl.clear();
                  await loadMessages(setInner);
                },
                child: const Text('Envoyer'),
              ),
            ],
          );
        },
      ),
    );
    pollTimer?.cancel();
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
                  ...requests.map((r) {
                    final status = r['status']?.toString() ?? '';
                    final canAct = status == 'pending';
                    return Card(
                      child: ListTile(
                        title: Text('${r['vehicle_type']} • $status'),
                        subtitle: Text(r['description']?.toString() ?? ''),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (canAct)
                              IconButton(
                                onPressed: () => _processRequest(r['id'] as int, true),
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                            if (canAct)
                              IconButton(
                                onPressed: () => _processRequest(r['id'] as int, false),
                                icon: const Icon(Icons.cancel, color: Colors.red),
                              ),
                            TextButton(
                              onPressed: () => _openChat(r['id'] as int),
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