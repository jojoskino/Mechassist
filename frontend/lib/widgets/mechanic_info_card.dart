import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../screens/user_profile_page.dart';
import '../theme/feu_theme.dart';
import '../utils/online_status.dart';
import '../utils/phone_launch.dart';
import 'user_avatar.dart';

/// Carte profil mécanicien (demande acceptée / en cours).
class MechanicInfoCard extends StatelessWidget {
  const MechanicInfoCard({
    super.key,
    required this.name,
    this.phone,
    this.specialty,
    this.available,
    this.isOnline,
    this.avatarUrl,
    this.avatarCacheEpoch,
    this.mechanicUser,
    this.onCall,
    this.onChat,
    this.compact = false,
  });

  final String name;
  final String? phone;
  final String? specialty;
  final bool? available;
  final bool? isOnline;
  final String? avatarUrl;
  final int? avatarCacheEpoch;
  final Map<String, dynamic>? mechanicUser;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final bool compact;

  bool get _showOnlineDot {
    final online = isOnline ?? (mechanicUser != null ? userIsOnline(mechanicUser) : (available == true));
    return online;
  }

  void _openProfile(BuildContext context) {
    final user = mechanicUser ??
        <String, dynamic>{
          'name': name,
          'phone': phone,
          'mechanic_specialty': specialty,
          'avatar_url': avatarUrl,
          'is_available': available,
          'role': 'mecanicien',
        };
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          user: Map<String, dynamic>.from(user),
          subtitle: 'Ton mécanicien',
          onMessage: onChat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openProfile(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FeuTheme.ember.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: FeuTheme.charcoal.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              UserAvatar(
                name: name,
                avatarUrl: avatarUrl ?? mechanicUser?['avatar_url']?.toString(),
                cacheEpoch: avatarCacheEpoch,
                radius: compact ? 24 : 28,
                showOnline: true,
                isOnline: _showOnlineDot,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ton mécanicien',
                      style: AppFonts.style(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    Text(
                      name,
                      style: AppFonts.style(
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        color: FeuTheme.charcoal,
                      ),
                    ),
                    if (specialty != null && specialty!.trim().isNotEmpty)
                      Text(
                        specialty!,
                        style: AppFonts.style(fontSize: 13, color: FeuTheme.deepBlue),
                      ),
                    if (phone != null && phone!.trim().isNotEmpty)
                      Text(
                        phone!,
                        style: AppFonts.style(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                  ],
                ),
              ),
              if (onCall != null && normalizePhoneForDial(phone) != null)
                IconButton(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded, color: FeuTheme.ember),
                  tooltip: 'Appeler',
                ),
              if (onChat != null)
                IconButton(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_rounded, color: FeuTheme.deepBlue),
                  tooltip: 'Chat',
                ),
              IconButton(
                onPressed: () => _openProfile(context),
                icon: const Icon(Icons.more_vert_rounded, color: FeuTheme.charcoal),
                tooltip: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
