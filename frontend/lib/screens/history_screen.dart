import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../theme/feu_theme.dart';
import '../widgets/request_list_tile.dart';

/// Historique des interventions (terminées, refusées, annulées).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.requests,
    required this.onRefresh,
    this.mechanicNameFor,
    this.onOpenRequest,
  });

  final List<dynamic> requests;
  final Future<void> Function() onRefresh;
  final String Function(Map<String, dynamic> request)? mechanicNameFor;
  final void Function(Map<String, dynamic> request)? onOpenRequest;

  static bool isHistorical(String? status) {
    switch (status) {
      case 'completed':
      case 'declined':
      case 'cancelled':
        return true;
      default:
        return false;
    }
  }

  String _statusLine(Map<String, dynamic> r) {
    switch (r['status']?.toString()) {
      case 'completed':
        return 'Terminée';
      case 'declined':
        return 'Refusée';
      case 'cancelled':
        return 'Annulée';
      case 'accepted':
        return 'Acceptée';
      case 'pending':
        return 'En attente';
      default:
        return r['status']?.toString() ?? '—';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade700;
      case 'declined':
      case 'cancelled':
        return Colors.red.shade700;
      case 'accepted':
        return FeuTheme.deepBlue;
      default:
        return Colors.grey.shade700;
    }
  }

  String _timeLabel(Map<String, dynamic> r) {
    final raw = r['updated_at']?.toString() ?? r['created_at']?.toString() ?? '';
    if (raw.length >= 16) return raw.substring(0, 16).replaceFirst('T', ' ');
    return '';
  }

  String _titleFor(Map<String, dynamic> r) {
    if (mechanicNameFor != null) {
      return mechanicNameFor!(r);
    }
    final client = r['client'];
    if (client is Map) {
      return client['name']?.toString() ?? 'Client';
    }
    return 'Intervention';
  }

  @override
  Widget build(BuildContext context) {
    final historical = requests
        .where((raw) {
          final r = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
          return isHistorical(r['status']?.toString());
        })
        .map((raw) => raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map))
        .toList()
      ..sort((a, b) {
        final ta = a['updated_at']?.toString() ?? a['created_at']?.toString() ?? '';
        final tb = b['updated_at']?.toString() ?? b['created_at']?.toString() ?? '';
        return tb.compareTo(ta);
      });

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: FeuTheme.ember,
      child: historical.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                Icon(Icons.history_rounded, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Aucun historique',
                  textAlign: TextAlign.center,
                  style: AppFonts.style(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Les interventions terminées ou clôturées apparaîtront ici.',
                    textAlign: TextAlign.center,
                    style: AppFonts.style(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: historical.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: Colors.grey.shade200),
              itemBuilder: (_, i) {
                final r = historical[i];
                final status = r['status']?.toString();
                return RequestListTile(
                  mechanicName: _titleFor(r),
                  vehicleType: r['vehicle_type']?.toString() ?? '—',
                  preview: r['description']?.toString() ?? '—',
                  statusLine: _statusLine(r),
                  statusColor: _statusColor(status),
                  timeLabel: _timeLabel(r),
                  onTap: onOpenRequest == null ? null : () => onOpenRequest!(r),
                );
              },
            ),
    );
  }
}
