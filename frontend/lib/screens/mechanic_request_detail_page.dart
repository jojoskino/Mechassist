import 'package:flutter/material.dart';

import '../theme/feu_theme.dart';
import '../widgets/public_network_image.dart';
import '../widgets/user_avatar.dart';

/// Détail demande mécanicien (page plein écran).
class MechanicRequestDetailPage extends StatelessWidget {
  const MechanicRequestDetailPage({
    super.key,
    required this.requestIdLabel,
    required this.status,
    required this.vehicleType,
    required this.description,
    this.client,
    required this.avatarCacheEpoch,
    this.photoUrl,
    required this.canDial,
    required this.canAccept,
    required this.canMarkDone,
    this.onCall,
    this.onAccept,
    this.onDecline,
    this.onChat,
    this.onMarkDone,
    required this.onOpenPhoto,
  });

  final String requestIdLabel;
  final String status;
  final String vehicleType;
  final String description;
  final Map<String, dynamic>? client;
  final int avatarCacheEpoch;
  final String? photoUrl;
  final bool canDial;
  final bool canAccept;
  final bool canMarkDone;
  final VoidCallback? onCall;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onChat;
  final VoidCallback? onMarkDone;
  final void Function(String url) onOpenPhoto;

  bool get _hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();
    final clientPhone = client is Map ? client!['phone']?.toString() : null;

    return Scaffold(
      backgroundColor: FeuTheme.pageGrey,
      appBar: AppBar(
        title: Text('Demande $requestIdLabel'),
        backgroundColor: Colors.white,
        foregroundColor: FeuTheme.deepBlue,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (client is Map) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      name: client!['name']?.toString() ?? 'C',
                      avatarUrl: client!['avatar_url']?.toString(),
                      cacheEpoch: avatarCacheEpoch,
                      radius: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client!['name']?.toString() ?? 'Client',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                          ),
                          if (clientPhone != null && clientPhone.trim().isNotEmpty)
                            Text(clientPhone, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('Véhicule : $vehicleType', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Statut : $status'),
          const SizedBox(height: 12),
          Text(description),
          if (_hasPhoto && photo != null) ...[
            const SizedBox(height: 16),
            Text('Photo de la panne', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => onOpenPhoto(photo),
              child: PublicNetworkImage(
                url: photo,
                width: 320,
                height: 200,
                borderRadius: BorderRadius.circular(12),
                icon: Icons.broken_image_outlined,
              ),
            ),
            TextButton.icon(
              onPressed: () => onOpenPhoto(photo),
              icon: const Icon(Icons.zoom_in_rounded),
              label: const Text('Agrandir la photo'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canDial && onCall != null && (status == 'pending' || status == 'accepted'))
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onCall!();
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Appeler'),
                ),
              if (canAccept && onAccept != null) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onAccept!();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  child: const Text('Accepter'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDecline!();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                  child: const Text('Refuser'),
                ),
              ],
              if (status == 'accepted' && onChat != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onChat!();
                  },
                  style: FilledButton.styleFrom(backgroundColor: FeuTheme.ember),
                  child: const Text('Chat'),
                ),
              if (canMarkDone && onMarkDone != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onMarkDone!();
                  },
                  style: FilledButton.styleFrom(backgroundColor: FeuTheme.deepBlue),
                  child: const Text('Terminée'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
