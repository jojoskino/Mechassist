import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/public_network_image.dart';

/// Affichage plein écran d’une photo de profil ou média.
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
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: PublicNetworkImage(
            url: resolved,
            fit: BoxFit.contain,
            height: MediaQuery.sizeOf(context).height * 0.75,
          ),
        ),
      ),
    );
  }
}
