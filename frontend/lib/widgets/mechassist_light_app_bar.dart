import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../theme/feu_theme.dart';
import 'mechassist_logo.dart';
import 'user_avatar.dart';

/// En-tête blanc des tableaux de bord (maquette : menu, MechAssist bleu, actions).
class MechAssistLightAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MechAssistLightAppBar({
    super.key,
    this.onMenu,
    this.onProfile,
    this.profileInitial,
    this.profileAvatarUrl,
    this.profileAvatarCacheEpoch,
    this.actions = const [],
    this.showLogo = true,
  });

  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final String? profileInitial;
  final String? profileAvatarUrl;
  final int? profileAvatarCacheEpoch;
  final List<Widget> actions;
  final bool showLogo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      foregroundColor: FeuTheme.deepBlue,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: FeuTheme.charcoal.withValues(alpha: 0.08)),
      ),
      title: Row(
        children: [
          if (onMenu != null)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded, color: FeuTheme.deepBlue, size: 26),
              tooltip: 'Menu',
            )
          else
            const SizedBox(width: 8),
          if (showLogo) ...[
            const MechAssistLogoChip(size: 32),
            const SizedBox(width: 8),
          ],
          Text(
            'MechAssist',
            style: AppFonts.style(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: FeuTheme.deepBlue,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        ...actions,
        if (onProfile != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UserAvatar(
              name: profileInitial ?? 'M',
              avatarUrl: profileAvatarUrl,
              cacheEpoch: profileAvatarCacheEpoch,
              radius: 20,
              onTap: onProfile,
            ),
          ),
      ],
    );
  }
}
