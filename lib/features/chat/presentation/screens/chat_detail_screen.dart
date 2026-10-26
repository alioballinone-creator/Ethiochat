import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/time_format.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../chats/domain/entities/conversation_entity.dart';
import '../../../chats/domain/entities/message_entity.dart' as entity;

/// 05 — Chat, backed by the local Drift database and outbox queue.
class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  bool get _hasText => _composer.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(demoSeedProvider.future);
    if (!mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    await repo.ensureConversation(widget.chatId);
    if (!mounted) return;
    await repo.markRead(widget.chatId, 0);
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(target, duration: Dur.normal, curve: Dur.curve);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _composer.clear();
    _scrollToBottom();
    final result = await ref.read(chatRepositoryProvider).sendMessage(
          conversationId: widget.chatId,
          type: entity.MessageType.text,
          body: text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.failureOrNull case final failure?) _feedback(failure.message);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() => _sending = true);
      final result = await ref.read(chatRepositoryProvider).sendMessage(
        conversationId: widget.chatId,
        type: entity.MessageType.image,
        media: {'path': picked.path, 'name': picked.name},
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (result.failureOrNull case final failure?) {
        _feedback(failure.message);
      } else {
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        _feedback('Could not pick an image: $error');
      }
    }
  }

  Future<void> _showAttachments() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x4),
          child: Wrap(
            spacing: Sp.x6,
            runSpacing: Sp.x4,
            children: [
              _AttachOption(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              _AttachOption(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_outlined,
                label: 'Document',
                onTap: () => Navigator.pop(sheetContext, 'document'),
              ),
              _AttachOption(
                icon: Icons.place_outlined,
                label: 'Location',
                onTap: () => Navigator.pop(sheetContext, 'location'),
              ),
              _AttachOption(
                icon: Icons.person_outline_rounded,
                label: 'Contact',
                onTap: () => Navigator.pop(sheetContext, 'contact'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'gallery':
        await _pickImage(ImageSource.gallery);
        break;
      case 'camera':
        await _pickImage(ImageSource.camera);
        break;
      case 'document':
        _feedback('Document sharing arrives with the file picker update.');
        break;
      case 'location':
        _feedback('Location sharing needs a GPS fix — try again outdoors.');
        break;
      case 'contact':
        _feedback('Contact cards will be shareable in the next release.');
        break;
    }
  }

  Future<void> _showEmojiPicker() async {
    const emojis = [
      '😀',
      '😂',
      '🥰',
      '😍',
      '😎',
      '🤝',
      '🙏',
      '👍',
      '👏',
      '💪',
      '❤️',
      '🔥',
      '🎉',
      '☕️',
      '🍲',
      '🇪🇹',
      '✅',
      '🙌',
      '😅',
      '🤔',
    ];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Wrap(
            spacing: Sp.x2,
            runSpacing: Sp.x2,
            children: [
              for (final e in emojis)
                InkWell(
                  onTap: () => Navigator.pop(sheetContext, e),
                  borderRadius: Rad.r10,
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.x2),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null) return;
    _composer.text = _composer.text + emoji;
    _composer.selection =
        TextSelection.collapsed(offset: _composer.text.length);
    setState(() {});
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
    final conversation = ref.watch(conversationProvider(widget.chatId));
    final messages = ref.watch(messagesProvider(widget.chatId));
    final info = conversation.valueOrNull;
    final title = info?.title ?? 'Chat';
    final isGroup = info?.type == ConversationType.group;
    final showOnlineHint = MediaQuery.textScalerOf(context).scale(1) <= 1.3;

    ref.listen(
      messagesProvider(widget.chatId),
      (previous, next) {
        final before = previous?.valueOrNull?.length ?? 0;
        final after = next.valueOrNull?.length ?? 0;
        if (after > before) _scrollToBottom(animate: before > 0);
        if (after > 0) {
          ref.read(chatRepositoryProvider).markRead(widget.chatId, 0);
        }
      },
    );

    return Scaffold(
      backgroundColor: pal.wallpaper,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () => context.push('/chats/${widget.chatId}/info'),
          borderRadius: Rad.r14,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x1),
            child: Row(
              children: [
                EthioAvatar(
                  name: title,
                  imageUrl: info?.avatarUrl,
                  size: 40,
                  online: !isGroup,
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showOnlineHint)
                        Text(
                          isGroup ? 'tap for group info' : 'online',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isGroup
                                    ? pal.textSecondary
                                    : EthioColors.success,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => context.push('/call/${widget.chatId}?video=true'),
          ),
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push('/call/${widget.chatId}'),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: Sp.screen,
                  child: Text('Could not load messages: $error'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: Sp.screen,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.waving_hand_outlined,
                              size: 40,
                              color: pal.textSecondary,
                            ),
                            const SizedBox(height: Sp.x3),
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: Sp.x1),
                            Text(
                              'Say hello to $title 👋',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: Sp.screen.copyWith(
                        top: Sp.x2,
                        bottom: Sp.x4,
                      ),
                      children: _buildMessages(context, items),
                    ),
            ),
          ),
          _Composer(
            controller: _composer,
            canSend: _hasText,
            sending: _sending,
            onChanged: () => setState(() {}),
            onSend: _sendText,
            onAttach: _showAttachments,
            onEmoji: _showEmojiPicker,
            onCamera: () => _pickImage(ImageSource.camera),
            onVoice: () => _feedback(
              'Hold the mic on a device to record — microphone access is '
              'requested there.',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMessages(
    BuildContext context,
    List<entity.MessageEntity> messages,
  ) {
    final widgets = <Widget>[];
    String? lastDay;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final label = dayLabel(message.createdAt);
      if (label != lastDay) {
        widgets.add(_DayDivider(label: label));
        lastDay = label;
      }
      if (message.type == entity.MessageType.system) {
        widgets.add(_SystemNote(text: message.body ?? 'System message'));
        continue;
      }
      final mine = message.senderId == 'me';
      widgets.add(
        MessageBubble(
          isMine: mine,
          time: bubbleTime(message.createdAt),
          status: _status(message.status),
          text: message.type == entity.MessageType.text
              ? (message.body ?? '')
              : null,
          child: _messageChild(message),
          onRetry: message.status == entity.MessageStatus.failed
              ? () async {
                  final result = await ref
                      .read(chatRepositoryProvider)
                      .retryFailed(message.id);
                  if (result.failureOrNull case final failure?) {
                    _feedback(failure.message);
                  }
                }
              : null,
        ),
      );
    }
    return widgets;
  }

  Widget? _messageChild(entity.MessageEntity message) {
    switch (message.type) {
      case entity.MessageType.image:
        final path = message.media?['path'] as String?;
        if (path != null && File(path).existsSync()) {
          return ClipRRect(
            borderRadius: Rad.r10,
            child: Image.file(
              File(path),
              width: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _mediaPlaceholder(
                Icons.broken_image_outlined,
                'Photo unavailable',
              ),
            ),
          );
        }
        return _mediaPlaceholder(Icons.image_outlined, 'Photo');
      case entity.MessageType.voice:
        return _VoiceNote(
          duration: message.media?['duration'] as String? ?? '0:12',
          onTap: () => _feedback('Playing voice message…'),
        );
      case entity.MessageType.payment:
        final amount = message.media?['amount'] as String? ?? 'ETB 0.00';
        final note = message.body ?? 'Payment';
        return _PaymentCard(
          amount: amount,
          note: note,
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Payment receipt'),
              content: Text('$note\n$amount\n\nStatus: completed'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      case entity.MessageType.location:
        return _mediaPlaceholder(Icons.place_outlined, 'Shared location');
      case entity.MessageType.file:
        return _mediaPlaceholder(Icons.description_outlined, 'Document');
      case entity.MessageType.video:
        return _mediaPlaceholder(Icons.play_circle_outline_rounded, 'Video');
      case entity.MessageType.sticker:
        return Text(
          message.body ?? '🐐',
          style: const TextStyle(fontSize: 44),
        );
      case entity.MessageType.redpacket:
        return _mediaPlaceholder(
          Icons.card_giftcard_outlined,
          'Red packet',
        );
      case entity.MessageType.contact:
        return _mediaPlaceholder(Icons.person_outline_rounded, 'Contact');
      case entity.MessageType.text:
      case entity.MessageType.system:
        return null;
    }
  }

  Widget _mediaPlaceholder(IconData icon, String label) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.x3,
        vertical: Sp.x2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: Rad.r10,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: Sp.x2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  MessageStatus _status(entity.MessageStatus status) {
    return switch (status) {
      entity.MessageStatus.pending => MessageStatus.sending,
      entity.MessageStatus.sent => MessageStatus.sent,
      entity.MessageStatus.delivered => MessageStatus.delivered,
      entity.MessageStatus.read => MessageStatus.read,
      entity.MessageStatus.failed => MessageStatus.failed,
    };
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.onEmoji,
    required this.onCamera,
    required this.onVoice,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool sending;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onEmoji;
  final VoidCallback onCamera;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x2, Sp.x2, Sp.x2, Sp.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: onAttach,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4,
                    vertical: Sp.x1,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: pal.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => onChanged(),
                          onSubmitted: (_) => onSend(),
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: Sp.x2,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Emoji',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 20,
                        ),
                        onPressed: onEmoji,
                      ),
                      IconButton(
                        tooltip: 'Camera',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.photo_camera_outlined,
                          size: 20,
                        ),
                        onPressed: onCamera,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Sp.x1),
              IconButton(
                tooltip: canSend ? 'Send' : 'Record voice note',
                icon: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    gradient: EthioColors.goldGradient,
                    shape: BoxShape.circle,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EthioColors.black,
                          ),
                        )
                      : Icon(
                          canSend ? Icons.send_rounded : Icons.mic_rounded,
                          color: EthioColors.black,
                          size: 20,
                        ),
                ),
                onPressed: sending ? null : (canSend ? onSend : onVoice),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
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

    return InkWell(
      onTap: onTap,
      borderRadius: Rad.r14,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r14,
              ),
              child: Icon(icon, size: 24),
            ),
            const SizedBox(height: Sp.x1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Sp.x2),
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.x3,
          vertical: Sp.x1,
        ),
        decoration: BoxDecoration(
          color: EthioPalette.of(context).chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x3,
            vertical: Sp.x1,
          ),
          decoration: BoxDecoration(
            color: pal.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: pal.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _VoiceNote extends StatelessWidget {
  const _VoiceNote({required this.duration, required this.onTap});

  final String duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: EthioColors.gold.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: EthioColors.goldDeep,
            ),
          ),
          const SizedBox(width: Sp.x2),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                for (var i = 0; i < 20; i++)
                  Expanded(
                    child: Container(
                      height: 8.0 + (i * 3 % 14),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: pal.textSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Sp.x2),
          Text(
            duration,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: pal.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.amount,
    required this.note,
    required this.onTap,
  });

  final String amount;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Sp.x3),
        decoration: BoxDecoration(
          color: EthioColors.gold.withValues(alpha: 0.16),
          borderRadius: Rad.r10,
          border: Border.all(color: EthioColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: EthioColors.goldDeep,
                ),
                const SizedBox(width: Sp.x2),
                Flexible(
                  child: Text(
                    note,
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x1),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: EthioColors.goldDeep,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Tap to view receipt',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
