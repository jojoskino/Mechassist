import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/feu_theme.dart';
import '../utils/read_file_bytes.dart';

/// Discussion intervention : style messagerie (bulles, fond), couleurs MechAssist,
/// rafraîchissement rapide, texte + photo + vocal (hors web pour le micro).
class InterventionChatScreen extends StatefulWidget {
  const InterventionChatScreen({super.key, required this.requestId});

  final int requestId;

  @override
  State<InterventionChatScreen> createState() => _InterventionChatScreenState();
}

class _InterventionChatScreenState extends State<InterventionChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  Timer? _poll;
  StreamSubscription<void>? _playerCompleteSub;

  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  String? _loadError;
  String? _sessionError;
  String _myName = '';
  int? _myUserId;
  bool _readOnly = false;
  String? _accessHint;
  String? _authToken;
  bool _foreground = true;
  int? _playingMessageId;
  DateTime? _recordStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _playerCompleteSub?.cancel();
    unawaited(_player.dispose());
    unawaited(_recorder.dispose());
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _startFastPoll();
      unawaited(_load(silent: true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _poll?.cancel();
      if (_recording) {
        unawaited(_cancelRecording());
      }
    }
  }

  void _startFastPoll() {
    _poll?.cancel();
    if (!_foreground) return;
    _poll = Timer.periodic(const Duration(milliseconds: 550), (_) => _load(silent: true));
  }

  Future<void> _bootstrap() async {
    final t = await AuthStorage.getToken();
    if (!mounted) return;
    if (t == null) {
      setState(() {
        _sessionError = 'Session expirée. Reconnecte-toi.';
        _loading = false;
      });
      return;
    }
    _authToken = t;
    await Future.wait<void>([
      _loadCurrentIdentity(),
      _loadMyUserId(t),
    ]);
    await _bootstrapAccess();
    if (!mounted) return;
    _startFastPoll();
  }

  Future<void> _loadMyUserId(String token) async {
    final me = await ApiService.getMe(token);
    if (!mounted) return;
    final st = me['status'] as int?;
    if (st != null && st >= 200 && st < 300) {
      _myUserId = ApiService.parseIntId(me['id']);
    }
  }

  Future<void> _bootstrapAccess() async {
    final token = _authToken;
    if (token == null) return;
    final res = await ApiService.getInterventionRequest(token, widget.requestId);
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

  bool _messagesEqual(List<dynamic> a, List<dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    final la = a.last;
    final lb = b.last;
    if (la is Map && lb is Map) {
      return la['id'] == lb['id'];
    }
    return false;
  }

  Future<void> _load({bool silent = false}) async {
    final token = _authToken;
    if (token == null) return;
    if (!silent) setState(() => _loading = true);
    final res = await ApiService.listMessages(token, widget.requestId);
    if (!mounted) return;
    final raw = res['data'];
    final list = (raw is List) ? raw : <dynamic>[];
    final err = (res['status'] as int?) != null &&
            (res['status'] as int) >= 200 &&
            (res['status'] as int) < 300
        ? null
        : (res['message']?.toString() ?? 'Erreur ${res['status']}');
    final changed = !_messagesEqual(_messages, list);
    if (changed || !silent) {
      setState(() {
        _messages = list;
        _loadError = err;
        _loading = false;
      });
    } else {
      setState(() {
        _loadError = err;
        _loading = false;
      });
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _sendText() async {
    final token = _authToken;
    if (token == null || _readOnly || _sending) return;
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Écris un message.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FeuTheme.charcoal,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final res = await ApiService.sendMessage(token, widget.requestId, body);
    if (!mounted) return;
    final ok = (res['status'] as int?) == 201;
    if (!ok) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade900,
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
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickAndSendImage() async {
    final token = _authToken;
    if (token == null || _readOnly || _sending) return;
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      final name = (x.name.isNotEmpty ? x.name : 'photo.jpg').split(RegExp(r'[\\/]')).last;
      final res = await ApiService.sendChatMedia(
        token,
        widget.requestId,
        messageType: 'image',
        bytes: bytes,
        filename: name,
        caption: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      );
      if (!mounted) return;
      final ok = (res['status'] as int?) == 201;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text(res['message']?.toString() ?? 'Envoi photo impossible.'),
          ),
        );
      } else {
        _msgCtrl.clear();
        await _load(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _recorder.stop();
    } catch (_) {
      /* ignore */
    }
    if (mounted) {
      setState(() {
        _recording = false;
        _recordStartedAt = null;
      });
    }
  }

  Future<void> _onVoiceLongPressStart() async {
    if (kIsWeb || _readOnly || _authToken == null || _sending) {
      if (kIsWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le vocal n’est pas disponible sur le web.')),
        );
      }
      return;
    }
    final ok = await _recorder.hasPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micro refusé — active-le dans les réglages du téléphone.')),
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/mechassist_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordStartedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Micro : $e')),
        );
      }
    }
  }

  Future<void> _onVoiceLongPressEnd() async {
    if (!_recording) return;
    final token = _authToken;
    final started = _recordStartedAt;
    setState(() {
      _recording = false;
      _recordStartedAt = null;
    });
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (token == null || !mounted) return;
    if (path == null || path.isEmpty) return;
    final dur = started != null ? DateTime.now().difference(started) : Duration.zero;
    if (dur < const Duration(milliseconds: 550)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message trop court — maintiens plus longtemps.')),
        );
      }
      return;
    }
    setState(() => _sending = true);
    try {
      final bytes = await readPathAsBytes(path);
      final res = await ApiService.sendChatMedia(
        token,
        widget.requestId,
        messageType: 'audio',
        bytes: bytes,
        filename: 'voice.m4a',
      );
      if (!mounted) return;
      final ok = (res['status'] as int?) == 201;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text(res['message']?.toString() ?? 'Envoi vocal impossible.'),
          ),
        );
      } else {
        await _load(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vocal : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _togglePlay(int messageId, String url) async {
    final abs = ApiService.resolvePublicUrl(url);
    if (abs.isEmpty) return;
    if (_playingMessageId == messageId) {
      await _player.stop();
      if (mounted) setState(() => _playingMessageId = null);
      return;
    }
    await _player.stop();
    await _player.play(UrlSource(abs));
    if (mounted) setState(() => _playingMessageId = messageId);
  }

  bool _isMine(Map<String, dynamic> map) {
    final user = (map['user'] as Map?) ?? {};
    final uid = ApiService.parseIntId(user['id']);
    if (_myUserId != null && uid != null) {
      return uid == _myUserId;
    }
    final author = (user['name']?.toString() ?? '').trim().toLowerCase();
    return _myName.isNotEmpty && author.isNotEmpty && author == _myName;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: FeuTheme.chatBackdrop,
      appBar: FeuTheme.fireAppBar(
        title: 'Discussion · #${widget.requestId}',
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _authToken == null ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_accessHint != null)
                Material(
                  color: FeuTheme.flame.withValues(alpha: 0.18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: FeuTheme.ember, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _accessHint!,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: FeuTheme.charcoal.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _loadError!,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                    ),
                  ),
                ),
              Expanded(
                child: _sessionError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _sessionError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 15),
                          ),
                        ),
                      )
                    : _authToken == null
                        ? const Center(
                            child: CircularProgressIndicator(color: FeuTheme.ember),
                          )
                        : _loading && _messages.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(color: FeuTheme.ember),
                              )
                            : ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                                itemCount: _messages.length,
                                itemBuilder: (_, i) {
                                  final m = _messages[i];
                                  if (m is! Map) return const SizedBox.shrink();
                                  final map = Map<String, dynamic>.from(m);
                                  final user = (map['user'] as Map?) ?? const {};
                                  final mine = _isMine(map);
                                  final body = map['body']?.toString() ?? '';
                                  final kind = map['kind']?.toString() ?? 'text';
                                  final mediaUrl = map['media_url']?.toString();
                                  final author = user['name']?.toString() ?? 'Utilisateur';
                                  final createdAt = map['created_at']?.toString() ?? '';
                                  final time = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
                                  final mid = ApiService.parseIntId(map['id']) ?? i;
                                  return Align(
                                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: width * 0.84),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: mine ? FeuTheme.mineBubble : FeuTheme.theirsBubble,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(mine ? 16 : 4),
                                          bottomRight: Radius.circular(mine ? 4 : 16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: FeuTheme.charcoal.withValues(alpha: mine ? 0.1 : 0.06),
                                            blurRadius: mine ? 8 : 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            author,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: FeuTheme.deepBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (kind == 'image' &&
                                              mediaUrl != null &&
                                              mediaUrl.isNotEmpty) ...[
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxHeight: 240),
                                                child: Image.network(
                                                  ApiService.resolvePublicUrl(mediaUrl),
                                                  fit: BoxFit.cover,
                                                  width: width * 0.72,
                                                  loadingBuilder: (c, w, p) {
                                                    if (p == null) return w;
                                                    return SizedBox(
                                                      height: 120,
                                                      child: Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: FeuTheme.ember.withValues(alpha: 0.8),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (_, __, ___) => const Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child: Icon(Icons.broken_image_outlined),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (body.isNotEmpty) const SizedBox(height: 6),
                                          ],
                                          if (kind == 'audio') ...[
                                            InkWell(
                                              onTap: () => _togglePlay(mid, mediaUrl ?? ''),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: mine
                                                      ? Colors.white.withValues(alpha: 0.55)
                                                      : FeuTheme.paper.withValues(alpha: 0.9),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _playingMessageId == mid
                                                          ? Icons.stop_rounded
                                                          : Icons.play_arrow_rounded,
                                                      color: FeuTheme.deepBlue,
                                                      size: 28,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Message vocal',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: FeuTheme.charcoal.withValues(alpha: 0.88),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (body.isNotEmpty) const SizedBox(height: 6),
                                          ],
                                          if (body.isNotEmpty)
                                            Text(
                                              body,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.35,
                                                color: FeuTheme.charcoal.withValues(alpha: 0.95),
                                              ),
                                            ),
                                          if (time.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              time,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: mine ? Colors.black45 : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              Material(
                elevation: 10,
                color: FeuTheme.paper,
                shadowColor: FeuTheme.charcoal.withValues(alpha: 0.18),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Envoyer une image',
                          onPressed: (_sending || _readOnly || _authToken == null || _sessionError != null)
                              ? null
                              : _pickAndSendImage,
                          icon: Icon(Icons.add_photo_alternate_outlined,
                              color: FeuTheme.deepBlue.withValues(alpha: 0.85)),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: FeuTheme.ember.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _msgCtrl,
                                    readOnly:
                                        _readOnly || _authToken == null || _sessionError != null,
                                    minLines: 1,
                                    maxLines: 5,
                                    style: const TextStyle(fontSize: 15),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: _readOnly
                                          ? 'Lecture seule'
                                          : (_sessionError != null
                                              ? 'Session invalide'
                                              : (_authToken == null ? 'Connexion…' : 'Message…')),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.fromLTRB(14, 12, 8, 12),
                                    ),
                                    onSubmitted: (_) => _sendText(),
                                  ),
                                ),
                                if (!kIsWeb)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onLongPressStart: (_) => _onVoiceLongPressStart(),
                                    onLongPressEnd: (_) => _onVoiceLongPressEnd(),
                                    onLongPressCancel: () => unawaited(_cancelRecording()),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                                      child: Icon(
                                        Icons.mic_none_rounded,
                                        color: _recording
                                            ? FeuTheme.ember
                                            : FeuTheme.deepBlue.withValues(alpha: 0.75),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: (_sending ||
                                  _readOnly ||
                                  _authToken == null ||
                                  _sessionError != null)
                              ? null
                              : _sendText,
                          style: FilledButton.styleFrom(
                            backgroundColor: FeuTheme.ember,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                            shape: const CircleBorder(),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_recording)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(18),
                color: FeuTheme.deepBlue,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Enregistrement… relâche pour envoyer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
