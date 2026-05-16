import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/feu_theme.dart';

/// Panneau « Besoin d'aide ? » sur la carte client (maquette accueil).
class ClientHomeHelpPanel extends StatelessWidget {
  const ClientHomeHelpPanel({
    super.key,
    required this.mechanicsNearby,
    required this.onReportBreakdown,
    this.onQuickPreset,
    this.busy = false,
  });

  final int mechanicsNearby;
  final VoidCallback onReportBreakdown;
  final void Function(String presetDescription)? onQuickPreset;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Besoin d\'aide ?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: FeuTheme.charcoal,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FeuTheme.urgencyLightBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                mechanicsNearby > 0
                    ? '$mechanicsNearby Mécano${mechanicsNearby > 1 ? 's' : ''} à proximité'
                    : 'Recherche en cours…',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FeuTheme.urgencyLightFg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: busy ? null : onReportBreakdown,
          icon: const Icon(Icons.warning_amber_rounded, color: FeuTheme.charcoal),
          label: Text(
            'Signaler une panne',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: FeuTheme.charcoal,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: FeuTheme.ember,
            foregroundColor: FeuTheme.charcoal,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (onQuickPreset != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickChip(
                  icon: Icons.tire_repair_rounded,
                  label: 'Pneu crevé',
                  onTap: busy ? null : () => onQuickPreset!('Pneu crevé — besoin d\'assistance sur place.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickChip(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Batterie',
                  onTap: busy ? null : () => onQuickPreset!('Batterie à plat — démarrage impossible.'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F2F5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: FeuTheme.deepBlue, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FeuTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
