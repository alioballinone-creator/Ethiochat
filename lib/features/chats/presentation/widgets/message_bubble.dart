import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/app_spacing.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';

enum BubbleType { sent, received }

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.type,
    required this.time,
    this.status,
  });

  final String text;
  final BubbleType type;
  final String time;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final isSent = type == BubbleType.sent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSent
              ? (isDark ? EthioColors.blackSoft : EthioColors.creamDark)
              : (isDark ? const Color(0xFF252525) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radius),
            topRight: const Radius.circular(AppSpacing.radius),
            bottomLeft: Radius.circular(isSent ? AppSpacing.radius : 4),
            bottomRight: Radius.circular(isSent ? 4 : AppSpacing.radius),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF2B2924) : EthioColors.creamDark,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (isSent && status != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    status!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: status == 'read'
                              ? EthioColors.goldDeep
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
