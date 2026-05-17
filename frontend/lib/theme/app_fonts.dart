import 'package:flutter/material.dart';

/// Polices Poppins embarquées (assets) — identiques sur mobile et navigateur.
abstract final class AppFonts {
  static const family = 'Poppins';
  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> ensureLoaded() async {
    if (_ready) return;
    _ready = true;
  }

  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: const ['sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme textTheme(TextTheme base) {
    TextStyle apply(TextStyle? s, {FontWeight? w}) {
      if (s == null) return style(fontWeight: w);
      return s.copyWith(fontFamily: family, fontFamilyFallback: const ['sans-serif']);
    }

    return base.copyWith(
      displayLarge: apply(base.displayLarge),
      displayMedium: apply(base.displayMedium),
      displaySmall: apply(base.displaySmall),
      headlineLarge: apply(base.headlineLarge),
      headlineMedium: apply(base.headlineMedium),
      headlineSmall: apply(base.headlineSmall),
      titleLarge: apply(base.titleLarge, w: FontWeight.w700),
      titleMedium: apply(base.titleMedium, w: FontWeight.w600),
      titleSmall: apply(base.titleSmall, w: FontWeight.w600),
      bodyLarge: apply(base.bodyLarge),
      bodyMedium: apply(base.bodyMedium),
      bodySmall: apply(base.bodySmall),
      labelLarge: apply(base.labelLarge, w: FontWeight.w600),
      labelMedium: apply(base.labelMedium),
      labelSmall: apply(base.labelSmall),
    );
  }
}
