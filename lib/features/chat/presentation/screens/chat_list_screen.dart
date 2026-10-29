import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/time_format.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../chats/domain/entities/conversation_entity.dart';
import '../../../chats/domain/entities/conversation_summary.dart';

/// 04 — Chats, backed by the local Drift database.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key, this.initialFilter = 0});

  final int initialFilter;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  int _filter = 0;
  final _listScrollController = ScrollController();
  Timer? _stateSaveTimer;
  double? _restoredScrollOffset;
  bool _scrollPositionRestored = false;

  static const _filters = ['All', 'Unread', 'Groups', 'Official', 'Archived'];
  static const _filterKey = 'chatList.filter';
  static const _scrollKey = 'chatList.scrollOffset';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter.clamp(0, _filters.length - 1).toInt();
    _listScrollController.addListener(_scheduleStateSave);
    Future<void>.microtask(_restoreListState);
  }

  @override
  void dispose() {
    _stateSaveTimer?.cancel();
    final scrollOffset = _listScrollController.hasClients
        ? _listScrollController.offset
        : null;
    unawaited(_saveListState(scrollOffset));
    _listScrollController
      ..removeListener(_scheduleStateSave)
      ..dispose();
    super.dispose();
  }

  Future<void> _restoreListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final storedFilter = prefs.getInt(_filterKey);
      setState(() {
        if (storedFilter != null) {
          _filter = storedFilter.clamp(0, _filters.length - 1).toInt();
        }
        _restoredScrollOffset = prefs.getDouble(_scrollKey);
      });
    } catch (_) {
      // The route-provided filter and initial position remain usable.
    }
  }

  void _scheduleStateSave() {
    _stateSaveTimer?.cancel();
    _stateSaveTimer = Timer(const Duration(milliseconds: 300), _saveListState);
  }

  Future<void> _saveListState([double? scrollOffset]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_filterKey, _filter);
      final offset = scrollOffset ??
          (_listScrollController.hasClients
              ? _listScrollController.offset
              : null);
      if (offset != null) {
        await prefs.setDouble(_scrollKey, offset);
      }
    } catch (_) {
      // Keep browsing if preference storage is unavailable.
    }
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      _filter = widget.initialFilter.clamp(0, _filters.length - 1).toInt();
    }
  }

  List<ConversationSummary> _visible(List<ConversationSummary> all) {
    final active = all.where((c) => !c.archived);
    switch (_filter) {
      case 1:
        return active.where((c) => c.unread > 0).toList(growable: false);
      case 2:
        return active
            .where((c) => c.type == ConversationType.group)
            .toList(growable: false);
      case 3:
        return active
            .where((c) => c.type == ConversationType.channel)
            .toList(growable: false);
      case 4:
        return all.where((c) => c.archived).toList(growable: false);
      default:
        return active.toList(growable: false);
    }
  }

  Future<void> _showActions(ConversationSummary chat) async {
    final pal = EthioPalette.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                chat.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
              title: Text(chat.pinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: Icon(
                chat.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(chat.muted ? 'Unmute' : 'Mute'),
              onTap: () => Navigator.pop(sheetContext, 'mute'),
            ),
            ListTile(
              leading: Icon(
                chat.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(chat.archived ? 'Unarchive' : 'Archive'),
              onTap: () => Navigator.pop(sheetContext, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text(
                'Delete',
                style: TextStyle(color: EthioColors.danger),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            Divider(color: pal.line, height: 1),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final repo = ref.read(chatRepositoryProvider);
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete chat?'),
          content: Text(
            'This removes your conversation with ${chat.title}, including '
            'all messages on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: EthioColors.danger),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final result = await repo.deleteConversation(chat.id);
      _feedback(
          result.isSuccess ? 'Chat deleted' : result.failureOrNull!.message);
      return;
    }

    switch (action) {
      case 'pin':
        {
          final result = await repo.setPinned(chat.id, !chat.pinned);
          _feedback(result.isSuccess
              ? chat.pinned
                  ? 'Chat unpinned'
                  : 'Chat pinned'
              : result.failureOrNull!.message);
          break;
        }
      case 'mute':
        {
          final result = await repo.setMuted(chat.id, !chat.muted);
          _feedback(result.isSuccess
              ? chat.muted
                  ? 'Notifications unmuted'
                  : 'Notifications muted'
              : result.failureOrNull!.message);
          break;
        }
      case 'archive':
        {
          final result = await repo.setArchived(chat.id, !chat.archived);
          _feedback(result.isSuccess
              ? chat.archived
                  ? 'Chat unarchived'
                  : 'Chat archived'
              : result.failureOrNull!.message);
          break;
        }
    }
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final seed = ref.watch(demoSeedProvider);
    final summaries = ref.watch(conversationSummariesProvider);
    final all = summaries.valueOrNull ?? const <ConversationSummary>[];
    final chats = _visible(all);
    final loading =
        seed.isLoading && all.isEmpty || summaries.isLoading && all.isEmpty;
    if (!loading &&
        !_scrollPositionRestored &&
        _restoredScrollOffset != null) {
      _scrollPositionRestored = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_listScrollController.hasClients) return;
        final maxExtent = _listScrollController.position.maxScrollExtent;
        _listScrollController.jumpTo(
          _restoredScrollOffset!.clamp(0, maxExtent).toDouble(),
        );
      });
    }

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
                    backgroundColor: EthioPalette.of(context).chip,
                    selectedColor: EthioColors.gold,
                    side: BorderSide(
                      color: selected
                          ? Colors.transparent
                          : EthioPalette.of(context).line,
                    ),
                    labelStyle:
                        Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: selected ? EthioColors.black : null,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                    onSelected: (_) {
                      setState(() => _filter = i);
                      _scheduleStateSave();
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: loading
                  ? const ChatListSkeleton()
                  : summaries.hasError && all.isEmpty
                      ? Center(
                          child: Padding(
                            padding: Sp.screen,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Could not load chats.',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.invalidate(
                                      conversationSummariesProvider,
                                    );
                                    ref.invalidate(demoSeedProvider);
                                  },
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : chats.isEmpty
                          ? _EmptyChats(
                              message: _filter == 0
                                  ? 'No chats yet'
                                  : 'Nothing in ${_filters[_filter]}',
                              onNewChat: () => context.push('/new-chat'),
                            )
                          : RefreshIndicator(
                              color: EthioColors.gold,
                              onRefresh: () async {
                                await ref.read(demoSeedProvider.future);
                                ref.invalidate(conversationSummariesProvider);
                              },
                              child: ListView.builder(
                                controller: _listScrollController,
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
                                      padding:
                                          const EdgeInsets.only(right: Sp.x6),
                                      color: EthioColors.gold,
                                      child: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: EthioColors.black,
                                      ),
                                    ),
                                    child: ChatListTile(
                                      title: chat.title,
                                      preview: chat.preview,
                                      time: chatListTime(chat.lastMessageAt),
                                      avatarUrl: chat.conversation.avatarUrl,
                                      heroTag: 'chat-avatar-${chat.id}',
                                      unread: chat.unread,
                                      pinned: chat.pinned,
                                      muted: chat.muted,
                                      onTap: () =>
                                          context.push('/chats/${chat.id}'),
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
    );
  }
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
