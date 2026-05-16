import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Polices Poppins : fichiers locaux (mobile) + préchargement Web.
abstract final class AppFonts {
  static const family = 'Poppins';
  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> ensureLoaded() async {
    if (_ready) return;
    if (kIsWeb) {
      await GoogleFonts.pendingFonts([
        GoogleFonts.poppins(fontWeight: FontWeight.w400),
        GoogleFonts.poppins(fontWeight: FontWeight.w500),
        GoogleFonts.poppins(fontWeight: FontWeight.w600),
        GoogleFonts.poppins(fontWeight: FontWeight.w700),
        GoogleFonts.poppins(fontWeight: FontWeight.w800),
      ]);
    }
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
