import 'package:flutter/material.dart';

/// Bannière compacte (pas de débordement horizontal) pour erreurs dans [MapsDiscoveryShell].
class MapsSheetBanner extends StatelessWidget {
  const MapsSheetBanner({
    super.key,
    required this.message,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
