import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../theme/feu_theme.dart';

/// Titre de section en petites capitales bleues (maquette profil / réglages).
class MechAssistSectionLabel extends StatelessWidget {
  const MechAssistSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.style(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: FeuTheme.deepBlue,
        ),
      ),
    );
  }
}

/// Carte blanche arrondie pour regrouper des lignes (profil, préférences).
class MechAssistSectionCard extends StatelessWidget {
  const MechAssistSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FeuTheme.cardShell(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: FeuTheme.charcoal.withValues(alpha: 0.07)),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Ligne cliquable dans une section (chevron à droite).
class MechAssistSettingsTile extends StatelessWidget {
  const MechAssistSettingsTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: icon != null
          ? Icon(icon, color: FeuTheme.deepBlue.withValues(alpha: 0.85), size: 22)
          : null,
      title: Text(
        title,
        style: AppFonts.style(
          fontSize: 13,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppFonts.style(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: FeuTheme.charcoal,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400)
              : null),
      isThreeLine: subtitle != null,
    );
  }
}
