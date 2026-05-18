import 'package:flutter/material.dart';

import '../theme/feu_theme.dart';
import '../utils/phone_launch.dart';
import '../widgets/public_network_image.dart';
import '../widgets/user_avatar.dart';

/// Détail demande client (page plein écran — évite les crashs AlertDialog sur Web).
class ClientRequestDetailPage extends StatelessWidget {
  const ClientRequestDetailPage({
    super.key,
    required this.requestIdLabel,
    required this.statusLine,
    required this.mechanicName,
    this.mechanic,
    required this.avatarCacheEpoch,
    required this.mechanicMarkedComplete,
    required this.needsRating,
    this.outcomeLabel,
    this.ratingStars,
    this.ratingComment,
    required this.vehicleType,
    required this.description,
    this.clientAddress,
    this.photoUrl,
    required this.status,
    this.onChat,
    this.onCancel,
    this.onCloseIntervention,
    this.onRate,
    required this.onOpenPhoto,
  });

  final String requestIdLabel;
  final String statusLine;
  final String mechanicName;
  final Map<String, dynamic>? mechanic;
  final int avatarCacheEpoch;
  final bool mechanicMarkedComplete;
  final bool needsRating;
  final String? outcomeLabel;
  final int? ratingStars;
  final String? ratingComment;
  final String vehicleType;
  final String description;
  final String? clientAddress;
  final String? photoUrl;
  final String status;
  final VoidCallback? onChat;
  final VoidCallback? onCancel;
  final VoidCallback? onCloseIntervention;
  final VoidCallback? onRate;
  final void Function(String url) onOpenPhoto;

  bool get _hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();
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
          if (mechanic != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      name: mechanicName,
                      avatarUrl: mechanic!['avatar_url']?.toString(),
                      cacheEpoch: avatarCacheEpoch,
                      radius: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ton mécanicien',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            mechanicName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                          ),
                          if (mechanic!['mechanic_specialty'] != null &&
                              mechanic!['mechanic_specialty'].toString().trim().isNotEmpty)
                            Text(
                              mechanic!['mechanic_specialty'].toString(),
                              style: const TextStyle(fontSize: 13, color: FeuTheme.deepBlue),
                            ),
                          if (mechanic!['phone'] != null && mechanic!['phone'].toString().trim().isNotEmpty)
                            TextButton.icon(
                              onPressed: () => launchTelDialer(context, mechanic!['phone']?.toString()),
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text('Appeler'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            Text('Mécanicien : $mechanicName', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('Véhicule : $vehicleType'),
          const SizedBox(height: 8),
          Text(statusLine, style: TextStyle(color: Colors.grey.shade800)),
          if (status == 'completed' && outcomeLabel != null) ...[
            const SizedBox(height: 8),
            Text('Résultat : $outcomeLabel'),
          ],
          if (ratingStars != null) ...[
            const SizedBox(height: 8),
            Text('Ta note : $ratingStars/5 ★'),
            if (ratingComment != null && ratingComment!.trim().isNotEmpty)
              Text('« $ratingComment »', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Text(description),
          if (clientAddress != null && clientAddress!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Repère : $clientAddress', style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
          ],
          if (status == 'accepted' && !mechanicMarkedComplete) ...[
            const SizedBox(height: 12),
            Text(
              'Le mécanicien doit marquer l’intervention comme terminée avant que tu puisses clôturer.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ],
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
            alignment: WrapAlignment.end,
            children: [
              if (status == 'pending' && onCancel != null)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onCancel!();
                  },
                  child: Text('Annuler', style: TextStyle(color: Colors.red.shade800)),
                ),
              if (status == 'accepted' && onChat != null)
                FilledButton(onPressed: () {
                  Navigator.pop(context);
                  onChat!();
                }, child: const Text('Chat')),
              if (status == 'accepted' && mechanicMarkedComplete && onCloseIntervention != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onCloseIntervention!();
                  },
                  style: FilledButton.styleFrom(backgroundColor: FeuTheme.deepBlue),
                  child: const Text('Clôturer'),
                ),
              if (needsRating && onRate != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onRate!();
                  },
                  style: FilledButton.styleFrom(backgroundColor: FeuTheme.ember),
                  child: const Text('Noter'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
