import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/feu_theme.dart';
import 'mechassist_logo.dart';

/// Barre supérieure : marque MechAssist + badges demandes / notifications.
class DashboardBrandBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardBrandBar({
    super.key,
    this.pendingRequestsCount = 0,
    this.unreadNotificationsCount = 0,
    required this.onOpenNotifications,
    this.onOpenRequests,
    this.trailing,
  });

  final int pendingRequestsCount;
  final int unreadNotificationsCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback? onOpenRequests;
  final List<Widget>? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Widget _badgeIcon({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: Colors.red,
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: FeuTheme.appBarSolid,
      foregroundColor: Colors.white,
      elevation: 1,
      shadowColor: FeuTheme.charcoal.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          const MechAssistLogoChip(size: 34),
          const SizedBox(width: 10),
          Text(
            'MechAssist',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        if (onOpenRequests != null)
          _badgeIcon(
            icon: Icons.assignment_outlined,
            count: pendingRequestsCount,
            onTap: onOpenRequests!,
            tooltip: 'Mes demandes',
          ),
        _badgeIcon(
          icon: Icons.notifications_outlined,
          count: unreadNotificationsCount,
          onTap: onOpenNotifications,
          tooltip: 'Notifications',
        ),
        ...?trailing,
      ],
    );
  }
}
