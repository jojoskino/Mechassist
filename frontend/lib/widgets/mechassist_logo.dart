import 'package:flutter/material.dart';

/// Logo MechAssist (fichier `assets/images/logo.png`) dans un médaillon blanc, comme sur le splash.
class MechAssistLogoBadge extends StatelessWidget {
  const MechAssistLogoBadge({
    super.key,
    this.size = 108,
    this.elevation = 0,
  });

  final double size;
  final double elevation;

  static const String _assetPath = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    final diameter = size;
    return Material(
      elevation: elevation,
      shape: const CircleBorder(),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(
            _assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.miscellaneous_services_rounded,
              size: size * 0.48,
              color: const Color(0xFF0F4C75),
            ),
          ),
        ),
      ),
    );
  }
}
