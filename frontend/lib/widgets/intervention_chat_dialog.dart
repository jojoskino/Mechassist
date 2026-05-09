import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';

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
  bool _sending = false;
  String? _loadError;
  String _myName = '';
  bool _readOnly = false;
  String? _accessHint;

  @override
  void initState() {
    super.initState();
    _loadCurrentIdentity();
    _bootstrapAccess();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  Future<void> _bootstrapAccess() async {
    final res = await ApiService.getInterventionRequest(widget.authToken, widget.requestId);
    if (!mounted) return;
    final code = res['http_status'] as int?;
    final httpOk = code != null && code >= 200 && code < 300;
    if (!httpOk) {
      setState(() {
        _readOnly = true;
        _accessHint = res['message']?.toString() ?? 'Impossible de charger la demande.';
      });
      await _load(silent: true);
      return;
    }
    final wf = res['status']?.toString();
    if (wf != null && wf != 'accepted') {
      setState(() {
        _readOnly = true;
        switch (wf) {
          case 'completed':
            _accessHint = 'Intervention terminée — historique en lecture seule.';
            break;
          case 'pending':
            _accessHint = 'En attente d’acceptation — le chat s’ouvre une fois la demande acceptée.';
            break;
          case 'declined':
            _accessHint = 'Demande refusée — pas de nouveaux messages.';
            break;
          default:
            _accessHint = 'Chat indisponible pour ce statut.';
        }
      });
    }
    await _load(silent: true);
  }

  Future<void> _loadCurrentIdentity() async {
    final n = await AuthStorage.getName();
    if (!mounted) return;
    setState(() => _myName = (n ?? '').trim().toLowerCase());
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
    if (_readOnly || _sending) return;
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écris un message.')),
      );
      return;
    }
    setState(() => _sending = true);
    final res = await ApiService.sendMessage(widget.authToken, widget.requestId, body);
    if (!mounted) return;
    final ok = (res['status'] as int?) == 201;
    if (!ok) {
      setState(() => _sending = false);
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
    if (mounted) {
      setState(() => _sending = false);
    }
  }

  bool _isMine(Map<String, dynamic> map) {
    final user = (map['user'] as Map?) ?? {};
    final author = (user['name']?.toString() ?? '').trim().toLowerCase();
    return _myName.isNotEmpty && author.isNotEmpty && author == _myName;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AlertDialog(
      title: const Text('Chat'),
      content: SizedBox(
        width: size.width * 0.88,
        height: size.height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_accessHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _accessHint!,
                            style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        if (m is! Map) {
                          return const SizedBox.shrink();
                        }
                        final map = Map<String, dynamic>.from(m);
                        final user = (map['user'] as Map?) ?? const {};
                        final mine = _isMine(map);
                        final body = map['body']?.toString() ?? '';
                        final author = user['name']?.toString() ?? 'Utilisateur';
                        final createdAt = map['created_at']?.toString() ?? '';
                        final time = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: size.width * 0.62),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: mine ? const Color(0xFFDCF8C6) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: Radius.circular(mine ? 14 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 14),
                              ),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(body),
                                if (time.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              readOnly: _readOnly,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _readOnly ? 'Lecture seule' : 'Message',
                border: const OutlineInputBorder(),
                isDense: true,
                filled: _readOnly,
                fillColor: _readOnly ? Colors.grey.shade100 : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _load(), child: const Text('Rafraîchir')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ElevatedButton(
          onPressed: (_sending || _readOnly) ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}
