import 'package:flutter/material.dart';

/// Accusés de lecture style messagerie : une coche = envoyé, deux = lu.
class MessageReadTicks extends StatelessWidget {
  const MessageReadTicks({super.key, required this.readAt});

  final String? readAt;

  bool get _isRead {
    final s = readAt?.trim() ?? '';
    return s.isNotEmpty && s != 'null';
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      _isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 16,
      color: _isRead ? const Color(0xFF34B7F1) : Colors.black38,
      semanticLabel: _isRead ? 'Lu' : 'Envoyé',
    );
  }
}

/// Heure + coches pour bulles « moi ».
class MessageTimeWithTicks extends StatelessWidget {
  const MessageTimeWithTicks({
    super.key,
    required this.time,
    required this.mine,
    this.readAt,
  });

  final String time;
  final bool mine;
  final String? readAt;

  @override
  Widget build(BuildContext context) {
    if (time.isEmpty && !mine) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (time.isNotEmpty)
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: mine ? Colors.black45 : Colors.black38,
            ),
          ),
        if (mine) ...[
          if (time.isNotEmpty) const SizedBox(width: 4),
          MessageReadTicks(readAt: readAt),
        ],
      ],
    );
  }
}
