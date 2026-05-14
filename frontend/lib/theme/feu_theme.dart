import 'package:flutter/material.dart';

/// Charte « feu » (aplats uniquement, pas de dégradés) + bleu MechAssist.
abstract final class FeuTheme {
  static const Color charcoal = Color(0xFF1E1612);
  static const Color ember = Color(0xFFE85D04);
  static const Color flame = Color(0xFFF48C06);
  static const Color deepBlue = Color(0xFF0F4C75);
  static const Color appBarSolid = Color(0xFF0F4C75);
  static const Color paper = Color(0xFFFFF5EF);
  /// Fond discussion type messagerie (aplats, proche WhatsApp mais teinte MechAssist).
  static const Color chatBackdrop = Color(0xFFE5DDD5);
  /// Bulle « moi » — fond uni lisible avec texte foncé.
  static const Color mineBubble = Color(0xFFFFE4CC);
  static const Color theirsBubble = Color(0xFFFFFFFF);

  static BoxDecoration cardShell({bool emberAccent = false}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emberAccent ? ember.withValues(alpha: 0.45) : ember.withValues(alpha: 0.12),
          width: emberAccent ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: charcoal.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );

  static AppBar fireAppBar({
    required String title,
    List<Widget> actions = const [],
    bool automaticallyImplyLeading = true,
    PreferredSizeWidget? bottom,
    Widget? leading,
  }) {
    return AppBar(
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
      foregroundColor: Colors.white,
      elevation: 1,
      shadowColor: charcoal.withValues(alpha: 0.18),
      scrolledUnderElevation: 1,
      backgroundColor: appBarSolid,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
    );
  }
}
