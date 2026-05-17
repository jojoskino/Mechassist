import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/app_notification_hub.dart';
import '../services/notification_navigation.dart';
import '../theme/feu_theme.dart';

/// Contenu liste des notifications (sans barre — utilisé dans une page poussée).
class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  final _hub = AppNotificationHub.instance;

  @override
  void initState() {
    super.initState();
    _hub.addListener(_onHub);
  }

  @override
  void dispose() {
    _hub.removeListener(_onHub);
    super.dispose();
  }

  void _onHub() {
    if (mounted) setState(() {});
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_rounded;
      case 'new_request':
      case 'request_accepted':
      case 'request_declined':
      case 'request_cancelled':
      case 'request_completed':
        return Icons.build_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _hub.items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Aucune notification',
                style: AppFonts.style(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Les messages et mises à jour de demandes apparaîtront ici.',
                textAlign: TextAlign.center,
                style: AppFonts.style(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, i) {
        final n = items[i];
        final time =
            '${n.receivedAt.hour.toString().padLeft(2, '0')}:${n.receivedAt.minute.toString().padLeft(2, '0')}';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: FeuTheme.ember.withValues(alpha: 0.15),
            child: Icon(_iconFor(n.type), color: FeuTheme.deepBlue),
          ),
          title: Text(n.title, style: AppFonts.style(fontWeight: FontWeight.w600)),
          subtitle: Text(
            n.body.isEmpty ? n.type : n.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.style(fontSize: 13),
          ),
          trailing: Text(time, style: AppFonts.style(fontSize: 12, color: Colors.grey.shade600)),
          onTap: () {
            _hub.markAllRead();
            NotificationNavigation.handleDataMap(n.data);
          },
        );
      },
    );
  }
}

/// Page notifications (ouverte depuis l’icône en haut — retour normal).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = AppNotificationHub.instance;
    return Scaffold(
      backgroundColor: FeuTheme.paper,
      appBar: AppBar(
        title: Text('Notifications', style: AppFonts.style(fontWeight: FontWeight.w700)),
        backgroundColor: FeuTheme.deepBlue,
        foregroundColor: Colors.white,
        actions: [
          if (hub.items.isNotEmpty)
            TextButton(
              onPressed: hub.clear,
              child: Text('Effacer', style: AppFonts.style(color: Colors.white)),
            ),
        ],
      ),
      body: const NotificationsPanel(),
    );
  }
}
