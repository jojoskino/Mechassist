import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/api_service.dart';
import '../theme/feu_theme.dart';

/// Avatar utilisateur avec pastille verte uniquement si [showOnline] et connecté.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.memoryBytes,
    this.cacheEpoch,
    this.radius = 24,
    this.showOnline = false,
    this.isOnline = false,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? memoryBytes;
  final int? cacheEpoch;
  final double radius;
  final bool showOnline;
  final bool isOnline;
  final VoidCallback? onTap;

  String? get _networkUrl {
    final resolved = ApiService.resolvePublicUrl(avatarUrl);
    if (resolved.isEmpty) return null;
    if (cacheEpoch == null) return resolved;
    final sep = resolved.contains('?') ? '&' : '?';
    return '$resolved${sep}v=$cacheEpoch';
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasMemory = memoryBytes != null && memoryBytes!.isNotEmpty;
    final networkUrl = _networkUrl;
    final hasPhoto = hasMemory || (networkUrl != null && networkUrl.isNotEmpty);

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: FeuTheme.deepBlue.withValues(alpha: 0.12),
      foregroundColor: FeuTheme.deepBlue,
      backgroundImage: hasMemory
          ? MemoryImage(memoryBytes!)
          : (networkUrl != null ? NetworkImage(networkUrl) : null),
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: AppFonts.style(fontWeight: FontWeight.w800, fontSize: radius * 0.85),
            ),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    if (!showOnline || !isOnline) {
      return avatar;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.42,
            height: radius * 0.42,
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
