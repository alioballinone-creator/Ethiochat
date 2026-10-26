import 'package:flutter/material.dart';
import '../ethio_colors.dart';
import 'ethio_avatar.dart';

/// One row of the Chats list. 72dp tall; pinned rows get a tinted background.
class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.title,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.avatarUrl,
    this.online = false,
    this.onTap,
    this.onLongPress,
  });

  final String title, preview, time;
  final int unread;
  final bool pinned, muted, online;
  final String? avatarUrl;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: pinned ? pal.surface2 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(children: [
            EthioAvatar(
                name: title, imageUrl: avatarUrl, size: 54, online: online),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(color: pal.textSecondary)),
                  ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(time,
                  style: t.labelSmall!.copyWith(
                      color: unread > 0
                          ? (isDark ? EthioColors.gold : EthioColors.goldDeep)
                          : pal.textTertiary,
                      fontWeight:
                          unread > 0 ? FontWeight.w600 : FontWeight.w400)),
              const SizedBox(height: 6),
              if (unread > 0)
                _Badge(count: unread, muted: muted)
              else if (muted)
                Icon(Icons.volume_off_rounded,
                    size: 16, color: pal.textTertiary)
              else
                const SizedBox(height: 20),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.muted});
  final int count;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? pal.textTertiary : EthioColors.gold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: EthioColors.black,
              fontFamily: 'Poppins')),
    );
  }
}
