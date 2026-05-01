import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Chat intervention (API) avec rafraîchissement périodique et envoi sécurisé.
Future<void> showInterventionChatDialog({
  required BuildContext context,
  required String authToken,
  required int requestId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _InterventionChatDialog(
      authToken: authToken,
      requestId: requestId,
    ),
  );
}

class _InterventionChatDialog extends StatefulWidget {
  const _InterventionChatDialog({
    required this.authToken,
    required this.requestId,
  });

  final String authToken;
  final int requestId;

  @override
  State<_InterventionChatDialog> createState() => _InterventionChatDialogState();
}

class _InterventionChatDialogState extends State<_InterventionChatDialog> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poll;
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final res = await ApiService.listMessages(widget.authToken, widget.requestId);
    if (!mounted) return;
    final raw = res['data'];
    final list = (raw is List) ? raw : <dynamic>[];
    final err = (res['status'] as int?) != null &&
            (res['status'] as int) >= 200 &&
            (res['status'] as int) < 300
        ? null
        : (res['message']?.toString() ?? 'Erreur ${res['status']}');
    setState(() {
      _messages = list;
      _loadError = err;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écris un message.')),
      );
      return;
    }
    final res = await ApiService.sendMessage(widget.authToken, widget.requestId, body);
    if (!context.mounted) return;
    final ok = (res['status'] as int?) == 201;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ??
                'Envoi impossible (vérifie que la demande est acceptée).',
          ),
        ),
      );
      return;
    }
    _msgCtrl.clear();
    await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chat'),
      content: SizedBox(
        width: 360,
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_loadError!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
              ),
            Expanded(
              child: _loading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        if (m is! Map) {
                          return const SizedBox.shrink();
                        }
                        final map = Map<String, dynamic>.from(m);
                        final user = (map['user'] as Map?) ?? {};
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(user['name']?.toString() ?? 'Utilisateur'),
                          subtitle: Text(map['body']?.toString() ?? ''),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _load(), child: const Text('Rafraîchir')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ElevatedButton(onPressed: _send, child: const Text('Envoyer')),
      ],
    );
  }
}
