import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import '../theme/feu_theme.dart';

enum MechAssistNavVariant { client, mechanic }

/// Barre de navigation basse (maquettes).
class MechAssistBottomNav extends StatelessWidget {
  const MechAssistBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badges = const {},
    this.variant = MechAssistNavVariant.client,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;
  final MechAssistNavVariant variant;

  static const _clientItems = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
    (Icons.search_outlined, Icons.search_rounded, 'Recherche'),
    (Icons.build_outlined, Icons.build_rounded, 'Demandes'),
    (Icons.history_outlined, Icons.history_rounded, 'Historique'),
  ];

  static const _mechanicItems = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
    (Icons.history_outlined, Icons.history_rounded, 'Historique'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Compte'),
  ];

  List<(IconData, IconData, String)> get _items =>
      variant == MechAssistNavVariant.mechanic ? _mechanicItems : _clientItems;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FeuTheme.charcoal.withValues(alpha: 0.08))),
        boxShadow: [
          BoxShadow(
            color: FeuTheme.charcoal.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              final badge = badges[i] ?? 0;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected ? FeuTheme.deepBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: badge > 0,
                          label: Text(badge > 99 ? '99+' : '$badge', style: AppFonts.style(fontSize: 10)),
                          backgroundColor: Colors.red.shade600,
                          child: Icon(
                            selected ? item.$2 : item.$1,
                            size: 24,
                            color: selected ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: AppFonts.style(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
    );
  }
}
