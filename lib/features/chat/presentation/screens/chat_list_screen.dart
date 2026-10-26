import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// 04 — Chats.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _filter = 0;
  bool _offline = false;

  static const _filters = ['All', 'Unread', 'Groups', 'Official'];

  static const _chats = <_ChatPreview>[
    _ChatPreview(
      id: '1',
      name: 'Abebe Kebede',
      preview: 'See you tomorrow',
      time: '14:32',
      unread: 2,
      online: true,
      pinned: true,
    ),
    _ChatPreview(
      id: '2',
      name: 'Tigist Alemayehu',
      preview: 'Thanks! 🙏',
      time: '12:15',
      group: true,
    ),
    _ChatPreview(
      id: '3',
      name: 'EthioChat Support',
      preview: 'Welcome to EthioChat',
      time: 'Yesterday',
      official: true,
    ),
    _ChatPreview(
      id: '4',
      name: 'Work group',
      preview: 'Dawit: Meeting moved to 3 PM',
      time: 'Yesterday',
      unread: 5,
      group: true,
      muted: true,
    ),
    _ChatPreview(
      id: '5',
      name: 'Hanna Girma',
      preview: 'Voice message · 0:12',
      time: 'Mon',
    ),
    _ChatPreview(
      id: '6',
      name: 'Selam Bekele',
      preview: 'Sent ETB 250.00',
      time: 'Sun',
    ),
  ];

  List<_ChatPreview> get _visible {
    switch (_filter) {
      case 1:
        return _chats.where((c) => c.unread > 0).toList(growable: false);
      case 2:
        return _chats.where((c) => c.group).toList(growable: false);
      case 3:
        return _chats.where((c) => c.official).toList(growable: false);
      default:
        return _chats;
    }
  }

  Future<void> _showActions(_ChatPreview chat) async {
    final pal = EthioPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                chat.pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
              ),
              title: Text(chat.pinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: Icon(
                chat.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(chat.muted ? 'Unmute' : 'Mute'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(
                'Delete',
                style: TextStyle(color: EthioColors.danger),
              ),
              onTap: () => Navigator.pop(sheetContext),
            ),
            Divider(color: pal.line, height: 1),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final chats = _visible;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Chats',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: 'New chat',
            icon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: EthioColors.goldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: EthioColors.black),
            ),
            onPressed: () => context.push('/new-chat'),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_offline) const _OfflineBanner(),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: Sp.screen,
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: Sp.x2),
                itemBuilder: (context, i) {
                  final selected = i == _filter;
                  return ChoiceChip(
                    label: Text(_filters[i]),
                    selected: selected,
                    showCheckmark: false,
                    backgroundColor: pal.chip,
                    selectedColor: EthioColors.gold,
                    side: BorderSide(
                      color: selected ? Colors.transparent : pal.line,
                    ),
                    labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: selected ? EthioColors.black : null,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                    onSelected: (_) => setState(() => _filter = i),
                  );
                },
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? _EmptyChats(
                      message: _filter == 0
                          ? 'No chats yet'
                          : 'Nothing in ${_filters[_filter]}',
                      onNewChat: () => context.push('/new-chat'),
                    )
                  : RefreshIndicator(
                      color: EthioColors.gold,
                      onRefresh: () async {
                        setState(() => _offline = false);
                        await Future<void>.delayed(
                          const Duration(milliseconds: 600),
                        );
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          top: Sp.x2,
                          bottom: Sp.x8,
                        ),
                        itemCount: chats.length,
                        itemBuilder: (context, i) {
                          final chat = chats[i];
                          return Dismissible(
                            key: ValueKey(chat.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _showActions(chat);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: Sp.x6),
                              color: EthioColors.gold,
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                color: EthioColors.black,
                              ),
                            ),
                            child: ChatListTile(
                              title: chat.name,
                              preview: chat.preview,
                              time: chat.time,
                              unread: chat.unread,
                              pinned: chat.pinned,
                              muted: chat.muted,
                              online: chat.online,
                              onTap: () => context.push('/chats/${chat.id}'),
                              onLongPress: () => _showActions(chat),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 0,
        onTap: (i) {
          if (i == 1) context.go('/contacts');
          if (i == 2) context.go('/discover');
          if (i == 3) context.go('/me');
        },
      ),
    );
  }
}

class _ChatPreview {
  const _ChatPreview({
    required this.id,
    required this.name,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.online = false,
    this.pinned = false,
    this.muted = false,
    this.group = false,
    this.official = false,
  });

  final String id;
  final String name;
  final String preview;
  final String time;
  final int unread;
  final bool online;
  final bool pinned;
  final bool muted;
  final bool group;
  final bool official;
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.message, required this.onNewChat});

  final String message;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: Sp.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: pal.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: Sp.x4),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Sp.x1),
            Text(
              'Start a conversation with a friend.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: pal.textSecondary),
            ),
            const SizedBox(height: Sp.x4),
            EthioButton(
              label: 'New chat',
              expand: false,
              onPressed: onNewChat,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.x5,
        vertical: Sp.x2,
      ),
      color: pal.chip,
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: pal.textSecondary),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Text(
              'You are offline. Messages will send when you reconnect.',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: pal.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
