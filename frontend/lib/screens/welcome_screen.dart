import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/feu_theme.dart';
import '../widgets/mechassist_logo.dart';

/// Écran d’accueil / onboarding (maquette « Trouvez l'aide partout »).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const MechAssistLogoChip(size: 36),
                  const SizedBox(width: 10),
                  Text(
                    'MechAssist',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: FeuTheme.deepBlue,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: Text('Passer', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FeuTheme.pageGrey,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: FeuTheme.deepBlue.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.map_rounded, size: 120, color: FeuTheme.deepBlue.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 28),
              Text(
                'Trouvez l\'aide partout',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: FeuTheme.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Visualisez les mécaniciens certifiés autour de vous en temps réel sur notre carte interactive.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 8,
                    decoration: BoxDecoration(
                      color: FeuTheme.deepBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text('Suivant', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: FeuTheme.deepBlue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FeuTheme.deepBlue,
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: FeuTheme.deepBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Créer un compte', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
