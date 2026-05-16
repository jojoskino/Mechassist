import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/feu_theme.dart';
import '../widgets/mechassist_logo.dart';

/// Onboarding en 3 écrans illustrés.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const _prefKey = 'onboarding_complete';

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPageData(
      icon: Icons.map_rounded,
      accent: FeuTheme.deepBlue,
      title: 'Trouvez l\'aide partout',
      body: 'Visualisez les mécaniciens certifiés autour de vous en temps réel sur la carte interactive.',
      chips: ['Carte live', 'Filtres', 'Géolocalisation'],
    ),
    _OnboardPageData(
      icon: Icons.warning_amber_rounded,
      accent: FeuTheme.ember,
      title: 'Signalez une panne',
      body: 'Décrivez le problème, choisissez l\'urgence et ajoutez une photo : le mécanicien la voit sur la demande.',
      chips: ['Photo panne', 'Urgence', 'Adresse GPS'],
    ),
    _OnboardPageData(
      icon: Icons.chat_bubble_rounded,
      accent: Color(0xFF2E7D32),
      title: 'Suivez en direct',
      body: 'Chat, appels et notifications push : restez informé de l\'acceptation et des messages.',
      chips: ['Chat', 'Notifications', 'Historique'],
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool toRegister}) async {
    await WelcomeScreen.markOnboardingComplete();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, toRegister ? '/register' : '/login');
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _finish(toRegister: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const MechAssistLogoChip(size: 36),
                  const SizedBox(width: 10),
                  Text(
                    'MechAssist',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: FeuTheme.deepBlue,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _finish(toRegister: false),
                    child: Text('Passer', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardIllustration(page: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? FeuTheme.deepBlue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(_page < _pages.length - 1 ? Icons.arrow_forward_rounded : Icons.login_rounded),
                    label: Text(
                      _page < _pages.length - 1 ? 'Suivant' : 'Commencer',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: FeuTheme.deepBlue,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  if (_page == _pages.length - 1) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _finish(toRegister: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FeuTheme.deepBlue,
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: FeuTheme.deepBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Créer un compte', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageData {
  const _OnboardPageData({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.chips,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final List<String> chips;
}

class _OnboardIllustration extends StatelessWidget {
  const _OnboardIllustration({required this.page});

  final _OnboardPageData page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    page.accent.withValues(alpha: 0.12),
                    FeuTheme.pageGrey,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: page.accent.withValues(alpha: 0.15),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Icon(page.icon, size: 48, color: page.accent.withValues(alpha: 0.25)),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: page.accent.withValues(alpha: 0.2),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(page.icon, size: 72, color: page.accent),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: page.chips
                            .map(
                              (c) => Chip(
                                label: Text(c, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: page.accent.withValues(alpha: 0.35)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: FeuTheme.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
