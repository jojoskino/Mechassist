import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/feu_theme.dart';

/// Miniature réseau avec URL corrigée, cache mémoire et placeholder si échec.
class PublicNetworkImage extends StatelessWidget {
  const PublicNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.icon = Icons.image_not_supported_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiService.resolvePublicUrl(url);
    final fixedH = height ?? 52;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width != null && width!.isFinite ? (width! * dpr).round() : null;
    final cacheH = (fixedH * dpr).round();

    if (resolved.isEmpty) {
      return _placeholder(width, fixedH);
    }

    Widget imageBuilder(double w, double h) {
      return Image.network(
        resolved,
        headers: ApiService.imageRequestHeaders,
        width: w.isFinite ? w : null,
        height: h,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        errorBuilder: (_, __, ___) => _placeholder(w, h),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: w.isFinite ? w : null,
            height: h,
            alignment: Alignment.center,
            color: Colors.grey.shade100,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FeuTheme.ember.withValues(alpha: 0.85),
              ),
            ),
          );
        },
      );
    }

    if (width != null && width!.isFinite) {
      final w = width!;
      Widget img = imageBuilder(w, fixedH);
      if (borderRadius != null) {
        img = ClipRRect(borderRadius: borderRadius!, child: img);
      }
      return RepaintBoundary(child: img);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 280.0;
        Widget img = imageBuilder(w, fixedH);
        if (borderRadius != null) {
          img = ClipRRect(borderRadius: borderRadius!, child: img);
        }
        return RepaintBoundary(
          child: SizedBox(width: w, height: fixedH, child: img),
        );
      },
    );
  }

  Widget _placeholder(double? w, double h) {
    final widthVal = (w != null && w.isFinite) ? w : null;
    return Container(
      width: widthVal,
      height: h,
      alignment: Alignment.center,
      color: FeuTheme.deepBlue.withValues(alpha: 0.08),
      child: Icon(icon, color: FeuTheme.deepBlue.withValues(alpha: 0.45), size: h * 0.4),
    );
  }
}
