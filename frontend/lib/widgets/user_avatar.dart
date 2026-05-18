import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/api_service.dart';
import '../services/profile_avatar_session.dart';
import '../theme/feu_theme.dart';

/// Avatar utilisateur : mémoire locale, puis réseau avec en-têtes (ngrok / CORS Web).
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

  String? get _resolvedNetworkUrl {
    final resolved = ApiService.resolvePublicUrl(avatarUrl);
    if (resolved.isEmpty) return null;
    final epoch = cacheEpoch ?? ProfileAvatarSession.epochForUrl(avatarUrl) ?? 0;
    if (epoch <= 0) return resolved;
    final sep = resolved.contains('?') ? '&' : '?';
    return '$resolved${sep}v=$epoch';
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final diameter = radius * 2;
    final hasMemory = memoryBytes != null && memoryBytes!.isNotEmpty;
    final networkUrl = _resolvedNetworkUrl;

    Widget face;
    if (hasMemory) {
      face = ClipOval(
        child: Image.memory(
          memoryBytes!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );
    } else if (networkUrl != null && networkUrl.isNotEmpty) {
      face = ClipOval(
        key: ValueKey<String>(networkUrl),
        child: Image.network(
          networkUrl,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          headers: ApiService.imageRequestHeaders,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _initialCircle(diameter, initial),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              color: FeuTheme.deepBlue.withValues(alpha: 0.08),
              child: SizedBox(
                width: radius * 0.55,
                height: radius * 0.55,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FeuTheme.ember.withValues(alpha: 0.9),
                ),
              ),
            );
          },
        ),
      );
    } else {
      face = _initialCircle(diameter, initial);
    }

    Widget avatar = SizedBox(width: diameter, height: diameter, child: face);

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

  Widget _initialCircle(double diameter, String initial) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FeuTheme.deepBlue.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppFonts.style(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.85,
          color: FeuTheme.deepBlue,
        ),
      ),
    );
  }
}
