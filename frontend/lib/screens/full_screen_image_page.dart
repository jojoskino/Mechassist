import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/feu_theme.dart';

/// Affichage plein écran d'une photo (demande, profil, chat).
class FullScreenImagePage extends StatelessWidget {
  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
    this.title,
  });

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiService.resolvePublicUrl(imageUrl);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title ?? ''),
      ),
      body: resolved.isEmpty
          ? Center(
              child: Text(
                'Image indisponible',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            )
          : Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  resolved,
                  headers: ApiService.imageRequestHeaders,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(color: FeuTheme.ember),
                    );
                  },
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          'Impossible de charger l\'image.\nVérifiez que Laravel tourne et que le stockage est lié.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
