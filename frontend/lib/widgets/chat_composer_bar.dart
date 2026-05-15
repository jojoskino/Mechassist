import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/feu_theme.dart';

/// Barre de saisie type messagerie : pilule + micro / envoi bien visibles.
class ChatComposerBar extends StatefulWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onPickGallery,
    this.onPickCamera,
    this.onVoicePressStart,
    this.onVoicePressEnd,
    this.onVoicePressCancel,
    this.readOnly = false,
    this.sending = false,
    this.recording = false,
    this.voiceEnabled = true,
    this.hintText = 'Message',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onVoicePressStart;
  final VoidCallback? onVoicePressEnd;
  final VoidCallback? onVoicePressCancel;
  final bool readOnly;
  final bool sending;
  final bool recording;
  final bool voiceEnabled;
  final String hintText;

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  bool _emojiOpen = false;
  bool _hasText = false;
  bool _voiceHeld = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(ChatComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) {
      setState(() => _hasText = next);
    }
  }

  void _insertEmoji(String value) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final updated = text.replaceRange(start, end, value);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  void _toggleEmoji() {
    if (widget.readOnly || widget.sending) return;
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
  }

  void _openAttachSheet() {
    if (widget.readOnly || widget.sending) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: FeuTheme.deepBlue),
                title: Text('Galerie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onPickGallery();
                },
              ),
              if (!kIsWeb && widget.onPickCamera != null)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: FeuTheme.deepBlue),
                  title: Text('Appareil photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onPickCamera!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _disabled => widget.readOnly || widget.sending;
  bool get _showSend => _hasText && !widget.recording;
  bool get _canVoice =>
      widget.voiceEnabled &&
      !kIsWeb &&
      widget.onVoicePressStart != null &&
      widget.onVoicePressEnd != null;

  void _voiceDown(PointerDownEvent e) {
    if (_disabled || !_canVoice || _showSend) return;
    HapticFeedback.mediumImpact();
    _voiceHeld = true;
    widget.onVoicePressStart?.call();
  }

  void _voiceUp(PointerUpEvent e) {
    if (!_voiceHeld) return;
    _voiceHeld = false;
    widget.onVoicePressEnd?.call();
  }

  void _voiceCancel() {
    if (!_voiceHeld) return;
    _voiceHeld = false;
    widget.onVoicePressCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    const pillColor = Color(0xFFF0F2F5);

    return Material(
      color: FeuTheme.chatBackdrop,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_emojiOpen)
              SizedBox(
                height: 260,
                child: emoji.EmojiPicker(
                  onEmojiSelected: (category, item) => _insertEmoji(item.emoji),
                  config: emoji.Config(
                    height: 256,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: emoji.EmojiViewConfig(
                      backgroundColor: FeuTheme.chatBackdrop,
                      columns: 8,
                      emojiSizeMax: 28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                    ),
                    categoryViewConfig: emoji.CategoryViewConfig(
                      backgroundColor: Colors.white,
                      indicatorColor: FeuTheme.ember,
                      iconColorSelected: FeuTheme.deepBlue,
                    ),
                    bottomActionBarConfig: const emoji.BottomActionBarConfig(enabled: false),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: widget.recording
                              ? FeuTheme.ember
                              : FeuTheme.charcoal.withValues(alpha: 0.08),
                          width: widget.recording ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _disabled ? null : _toggleEmoji,
                            icon: Icon(
                              _emojiOpen ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                              color: FeuTheme.deepBlue.withValues(alpha: 0.7),
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              readOnly: widget.readOnly,
                              minLines: 1,
                              maxLines: 5,
                              style: GoogleFonts.poppins(fontSize: 15.5, color: FeuTheme.charcoal),
                              decoration: InputDecoration(
                                hintText: widget.hintText,
                                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onTap: () {
                                if (_emojiOpen) setState(() => _emojiOpen = false);
                              },
                              onSubmitted: _disabled || !_showSend ? null : (_) => widget.onSend(),
                            ),
                          ),
                          IconButton(
                            onPressed: _disabled ? null : _openAttachSheet,
                            icon: Icon(
                              Icons.attach_file_rounded,
                              color: FeuTheme.deepBlue.withValues(alpha: 0.7),
                              size: 24,
                            ),
                            tooltip: 'Pièce jointe',
                          ),
                          if (_showSend)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Material(
                                color: FeuTheme.ember,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _disabled ? null : widget.onSend,
                                  customBorder: const CircleBorder(),
                                  child: SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: Center(
                                      child: widget.sending
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _VoiceMicButton(
                                enabled: _canVoice && !_disabled,
                                recording: widget.recording,
                                onDown: _voiceDown,
                                onUp: _voiceUp,
                                onCancel: _voiceCancel,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.recording)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Enregistrement… relâche pour envoyer',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FeuTheme.ember,
                  ),
                ),
              ),
            if (!_canVoice && !kIsWeb && !_showSend)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Micro indisponible',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceMicButton extends StatelessWidget {
  const _VoiceMicButton({
    required this.enabled,
    required this.recording,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
  });

  final bool enabled;
  final bool recording;
  final void Function(PointerDownEvent) onDown;
  final void Function(PointerUpEvent) onUp;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bg = recording
        ? FeuTheme.deepBlue
        : (enabled ? FeuTheme.ember : Colors.grey.shade400);

    return Listener(
      onPointerDown: enabled ? onDown : null,
      onPointerUp: enabled ? onUp : null,
      onPointerCancel: enabled ? (_) => onCancel() : null,
      child: Material(
        color: bg,
        elevation: enabled ? 3 : 0,
        shadowColor: FeuTheme.charcoal.withValues(alpha: 0.25),
        shape: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            recording ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
