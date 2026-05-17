import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../theme/feu_theme.dart';
import '../utils/online_status.dart';
import '../utils/phone_launch.dart';
import '../widgets/user_avatar.dart';
import 'full_screen_image_page.dart';

/// Fiche contact (style messagerie) — mécanicien ou client.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.user,
    this.subtitle,
    this.onMessage,
    this.onNavigate,
  });

  final Map<String, dynamic> user;
  final String? subtitle;
  final VoidCallback? onMessage;
  final VoidCallback? onNavigate;

  String get _name => user['name']?.toString() ?? 'Utilisateur';
  String? get _phone => user['phone']?.toString();
  String? get _specialty => user['mechanic_specialty']?.toString();
  String? get _avatarUrl => user['avatar_url']?.toString();
  bool get _isMechanic => user['role']?.toString() == 'mecanicien';
  bool get _online => userIsOnline(user);

  @override
  Widget build(BuildContext context) {
    final rating = user['rating_avg'];
    final ratingCount = user['rating_count'];

    return Scaffold(
      backgroundColor: FeuTheme.paper,
      appBar: AppBar(
        backgroundColor: FeuTheme.deepBlue,
        foregroundColor: Colors.white,
        title: Text('Profil', style: AppFonts.style(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          Center(
            child: UserAvatar(
              name: _name,
              avatarUrl: _avatarUrl,
              radius: 56,
              showOnline: _isMechanic,
              isOnline: _online,
              onTap: _avatarUrl != null && _avatarUrl!.trim().isNotEmpty
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FullScreenImagePage(
                            imageUrl: _avatarUrl!,
                            title: _name,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: AppFonts.style(fontSize: 24, fontWeight: FontWeight.w800, color: FeuTheme.charcoal),
          ),
          if (_phone != null && _phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _phone!,
              textAlign: TextAlign.center,
              style: AppFonts.style(fontSize: 16, color: Colors.grey.shade700),
            ),
          ],
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppFonts.style(fontSize: 14, color: FeuTheme.deepBlue),
            ),
          ],
          if (_isMechanic && _specialty != null && _specialty!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _specialty!,
              textAlign: TextAlign.center,
              style: AppFonts.style(fontSize: 15, fontWeight: FontWeight.w600, color: FeuTheme.ember),
            ),
          ],
          if (_isMechanic) ...[
            const SizedBox(height: 8),
            Text(
              _online ? 'En ligne' : 'Hors ligne',
              textAlign: TextAlign.center,
              style: AppFonts.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _online ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ],
          if (rating != null) ...[
            const SizedBox(height: 6),
            Text(
              'Note moyenne : $rating ★ (${ratingCount ?? 0} avis)',
              textAlign: TextAlign.center,
              style: AppFonts.style(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.call_rounded,
                  label: 'Appeler',
                  color: FeuTheme.ember,
                  onTap: normalizePhoneForDial(_phone) == null
                      ? null
                      : () => launchTelDialer(context, _phone),
                ),
              ),
              const SizedBox(width: 12),
              if (onMessage != null)
                Expanded(
                  child: _ActionTile(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Message',
                    color: FeuTheme.deepBlue,
                    onTap: onMessage,
                  ),
                ),
              if (onNavigate != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.directions_rounded,
                    label: 'Itinéraire',
                    color: FeuTheme.deepBlue,
                    onTap: onNavigate,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: onTap == null ? Colors.grey : color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppFonts.style(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: onTap == null ? Colors.grey : FeuTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
