import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/feu_theme.dart';

/// Ligne « Mes demandes » style liste de messages.
class RequestListTile extends StatelessWidget {
  const RequestListTile({
    super.key,
    required this.mechanicName,
    required this.vehicleType,
    required this.preview,
    required this.statusLine,
    required this.statusColor,
    this.timeLabel,
    this.onTap,
    this.trailing,
  });

  final String mechanicName;
  final String vehicleType;
  final String preview;
  final String statusLine;
  final Color statusColor;
  final String? timeLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final initial = mechanicName.isNotEmpty ? mechanicName[0].toUpperCase() : '?';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: FeuTheme.deepBlue.withValues(alpha: 0.12),
                    foregroundColor: FeuTheme.deepBlue,
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mechanicName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: FeuTheme.charcoal,
                            ),
                          ),
                        ),
                        if (timeLabel != null && timeLabel!.isNotEmpty)
                          Text(
                            timeLabel!,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$vehicleType · $preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
