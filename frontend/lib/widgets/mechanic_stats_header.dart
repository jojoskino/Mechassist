import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/feu_theme.dart';

/// En-tête tableau de bord mécano (statut + cartes stats, maquette).
class MechanicStatsHeader extends StatelessWidget {
  const MechanicStatsHeader({
    super.key,
    required this.isOnline,
    required this.onOnlineChanged,
    required this.completedThisMonth,
    required this.pendingCount,
    this.weeklyRevenueLabel,
  });

  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final int completedThisMonth;
  final int pendingCount;
  final String? weeklyRevenueLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: FeuTheme.cardShell(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statut actuel',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline ? 'En ligne' : 'Hors ligne',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isOnline ? FeuTheme.urgencyLightFg : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusToggle(isOnline: isOnline, onChanged: onOnlineChanged),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                color: FeuTheme.statsBlue,
                title: 'Revenus de la semaine',
                value: weeklyRevenueLabel ?? '—',
                subtitle: 'Estimation locale',
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                color: FeuTheme.statsOrange,
                title: 'Missions terminées',
                value: '$completedThisMonth',
                subtitle: 'Ce mois-ci',
                icon: Icons.check_circle_outline_rounded,
                darkText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Demandes entrantes',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: FeuTheme.charcoal),
            ),
            const Spacer(),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount nouvelle${pendingCount > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('En ligne', isOnline, () => onChanged(true), FeuTheme.urgencyLightFg),
          _pill('Hors ligne', !isOnline, () => onChanged(false), Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap, Color fg) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? (label == 'En ligne' ? FeuTheme.urgencyLightFg : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected && label == 'En ligne' ? Colors.white : fg,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.darkText = false,
  });

  final Color color;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    final fg = darkText ? FeuTheme.charcoal : Colors.white;
    final subFg = darkText ? Colors.grey.shade800 : Colors.white.withValues(alpha: 0.88);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg.withValues(alpha: 0.85), size: 22),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: subFg)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: fg),
          ),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: subFg)),
        ],
      ),
    );
  }
}
