import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../chats/domain/entities/conversation_entity.dart';
import '../../../chats/domain/entities/message_entity.dart' as entity;
import '../../../contacts/domain/entities/contact_entity.dart';

/// Chat info / conversation settings, persisted to the local database.
class ChatInfoScreen extends ConsumerStatefulWidget {
  const ChatInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  bool _busy = false;

  Future<void> _setMuted(bool muted) async {
    final result =
        await ref.read(chatRepositoryProvider).setMuted(widget.chatId, muted);
    if (result.failureOrNull case final failure?) _feedback(failure.message);
  }

  Future<void> _setPinned(bool pinned) async {
    final result =
        await ref.read(chatRepositoryProvider).setPinned(widget.chatId, pinned);
    if (result.failureOrNull case final failure?) _feedback(failure.message);
  }

  Future<void> _clearChat() async {
    final confirmed = await _confirm(
      title: 'Clear chat?',
      message: 'All messages in this conversation will be removed from this '
          'device. This cannot be undone.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    final result =
        await ref.read(chatRepositoryProvider).clearMessages(widget.chatId);
    _feedback(
        result.isSuccess ? 'Chat cleared' : result.failureOrNull!.message);
  }

  Future<void> _deleteChat() async {
    final confirmed = await _confirm(
      title: 'Delete chat?',
      message: 'This conversation and its messages will be removed from this '
          'device.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    final result = await ref
        .read(chatRepositoryProvider)
        .deleteConversation(widget.chatId);
    if (!mounted) return;
    if (result.isSuccess) {
      context.go('/chats');
    } else {
      _feedback(result.failureOrNull!.message);
    }
  }

  Future<void> _blockContact(String name) async {
    final confirmed = await _confirm(
      title: 'Block $name?',
      message: 'Blocked contacts can no longer call you or send new messages.',
      confirmLabel: 'Block',
    );
    if (!confirmed) return;
    final result =
        await ref.read(chatRepositoryProvider).setContactBlocked(name, true);
    if (!mounted) return;
    if (!result.isSuccess) {
      _feedback(result.failureOrNull?.message ?? 'Could not block contact');
      return;
    }
    _feedback('$name blocked. You can unblock them in Settings.');
  }

  Future<void> _report(String name) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reason in [
              'Spam or scam',
              'Harassment',
              'Inappropriate content',
              'Other',
            ])
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(sheetContext, reason),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final result = await ref.read(chatRepositoryProvider).saveReport(
          targetId: widget.chatId,
          targetName: name,
          reason: reason,
        );
    if (!mounted) return;
    _feedback(
      result.isSuccess
          ? 'Reported $name for "$reason". Thank you.'
          : result.failureOrNull?.message ?? 'Could not send report.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: EthioColors.danger),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final conversation = ref.watch(conversationProvider(widget.chatId));
    final messages = ref.watch(messagesProvider(widget.chatId)).valueOrNull ??
        const <entity.MessageEntity>[];
    final contacts =
        ref.watch(contactsProvider).valueOrNull ?? const <ContactEntity>[];
    final info = conversation.valueOrNull;
    final title = info?.title ?? 'Chat';
    final isGroup = info?.type == ConversationType.group;
    final images = messages
        .where((m) =>
            m.type == entity.MessageType.image &&
            (m.media?['path'] as String?) != null)
        .toList(growable: false);
    final documents =
        messages.where((m) => m.type == entity.MessageType.file).length;
    final links = messages.where((m) => (m.body ?? '').contains('http')).length;
    ContactEntity? contact;
    for (final c in contacts) {
      if (c.displayName == title) {
        contact = c;
        break;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Chat info', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: _busy
                ? null
                : () async {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      builder: (sheetContext) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading:
                                  const Icon(Icons.cleaning_services_outlined),
                              title: const Text('Clear chat'),
                              onTap: () => Navigator.pop(sheetContext, 'clear'),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.delete_outline_rounded,
                                color: EthioColors.danger,
                              ),
                              title: const Text(
                                'Delete chat',
                                style: TextStyle(color: EthioColors.danger),
                              ),
                              onTap: () =>
                                  Navigator.pop(sheetContext, 'delete'),
                            ),
                            const SizedBox(height: Sp.x2),
                          ],
                        ),
                      ),
                    );
                    setState(() => _busy = true);
                    if (action == 'clear') await _clearChat();
                    if (action == 'delete') await _deleteChat();
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            Center(
              child: Column(
                children: [
                  EthioAvatar(
                    name: title,
                    imageUrl: info?.avatarUrl,
                    size: 88,
                  ),
                  const SizedBox(height: Sp.x3),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    isGroup
                        ? '${messages.map((m) => m.senderId).toSet().length} '
                            'participants'
                        : contact?.phoneE164 ??
                            (contact?.ethioId == null
                                ? 'EthioChat contact'
                                : 'Ethio ID: ${contact?.ethioId}'),
                    style: text.bodyMedium?.copyWith(color: pal.textSecondary),
                  ),
                  const SizedBox(height: Sp.x3),
                  Wrap(
                    spacing: Sp.x2,
                    runSpacing: Sp.x2,
                    alignment: WrapAlignment.center,
                    children: [
                      _QuickPill(
                        icon: Icons.call_outlined,
                        label: 'Call',
                        onTap: () => context.push('/call/${widget.chatId}'),
                      ),
                      _QuickPill(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        onTap: () =>
                            context.push('/call/${widget.chatId}?video=true'),
                      ),
                      _QuickPill(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        onTap: () => context.push('/search'),
                      ),
                      if (isGroup)
                        _QuickPill(
                          icon: Icons.manage_accounts_outlined,
                          label: 'Group info',
                          onTap: () => context.push(
                            '/chats/${widget.chatId}/group',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            _Card(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_off_outlined,
                  title: 'Mute notifications',
                  value: info?.mutedUntil != null,
                  onChanged: _setMuted,
                ),
                _SwitchRow(
                  icon: Icons.push_pin_outlined,
                  title: 'Pin chat',
                  value: info?.pinned ?? false,
                  onChanged: _setPinned,
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            Row(
              children: [
                Text('Media', style: text.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => _showMedia(images),
                  child: const Text('See all'),
                ),
              ],
            ),
            if (images.isEmpty)
              Container(
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: Rad.r14,
                  border: Border.all(color: pal.line),
                ),
                child: Text(
                  'No media yet',
                  style: text.bodyMedium?.copyWith(color: pal.textSecondary),
                ),
              )
            else
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Sp.x2),
                  itemBuilder: (context, i) {
                    final image = images[i];
                    return GestureDetector(
                      onTap: () => _showMedia(images, initial: i),
                      child: _MediaThumb(
                        path: image.media!['path'] as String,
                        index: i,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: Sp.x4),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos and videos',
                  trailing: '${images.length}',
                  onTap: () => _showMedia(images),
                ),
                _NavRow(
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Documents',
                  trailing: '$documents',
                  onTap: () => _feedback(
                    documents == 0
                        ? 'No documents in this chat yet.'
                        : '$documents document(s) shared.',
                  ),
                ),
                _NavRow(
                  icon: Icons.link_rounded,
                  title: 'Links',
                  trailing: '$links',
                  onTap: () => _feedback(
                    links == 0
                        ? 'No links in this chat yet.'
                        : '$links link(s) shared.',
                  ),
                ),
                _NavRow(
                  icon: Icons.auto_delete_outlined,
                  title: 'Disappearing messages',
                  trailing: 'Off',
                  onTap: () => _feedback(
                    'Disappearing messages are not available in this release.',
                  ),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.block_outlined,
                  title: isGroup ? 'Block group' : 'Block contact',
                  danger: true,
                  onTap: () => _blockContact(title),
                ),
                _NavRow(
                  icon: Icons.flag_outlined,
                  title: 'Report',
                  danger: true,
                  onTap: () => _report(title),
                  last: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMedia(
    List<entity.MessageEntity> images, {
    int initial = 0,
  }) async {
    if (images.isEmpty) {
      _feedback('No photos or videos in this chat.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 320,
          height: 420,
          child: PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: images.length,
            itemBuilder: (context, i) {
              final path = images[i].media!['path'] as String;
              if (!File(path).existsSync()) {
                return const Center(child: Text('Media unavailable'));
              }
              return InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.path, required this.index});

  final String path;
  final int index;

  @override
  Widget build(BuildContext context) {
    final exists = File(path).existsSync();
    return ClipRRect(
      borderRadius: Rad.r14,
      child: exists
          ? Image.file(File(path), width: 84, height: 84, fit: BoxFit.cover)
          : Container(
              width: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EthioColors
                        .avatarTones[index % EthioColors.avatarTones.length],
                    EthioColors.avatarTones[
                        (index + 3) % EthioColors.avatarTones.length],
                  ],
                ),
              ),
            ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: Rad.r14,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rad.r14,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: Rad.r14,
            border: Border.all(color: pal.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: Sp.x2),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r18,
        border: Border.all(color: pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: danger ? EthioColors.danger.withValues(alpha: 0.12) : pal.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 22,
        color: danger ? EthioColors.danger : null,
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x1,
          ),
          leading: _IconTile(icon: icon, danger: danger),
          title: Text(
            title,
            style: text.titleMedium?.copyWith(
              color: danger ? EthioColors.danger : null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(
                  trailing!,
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
              const SizedBox(width: Sp.x1),
              Icon(Icons.chevron_right_rounded, color: pal.textTertiary),
            ],
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            indent: Sp.x4 + 44 + Sp.x3,
            endIndent: Sp.x4,
            color: pal.line,
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x1,
          ),
          secondary: _IconTile(icon: icon),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          activeTrackColor: EthioColors.gold,
        ),
        if (!last)
          Divider(
            height: 1,
            indent: Sp.x4 + 44 + Sp.x3,
            endIndent: Sp.x4,
            color: pal.line,
          ),
      ],
    );
  }
}
