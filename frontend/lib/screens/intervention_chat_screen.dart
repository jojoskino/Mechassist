import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../services/api_data_cache.dart';
import '../services/api_response_cache.dart';
import '../services/api_service.dart';
import '../services/app_notification_hub.dart';
import '../services/auth_storage.dart';
import '../services/in_app_notification_sync.dart';
import '../services/profile_signals.dart';
import '../theme/feu_theme.dart';
import '../utils/read_file_bytes.dart';
import '../utils/phone_launch.dart';
import '../widgets/chat_composer_bar.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_screen_header.dart';
import '../screens/user_profile_page.dart';
import '../utils/gps_position_tracker.dart';

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
  String _peerName = 'Interlocuteur';
  Map<String, dynamic>? _peerMechanic;
  Map<String, dynamic>? _peerClient;
  bool _iAmClient = false;
  int _peerAvatarEpoch = 0;
  String? _lastPeerAvatarUrlSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ProfileSignals.instance.addListener(_onProfileSignals);
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ProfileSignals.instance.removeListener(_onProfileSignals);
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
    // PERF: 12 s minimum ; arrêt si écran non visible (lifecycle + route).
    _poll = Timer.periodic(perfChatPollInterval, (_) {
      if (!_foreground) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      unawaited(_load(silent: true, markRead: !_readOnly));
    });
  }

  void _onProfileSignals() {
    if (_authToken == null) return;
    if (mounted) setState(() {});
    unawaited(_bootstrapAccess());
  }

  void _syncPeerAvatarEpochFromPeers() {
    final peer = _iAmClient ? _peerMechanic : _peerClient;
    final url = peer?['avatar_url']?.toString() ?? '';
    if (_lastPeerAvatarUrlSnapshot != url) {
      _lastPeerAvatarUrlSnapshot = url;
      _peerAvatarEpoch++;
    }
  }

  Future<void> _bootstrap() async {
    final cachedMsgs = ApiDataCache.messagesSync(widget.requestId) ??
        await ApiDataCache.loadMessages(widget.requestId);
    if (cachedMsgs != null && cachedMsgs.isNotEmpty && mounted) {
      setState(() {
        _messages = cachedMsgs;
        _loading = false;
      });
    }

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

    final batch = await Future.wait<dynamic>([
      AuthStorage.getName(),
      ApiService.getMe(t),
      ApiService.getInterventionRequest(t, widget.requestId),
    ]);
    if (!mounted) return;
    _myName = ((batch[0] as String?) ?? '').trim().toLowerCase();
    final me = batch[1] as Map<String, dynamic>;
    final st = me['status'] as int?;
    if (st != null && st >= 200 && st < 300) {
      _myUserId = ApiService.parseIntId(me['id']);
    }
    await _bootstrapAccessWithPayload(batch[2] as Map<String, dynamic>);
    if (!mounted) return;
    _startFastPoll();
  }

  Future<void> _bootstrapAccess() async {
    final token = _authToken;
    if (token == null) return;
    final res = await ApiService.getInterventionRequest(token, widget.requestId);
    if (!mounted) return;
    await _bootstrapAccessWithPayload(res);
  }

  Future<void> _bootstrapAccessWithPayload(Map<String, dynamic> res) async {
    if (!mounted) return;
    final code = res['http_status'] as int?;
    final httpOk = code != null && code >= 200 && code < 300;
    if (!httpOk) {
      setState(() {
        _readOnly = true;
        _accessHint = res['message']?.toString() ?? 'Impossible de charger la demande.';
      });
      await _markConversationRead();
      return;
    }
    _applyPeerFromRequest(res);
    _syncPeerAvatarEpochFromPeers();
    if (mounted) {
      setState(() {});
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
    await _markConversationRead();
  }

  Future<void> _markConversationRead() async {
    if (_readOnly || _authToken == null) {
      await _load(silent: true);
      return;
    }
    ApiResponseCache.invalidateMessages(widget.requestId);
    await _load(silent: true, markRead: true);
    AppNotificationHub.instance.clearChatForRequest(widget.requestId);
    unawaited(InAppNotificationSync.instance.refresh());
  }

  bool _messagesEqual(List<dynamic> a, List<dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ma = a[i];
      final mb = b[i];
      if (ma is! Map || mb is! Map) return false;
      if (ma['id'] != mb['id']) return false;
      if (ma['read_at']?.toString() != mb['read_at']?.toString()) return false;
      if (ma['body']?.toString() != mb['body']?.toString()) return false;
      if (ma['kind']?.toString() != mb['kind']?.toString()) return false;
      if (ma['media_url']?.toString() != mb['media_url']?.toString()) return false;
    }
    return true;
  }

  Future<void> _load({bool silent = false, bool markRead = false}) async {
    final token = _authToken;
    if (token == null) return;
    if (!silent) setState(() => _loading = true);
    final res = await ApiService.listMessages(
      token,
      widget.requestId,
      markRead: markRead,
    );
    if (!mounted) return;
    final raw = res['data'];
    final list = (raw is List) ? raw : <dynamic>[];
    final err = (res['status'] as int?) != null &&
            (res['status'] as int) >= 200 &&
            (res['status'] as int) < 300
        ? null
        : (ApiService.isTransientFailure(res)
            ? null
            : (res['message']?.toString() ?? 'Erreur ${res['status']}'));
    if (list.isNotEmpty) {
      unawaited(ApiDataCache.saveMessages(widget.requestId, list));
    }
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
      if (markRead) {
        AppNotificationHub.instance.clearChatForRequest(widget.requestId);
      }
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
    if (mounted) setState(() => _sending = false);
    unawaited(_load(silent: true));
    _poll?.cancel();
    _startFastPoll();
  }

  Future<void> _pickAndSendImage({ImageSource source = ImageSource.gallery}) async {
    final token = _authToken;
    if (token == null || _readOnly || _sending) return;
    final x = await _picker.pickImage(
      source: source,
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
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Micro refusé — autorise le micro dans les réglages.'),
            action: SnackBarAction(
              label: 'Réglages',
              onPressed: openAppSettings,
            ),
          ),
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
    if (dur < const Duration(milliseconds: 400)) {
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
        if (mounted) setState(() => _sending = false);
        unawaited(_load(silent: true));
        _poll?.cancel();
        _startFastPoll();
        return;
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

  void _applyPeerFromRequest(Map<String, dynamic> res) {
    final client = res['client'];
    final mechanic = res['mechanic'];
    final clientId = ApiService.parseIntId(res['client_id']);
    _peerMechanic = mechanic is Map ? Map<String, dynamic>.from(mechanic) : null;
    _peerClient = client is Map ? Map<String, dynamic>.from(client) : null;
    _iAmClient = _myUserId != null && clientId != null && _myUserId == clientId;
    if (_iAmClient) {
      _peerName = _peerMechanic?['name']?.toString() ?? 'Mécanicien';
    } else {
      _peerName = _peerClient?['name']?.toString() ?? 'Client';
    }
  }

  String? _dateSeparatorForIndex(int index) {
    if (index < 0 || index >= _messages.length) return null;
    final cur = _messages[index];
    if (cur is! Map) return null;
    final curAt = cur['created_at']?.toString() ?? '';
    if (curAt.length < 10) return null;
    final curDay = curAt.substring(0, 10);
    if (index == 0) {
      return _formatDayLabel(curAt);
    }
    final prev = _messages[index - 1];
    if (prev is! Map) return null;
    final prevAt = prev['created_at']?.toString() ?? '';
    if (prevAt.length < 10 || prevAt.substring(0, 10) == curDay) {
      return null;
    }
    return _formatDayLabel(curAt);
  }

  String _formatDayLabel(String iso) {
    if (iso.length < 16) return iso;
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (msgDay == today) {
        return "Aujourd'hui à $time";
      }
      final yesterday = today.subtract(const Duration(days: 1));
      if (msgDay == yesterday) {
        return 'Hier à $time';
      }
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')} à $time';
    } catch (_) {
      return iso.substring(0, 16);
    }
  }

  String _timeLabel(String iso) {
    if (iso.length >= 16) {
      return iso.substring(11, 16);
    }
    return '';
  }

  String? _mediaUrlFromMessage(Map<String, dynamic> map) {
    final url = map['media_url']?.toString();
    if (url != null && url.trim().isNotEmpty && url != 'null') {
      return url;
    }
    final path = map['media_path']?.toString();
    if (path != null && path.trim().isNotEmpty && path != 'null') {
      return path;
    }
    return null;
  }

  String? _peerPhone(Map<String, dynamic>? mechanic, Map<String, dynamic>? client) {
    final map = _iAmClient ? mechanic : client;
    if (map == null) return null;
    final p = map['phone']?.toString();
    if (p == null || p.isEmpty) return null;
    return p;
  }

  String _effectiveKind(Map<String, dynamic> map) {
    final raw = map['kind']?.toString() ?? map['message_type']?.toString();
    if (raw != null && raw.isNotEmpty && raw != 'text' && raw != 'null') {
      return raw;
    }
    final media = _mediaUrlFromMessage(map);
    if (media == null || media.isEmpty) return 'text';
    final lower = media.toLowerCase();
    if (RegExp(r'\.(m4a|mp3|wav|ogg|aac|webm)(\?|$)').hasMatch(lower)) {
      return 'audio';
    }
    if (RegExp(r'\.(jpe?g|png|gif|webp)(\?|$)').hasMatch(lower)) {
      return 'image';
    }
    if (lower.contains('/chat/')) {
      return 'image';
    }
    return 'image';
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
    final bubbleMax = width * 0.78;
    final m = _peerMechanic;
    final c = _peerClient;
    return Scaffold(
      backgroundColor: FeuTheme.chatBackdrop,
      appBar: ChatScreenHeader(
        peerName: _peerName,
        roleLabel: _iAmClient ? 'Ton mécanicien' : 'Client',
        phone: _peerPhone(m, c),
        specialty: _iAmClient && m != null ? m['mechanic_specialty']?.toString() : null,
        avatarUrl: _iAmClient
            ? (m != null ? m['avatar_url']?.toString() : null)
            : (c != null ? c['avatar_url']?.toString() : null),
        avatarCacheEpoch: Object.hash(_peerAvatarEpoch, ProfileSignals.instance.generation),
        peerUser: _iAmClient ? m : c,
        onRefresh: _authToken == null ? null : () => _load(),
        onOpenProfile: () {
          final user = _iAmClient ? m : c;
          if (user == null) return;
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => UserProfilePage(
                user: Map<String, dynamic>.from(user),
                subtitle: _iAmClient ? 'Ton mécanicien' : 'Client',
              ),
            ),
          );
        },
        onCall: _peerPhone(m, c) == null
            ? null
            : () => launchTelDialer(context, _peerPhone(m, c)),
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
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                itemCount: _messages.length,
                                itemBuilder: (_, i) {
                                  final m = _messages[i];
                                  if (m is! Map) return const SizedBox.shrink();
                                  final map = Map<String, dynamic>.from(m);
                                  final mine = _isMine(map);
                                  final body = map['body']?.toString() ?? '';
                                  final kind = _effectiveKind(map);
                                  final mediaUrl = _mediaUrlFromMessage(map);
                                  final createdAt = map['created_at']?.toString() ?? '';
                                  final readAt = map['read_at']?.toString();
                                  final mid = ApiService.parseIntId(map['id']) ?? i;
                                  return Align(
                                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                    child: ChatMessageRow(
                                      mine: mine,
                                      body: body,
                                      kind: kind,
                                      timeLabel: _timeLabel(createdAt),
                                      mediaUrl: mediaUrl,
                                      readAt: readAt,
                                      maxWidth: bubbleMax,
                                      dateSeparator: _dateSeparatorForIndex(i),
                                      isPlayingAudio: _playingMessageId == mid,
                                      onPlayAudio: kind == 'audio'
                                          ? () => _togglePlay(mid, mediaUrl ?? '')
                                          : null,
                                    ),
                                  );
                                },
                              ),
              ),
              ChatComposerBar(
                controller: _msgCtrl,
                onSend: _sendText,
                onPickGallery: () => _pickAndSendImage(source: ImageSource.gallery),
                onPickCamera: kIsWeb ? null : () => _pickAndSendImage(source: ImageSource.camera),
                onVoicePressStart: _onVoiceLongPressStart,
                onVoicePressEnd: _onVoiceLongPressEnd,
                onVoicePressCancel: () => unawaited(_cancelRecording()),
                readOnly: _readOnly || _authToken == null || _sessionError != null,
                sending: _sending,
                recording: _recording,
                hintText: _readOnly
                    ? 'Lecture seule'
                    : (_sessionError != null
                        ? 'Session invalide'
                        : (_authToken == null ? 'Connexion…' : 'Message')),
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
                          'Enregistrement… relâche pour envoyer · glisse à gauche pour annuler',
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
