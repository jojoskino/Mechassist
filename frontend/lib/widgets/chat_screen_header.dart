import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/user_profile_page.dart';
import '../theme/feu_theme.dart';
import '../utils/online_status.dart';
import '../utils/phone_launch.dart';
import 'user_avatar.dart';

/// En-tête discussion fusionné : contact, appel et menu à droite.
class ChatScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatScreenHeader({
    super.key,
    required this.peerName,
    this.roleLabel,
    this.phone,
    this.specialty,
    this.avatarUrl,
    this.avatarCacheEpoch,
    this.peerUser,
    this.onRefresh,
    this.onShowDetails,
    this.onCall,
    this.onOpenProfile,
  });

  final String peerName;
  final String? roleLabel;
  final String? phone;
  final String? specialty;
  final String? avatarUrl;
  final int? avatarCacheEpoch;
  final Map<String, dynamic>? peerUser;
  final VoidCallback? onRefresh;
  final VoidCallback? onShowDetails;
  final VoidCallback? onCall;
  final VoidCallback? onOpenProfile;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  bool get _isOnline {
    if (peerUser != null) return userIsOnline(peerUser);
    return false;
  }

  bool get _isMechanicPeer => peerUser?['role']?.toString() == 'mecanicien' || roleLabel?.contains('mécanicien') == true;

  void _openMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRefresh != null)
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: FeuTheme.deepBlue),
                title: Text('Actualiser', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRefresh!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: FeuTheme.deepBlue),
              title: Text('Voir le profil', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                if (onOpenProfile != null) {
                  onOpenProfile!();
                } else if (onShowDetails != null) {
                  onShowDetails!();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _defaultOpenProfile(BuildContext context) {
    final user = peerUser ??
        <String, dynamic>{
          'name': peerName,
          'phone': phone,
          'mechanic_specialty': specialty,
          'avatar_url': avatarUrl,
          'role': _isMechanicPeer ? 'mecanicien' : 'client',
        };
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          user: Map<String, dynamic>.from(user),
          subtitle: roleLabel,
          onMessage: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final canCall = onCall != null && normalizePhoneForDial(phone) != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: FeuTheme.deepBlue,
        elevation: 2,
        shadowColor: FeuTheme.charcoal.withValues(alpha: 0.2),
        child: Padding(
          padding: EdgeInsets.fromLTRB(2, top + 2, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              UserAvatar(
                name: peerName,
                avatarUrl: avatarUrl ?? peerUser?['avatar_url']?.toString(),
                cacheEpoch: avatarCacheEpoch,
                radius: 24,
                showOnline: _isMechanicPeer,
                isOnline: _isOnline,
                onTap: () => onOpenProfile != null ? onOpenProfile!() : _defaultOpenProfile(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => onOpenProfile != null ? onOpenProfile!() : _defaultOpenProfile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (roleLabel != null && roleLabel!.isNotEmpty)
                        Text(
                          roleLabel!,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (specialty != null && specialty!.trim().isNotEmpty)
                        Text(
                          specialty!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                          ),
                        )
                      else if (phone != null && phone!.trim().isNotEmpty)
                        Text(
                          phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (canCall)
                IconButton(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded, color: FeuTheme.flame, size: 28),
                  tooltip: 'Appeler',
                ),
              IconButton(
                onPressed: () => _openMenu(context),
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: 'Options',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
