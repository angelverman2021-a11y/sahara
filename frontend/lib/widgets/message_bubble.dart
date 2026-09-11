import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    final isCritical = message.priority == MessagePriority.critical ||
        message.type == MessageType.sosAlert;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isCritical
              ? AppTheme.emergencyRedLight
              : isMe
                  ? const Color(0xFFE2E8F0)
                  : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: isCritical
                ? AppTheme.emergencyRedBorder
                : isMe
                    ? AppTheme.surfaceBorderStrong
                    : AppTheme.surfaceBorder,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isCritical) ...[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.emergencyRed),
                  SizedBox(width: 4),
                  Text(
                    'CRITICAL ALERT',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.emergencyRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            Text(
              message.content,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14.5,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.hops} ${message.hops == 1 ? "hop" : "hops"}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('•', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                const SizedBox(width: 4),
                Text(
                  message.timeFormatted,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isDelivered ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: message.isDelivered
                        ? AppTheme.activeGreen
                        : AppTheme.textMuted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
