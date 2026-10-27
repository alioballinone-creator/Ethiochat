import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/time_format.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../chats/domain/entities/conversation_entity.dart';
import '../../../chats/domain/entities/conversation_summary.dart';
import '../../../chats/domain/entities/message_entity.dart' as entity;
import '../../../contacts/domain/entities/contact_entity.dart';

/// 05 — Chat, backed by the local Drift database and outbox queue.
class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;
  entity.MessageEntity? _replyingTo;
  bool _atBottom = true;
  int _unseen = 0;
  Timer? _draftTimer;

  bool get _hasText => _composer.text.trim().isNotEmpty;
  String get _draftKey => 'chat.draft.${widget.chatId}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    Future<void>.microtask(_bootstrap);
    Future<void>.microtask(_restoreDraft);
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString(_draftKey);
      if (!mounted ||
          draft == null ||
          draft.isEmpty ||
          _composer.text.isNotEmpty) {
        return;
      }
      setState(() => _composer.text = draft);
    } catch (_) {
      // Drafts are best-effort when storage is unavailable.
    }
  }

  void _onComposerChanged() {
    setState(() {});
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _persistDraft);
  }

  Future<void> _persistDraft() async {
    final text = _composer.text.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (text.isEmpty) {
        await prefs.remove(_draftKey);
      } else {
        await prefs.setString(_draftKey, text);
      }
    } catch (_) {
      // Drafts are best-effort when storage is unavailable.
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {
      // Drafts are best-effort when storage is unavailable.
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom =
        _scroll.position.maxScrollExtent - _scroll.position.pixels < 80;
    if (atBottom != _atBottom) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _unseen = 0;
      });
    }
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
    _draftTimer?.cancel();
    _persistDraft();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (mounted) {
      setState(() {
        _atBottom = true;
        _unseen = 0;
      });
    }
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
    final replyTo = _replyingTo?.id;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    _composer.clear();
    _clearDraft();
    _scrollToBottom();
    final result = await ref.read(chatRepositoryProvider).sendMessage(
          conversationId: widget.chatId,
          type: entity.MessageType.text,
          body: text,
          replyTo: replyTo,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.failureOrNull case final failure?) _feedback(failure.message);
  }

  void _startReply(entity.MessageEntity message) {
    setState(() => _replyingTo = message);
    _composerFocus.requestFocus();
  }

  Future<void> _startCall({required bool video}) async {
    final route = '/call/${widget.chatId}${video ? '?video=true' : ''}';
    final outcome = await context.push<String>(route);
    if (!mounted || outcome == null || outcome.isEmpty) return;
    final result = await ref.read(chatRepositoryProvider).sendMessage(
          conversationId: widget.chatId,
          type: entity.MessageType.system,
          body: outcome,
        );
    if (!mounted) return;
    if (result.failureOrNull case final failure?) _feedback(failure.message);
  }

  String _messagePreview(entity.MessageEntity message) {
    final body = message.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    return switch (message.type) {
      entity.MessageType.image => 'Photo',
      entity.MessageType.voice => 'Voice message',
      entity.MessageType.file => 'Document',
      entity.MessageType.location => 'Location',
      entity.MessageType.contact => 'Contact',
      entity.MessageType.payment => 'Payment',
      entity.MessageType.redpacket => 'Red packet',
      _ => 'Message',
    };
  }

  Future<void> _sendAttachment(
    entity.MessageType type, {
    String? body,
    Map<String, dynamic>? media,
  }) async {
    if (_sending) return;
    final replyTo = _replyingTo?.id;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    final result = await ref.read(chatRepositoryProvider).sendMessage(
          conversationId: widget.chatId,
          type: type,
          body: body,
          media: media,
          replyTo: replyTo,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.failureOrNull case final failure?) {
      _feedback(failure.message);
    } else {
      _scrollToBottom();
    }
  }

  Future<void> _pickDocument() async {
    try {
      final picked = await FilePicker.platform.pickFiles();
      final file = picked?.files.single;
      if (file?.path == null || !mounted) return;
      await _sendAttachment(
        entity.MessageType.file,
        body: file!.name,
        media: {
          'path': file.path,
          'name': file.name,
          'size': file.size,
        },
      );
    } catch (error) {
      if (mounted) _feedback('Could not open the file picker: $error');
    }
  }

  Future<void> _shareLocation() async {
    final controller = TextEditingController(text: 'Bole, Addis Ababa');
    final place = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share a place'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Area, landmark or address',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (place == null || place.isEmpty || !mounted) return;
    final query = Uri.encodeComponent(place);
    await _sendAttachment(
      entity.MessageType.location,
      body: place,
      media: {
        'label': place,
        'url': 'https://maps.google.com/?q=$query',
      },
    );
  }

  Future<void> _shareContact() async {
    final contacts =
        ref.read(contactsProvider).valueOrNull ?? const <ContactEntity>[];
    if (contacts.isEmpty) {
      _feedback('Add a contact first, then share their card.');
      return;
    }
    final contact = await showModalBottomSheet<ContactEntity>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(
                'Share a contact',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final item = contacts[index];
                  return ListTile(
                    leading: EthioAvatar(name: item.displayName, size: 40),
                    title: Text(item.displayName),
                    subtitle: Text(item.phoneE164 ?? item.ethioId ?? ''),
                    onTap: () => Navigator.pop(sheetContext, item),
                  );
                },
              ),
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (contact == null || !mounted) return;
    await _sendAttachment(
      entity.MessageType.contact,
      body: contact.displayName,
      media: {
        'name': contact.displayName,
        'phone': contact.phoneE164,
        'ethio_id': contact.ethioId,
      },
    );
  }

  Future<void> _recordVoice() async {
    final recording = await showModalBottomSheet<_Recording>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => const _VoiceRecorderSheet(),
    );
    if (recording == null || !mounted) return;
    await _sendAttachment(
      entity.MessageType.voice,
      media: {
        'path': recording.path,
        'duration': recording.duration,
        'seconds': recording.seconds,
      },
    );
  }

  Future<void> _messageActions(
    entity.MessageEntity message,
    List<entity.MessageEntity> messages,
  ) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(sheetContext, 'forward'),
            ),
            if (message.senderId == 'me' &&
                message.type == entity.MessageType.text &&
                !message.deletedEveryone &&
                DateTime.now().difference(message.createdAt) <=
                    const Duration(minutes: 15))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (message.status == entity.MessageStatus.failed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Retry'),
                onTap: () => Navigator.pop(sheetContext, 'retry'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: EthioColors.danger,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: EthioColors.danger),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    switch (action) {
      case 'reply':
        _startReply(message);
        break;
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: _messagePreview(message)),
        );
        _feedback('Message copied.');
        break;
      case 'forward':
        await _forward(message);
        break;
      case 'edit':
        await _editMessage(message);
        break;
      case 'retry':
        final result = await repo.retryFailed(message.id);
        if (result.failureOrNull case final failure?) {
          _feedback(failure.message);
        }
        break;
      case 'delete':
        await _deleteMessage(message);
        break;
    }
  }

  Future<void> _editMessage(entity.MessageEntity message) async {
    final controller = TextEditingController(text: message.body ?? '');
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          maxLength: 4096,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || !mounted) return;
    final result =
        await ref.read(chatRepositoryProvider).editMessage(message.id, body);
    if (result.failureOrNull case final failure?) {
      _feedback(failure.message);
    }
  }

  Future<void> _deleteMessage(entity.MessageEntity message) async {
    final canDeleteForEveryone = message.senderId == 'me' &&
        DateTime.now().difference(message.createdAt) <=
            const Duration(hours: 24);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: EthioColors.danger,
              ),
              title: const Text('Delete for me'),
              onTap: () => Navigator.pop(sheetContext, 'me'),
            ),
            if (canDeleteForEveryone)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: EthioColors.danger,
                ),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.pop(sheetContext, 'everyone'),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    final result = choice == 'everyone'
        ? await repo.deleteMessageForEveryone(message.id)
        : await repo.deleteMessage(message.id);
    if (result.failureOrNull case final failure?) {
      _feedback(failure.message);
    }
  }

  Future<void> _forward(entity.MessageEntity message) async {
    final summaries = ref.read(conversationSummariesProvider).valueOrNull ??
        const <ConversationSummary>[];
    final available = summaries
        .where((item) => item.conversation.id != widget.chatId)
        .toList(growable: false);
    if (available.isEmpty) {
      _feedback('No other chats to forward to.');
      return;
    }
    final target = await showModalBottomSheet<ConversationSummary>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(
                'Forward to',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final item = available[index];
                  return ListTile(
                    leading: EthioAvatar(
                      name: item.conversation.title ?? 'Chat',
                      size: 40,
                    ),
                    title: Text(item.conversation.title ?? 'Chat'),
                    subtitle: Text(
                      item.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(sheetContext, item),
                  );
                },
              ),
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    final result = await ref.read(chatRepositoryProvider).forwardMessage(
          message.id,
          target.conversation.id,
        );
    if (!mounted) return;
    _feedback(
      result.isSuccess
          ? 'Forwarded to ${target.conversation.title ?? 'chat'}.'
          : result.failureOrNull?.message ?? 'Could not forward message.',
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (picked == null || !mounted) return;
      await _sendAttachment(
        entity.MessageType.image,
        media: {'path': picked.path, 'name': picked.name},
      );
    } catch (error) {
      if (mounted) _feedback('Could not pick an image: $error');
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
        await _pickDocument();
        break;
      case 'location':
        await _shareLocation();
        break;
      case 'contact':
        await _shareContact();
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
        if (after > before) {
          if (_atBottom || before == 0) {
            _scrollToBottom(animate: before > 0);
          } else {
            setState(() => _unseen += after - before);
          }
        }
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
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
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
            onPressed: () => _startCall(video: true),
          ),
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => _startCall(video: false),
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
                  : Stack(
                      children: [
                        ListView(
                          controller: _scroll,
                          padding: Sp.screen.copyWith(
                            top: Sp.x2,
                            bottom: Sp.x4,
                          ),
                          children: _buildMessages(context, items),
                        ),
                        if (!_atBottom)
                          Positioned(
                            right: Sp.x4,
                            bottom: Sp.x3,
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              elevation: 3,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _scrollToBottom(),
                                child: Padding(
                                  padding: const EdgeInsets.all(Sp.x3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                      ),
                                      if (_unseen > 0) ...[
                                        const SizedBox(width: Sp.x1),
                                        Text(
                                          '$_unseen',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          _Composer(
            controller: _composer,
            canSend: _hasText,
            sending: _sending,
            onChanged: _onComposerChanged,
            onSend: _sendText,
            onAttach: _showAttachments,
            onEmoji: _showEmojiPicker,
            onCamera: () => _pickImage(ImageSource.camera),
            onVoice: _recordVoice,
            focusNode: _composerFocus,
            replyPreview:
                _replyingTo == null ? null : _messagePreview(_replyingTo!),
            onCancelReply: () => setState(() => _replyingTo = null),
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
      final deleted = message.deletedEveryone;
      final bubble = MessageBubble(
        isMine: mine,
        time: bubbleTime(message.createdAt),
        status: _status(message.status),
        text: deleted
            ? 'This message was deleted'
            : message.type == entity.MessageType.text
                ? (message.body ?? '')
                : null,
        child: deleted ? null : _messageChild(message),
        edited: !deleted && message.editedAt != null,
        header: _replyHeader(message, messages),
        onLongPress: () => _messageActions(message, messages),
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
      );
      widgets.add(
        Dismissible(
          key: ValueKey('reply-${message.id}'),
          direction: DismissDirection.startToEnd,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: Sp.x5),
            child: const Icon(
              Icons.reply_rounded,
              color: EthioColors.goldDeep,
            ),
          ),
          confirmDismiss: (_) async {
            _startReply(message);
            return false;
          },
          child: bubble,
        ),
      );
    }
    return widgets;
  }

  Widget? _replyHeader(
    entity.MessageEntity message,
    List<entity.MessageEntity> messages,
  ) {
    final replyId = message.replyTo;
    if (replyId == null) return null;
    entity.MessageEntity? target;
    for (final item in messages) {
      if (item.id == replyId) {
        target = item;
        break;
      }
    }
    final pal = EthioPalette.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.fromLTRB(Sp.x2, Sp.x1, Sp.x2, Sp.x1),
      decoration: BoxDecoration(
        color: pal.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: EthioColors.goldDeep, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            target == null
                ? 'Original message'
                : (target.senderId == 'me' ? 'You' : 'Reply'),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: EthioColors.goldDeep),
          ),
          Text(
            target == null ? 'Message unavailable' : _messagePreview(target),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
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
          path: message.media?['path'] as String?,
          onMissing: () => _feedback('Voice note audio is unavailable.'),
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
        return _LocationCard(
          label: message.media?['label'] as String? ??
              message.body ??
              'Shared location',
          url: message.media?['url'] as String?,
        );
      case entity.MessageType.file:
        return _DocumentCard(
          name: message.media?['name'] as String? ?? message.body ?? 'Document',
          path: message.media?['path'] as String?,
          size: message.media?['size'] as int?,
        );
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
        return _ContactCard(
          name: message.media?['name'] as String? ?? message.body ?? 'Contact',
          phone: message.media?['phone'] as String?,
          ethioId: message.media?['ethio_id'] as String?,
          onOpen: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                message.media?['name'] as String? ?? message.body ?? 'Contact',
              ),
              content: Text(
                [
                  message.media?['phone'] as String?,
                  message.media?['ethio_id'] as String?,
                ].whereType<String>().join('\n'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
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
    required this.focusNode,
    this.replyPreview,
    this.onCancelReply,
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
  final FocusNode focusNode;
  final String? replyPreview;
  final VoidCallback? onCancelReply;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyPreview != null)
              Container(
                margin: const EdgeInsets.fromLTRB(Sp.x3, Sp.x2, Sp.x3, 0),
                padding: const EdgeInsets.fromLTRB(Sp.x3, Sp.x1, Sp.x1, Sp.x1),
                decoration: BoxDecoration(
                  color: pal.chip,
                  borderRadius: Rad.r10,
                  border: Border(
                    left: BorderSide(
                      color: EthioColors.goldDeep,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: EthioColors.goldDeep),
                          ),
                          Text(
                            replyPreview!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onCancelReply,
                    ),
                  ],
                ),
              ),
            Padding(
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
                              focusNode: focusNode,
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
          ],
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

class _VoiceNote extends StatefulWidget {
  const _VoiceNote({
    required this.duration,
    required this.path,
    required this.onMissing,
  });

  final String duration;
  final String? path;
  final VoidCallback onMissing;

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  AudioPlayer? _player;
  var _playing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final path = widget.path;
    if (path == null || !File(path).existsSync()) {
      widget.onMissing();
      return;
    }
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      final player = _player ??= AudioPlayer();
      if (_player == player) {
        player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
      }
      await player.play(DeviceFileSource(path));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      widget.onMissing();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return InkWell(
      onTap: _toggle,
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
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                        color: _playing
                            ? EthioColors.goldDeep
                            : pal.textSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Sp.x2),
          Text(
            widget.duration,
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.name,
    required this.path,
    required this.size,
  });

  final String name;
  final String? path;
  final int? size;

  String get _sizeLabel {
    final bytes = size ?? 0;
    if (bytes <= 0) return 'Document';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _open(BuildContext context) async {
    final file = path;
    if (file == null || !File(file).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This document is not on this device.')),
      );
      return;
    }
    final result = await OpenFilex.open(file);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.all(Sp.x3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: Rad.r10,
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 28),
            const SizedBox(width: Sp.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    _sizeLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.name,
    required this.phone,
    required this.ethioId,
    required this.onOpen,
  });

  final String name;
  final String? phone;
  final String? ethioId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.all(Sp.x3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: Rad.r10,
        ),
        child: Row(
          children: [
            EthioAvatar(name: name, size: 38),
            const SizedBox(width: Sp.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (phone != null)
                    Text(
                      phone!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            const Icon(Icons.person_add_alt_1_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.label, required this.url});

  final String label;
  final String? url;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(
          text: url ??
              'https://maps.google.com/?q=${Uri.encodeComponent(label)}'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map link copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.all(Sp.x3),
        decoration: BoxDecoration(
          color: EthioColors.success.withValues(alpha: 0.12),
          borderRadius: Rad.r10,
          border: Border.all(
            color: EthioColors.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_rounded, color: EthioColors.success),
            const SizedBox(width: Sp.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    'Tap to copy map link',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recording {
  const _Recording({required this.path, required this.seconds});

  final String path;
  final int seconds;

  String get duration {
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}

class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet();

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final _recorder = AudioRecorder();
  Timer? _timer;
  DateTime? _startedAt;
  String? _path;
  String? _error;
  var _starting = true;
  var _stopping = false;
  var _seconds = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      var granted = await _recorder.hasPermission();
      if (!granted) {
        final status = await Permission.microphone.request();
        granted = status.isGranted;
      }
      if (!granted) {
        if (mounted) {
          setState(() {
            _starting = false;
            _error =
                'Microphone permission is required to record a voice note.';
          });
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _path = path;
        _starting = false;
        _startedAt = DateTime.now();
      });
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _startedAt == null) return;
        final seconds = DateTime.now().difference(_startedAt!).inSeconds;
        if (seconds != _seconds) setState(() => _seconds = seconds);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'Could not start recording: $error';
      });
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (!_stopping) {
      _stopping = true;
      try {
        await _recorder.stop();
      } catch (_) {
        // The recorder may already be stopped.
      }
      final path = _path;
      if (path != null) {
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } catch (_) {
          // A leftover temporary file is harmless.
        }
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _stopAndSend() async {
    if (_seconds < 1) {
      setState(() => _error = 'Record for at least one second.');
      return;
    }
    setState(() => _stopping = true);
    _timer?.cancel();
    try {
      final path = await _recorder.stop() ?? _path;
      if (path == null || !mounted) return;
      Navigator.pop(
        context,
        _Recording(path: path, seconds: _seconds),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stopping = false;
        _error = 'Could not finish the recording: $error';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final minutes = _seconds ~/ 60;
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pal = EthioPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.x6,
        Sp.x2,
        Sp.x6,
        Sp.x6 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Voice message', style: text.titleLarge),
          const SizedBox(height: Sp.x5),
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              gradient: EthioColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _starting ? Icons.hourglass_top_rounded : Icons.mic_rounded,
              size: 38,
              color: EthioColors.black,
            ),
          ),
          const SizedBox(height: Sp.x3),
          Text(
            _starting ? 'Starting microphone…' : _timerLabel,
            style: text.headlineMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: Sp.x2),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: EthioColors.danger),
            ),
          ],
          const SizedBox(height: Sp.x4),
          Row(
            children: [
              Expanded(
                child: EthioButton(
                  label: 'Cancel',
                  kind: EthioButtonKind.secondary,
                  onPressed: _cancel,
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: EthioButton(
                  label: _stopping ? 'Sending…' : 'Send',
                  icon: Icons.send_rounded,
                  onPressed: _starting || _stopping || _error != null
                      ? null
                      : _stopAndSend,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x2),
          Text(
            'Audio is stored on this device and sent with end-to-end encryption.',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: pal.textTertiary),
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
