import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/feu_theme.dart';
import 'message_read_ticks.dart';
import 'public_network_image.dart';

/// Bulle de message (reçu / envoyé) avec queue arrondie type messagerie moderne.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.mine,
    required this.body,
    required this.kind,
    this.mediaUrl,
    this.maxWidth = 300,
    this.onPlayAudio,
    this.isPlayingAudio = false,
  });

  final bool mine;
  final String body;
  final String kind;
  final String? mediaUrl;
  final double maxWidth;
  final VoidCallback? onPlayAudio;
  final bool isPlayingAudio;

  String? get _resolvedMedia {
    final u = mediaUrl?.trim();
    if (u != null && u.isNotEmpty && u != 'null') {
      return ApiService.resolvePublicUrl(u);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    if (kind == 'image') {
      final resolved = _resolvedMedia;
      return Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: FeuTheme.charcoal.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (resolved != null && resolved.isNotEmpty)
                PublicNetworkImage(
                  url: resolved,
                  width: maxWidth,
                  height: 200,
                  icon: Icons.broken_image_outlined,
                )
              else
                Container(
                  width: maxWidth,
                  height: 120,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Text(
                    'Image indisponible',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              if (body.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: mine ? FeuTheme.mineBubble : FeuTheme.theirsBubble,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 15,
                      color: mine ? Colors.white : FeuTheme.charcoal,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? FeuTheme.mineBubble : FeuTheme.theirsBubble,
        borderRadius: radius,
        border: mine ? null : Border.all(color: FeuTheme.charcoal.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: FeuTheme.charcoal.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kind == 'audio') ...[
            Material(
              color: mine ? Colors.white.withValues(alpha: 0.15) : FeuTheme.paper,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onPlayAudio,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlayingAudio ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: mine ? Colors.white : FeuTheme.deepBlue,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Message vocal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: mine ? Colors.white : FeuTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (body.isNotEmpty) const SizedBox(height: 8),
          ],
          if (body.isNotEmpty)
            Text(
              body,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: mine ? Colors.white : FeuTheme.charcoal.withValues(alpha: 0.92),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne message : horodatage hors bulle + bulle (comme le mockup).
class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({
    super.key,
    required this.mine,
    required this.body,
    required this.kind,
    required this.timeLabel,
    this.mediaUrl,
    this.readAt,
    this.maxWidth = 300,
    this.onPlayAudio,
    this.isPlayingAudio = false,
    this.dateSeparator,
  });

  final bool mine;
  final String body;
  final String kind;
  final String timeLabel;
  final String? mediaUrl;
  final String? readAt;
  final double maxWidth;
  final VoidCallback? onPlayAudio;
  final bool isPlayingAudio;
  final String? dateSeparator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (dateSeparator != null && dateSeparator!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: FeuTheme.charcoal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dateSeparator!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FeuTheme.charcoal.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
          if (!mine && timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: FeuTheme.charcoal.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ChatMessageBubble(
            mine: mine,
            body: body,
            kind: kind,
            mediaUrl: mediaUrl,
            maxWidth: maxWidth,
            onPlayAudio: onPlayAudio,
            isPlayingAudio: isPlayingAudio,
          ),
          if (mine && (timeLabel.isNotEmpty || readAt != null))
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: FeuTheme.charcoal.withValues(alpha: 0.4),
                      ),
                    ),
                  if (timeLabel.isNotEmpty) const SizedBox(width: 4),
                  MessageReadTicks(readAt: readAt),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
