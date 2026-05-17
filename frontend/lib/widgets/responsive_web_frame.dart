import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cadre Web : pleine hauteur, largeur max sur grand écran, pas de débordement horizontal.
class ResponsiveWebFrame extends StatelessWidget {
  const ResponsiveWebFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final phoneLike = maxW <= 520;
        final contentMaxW = phoneLike ? maxW : (maxW > 960 ? 920.0 : maxW);

        Widget body = child;
        if (!phoneLike && maxW > 600) {
          body = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxW, maxHeight: maxH),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: body,
              ),
            ),
          );
        }

        return ColoredBox(
          color: const Color(0xFFE8ECEF),
          child: SizedBox(width: maxW, height: maxH, child: body),
        );
      },
    );
  }
}
