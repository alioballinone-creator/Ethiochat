import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// 05 — Chat.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool get _hasText => _composer.text.trim().isNotEmpty;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (!_hasText) return;
    setState(() => _composer.clear());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: Dur.normal,
          curve: Dur.curve,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

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
                const EthioAvatar(name: 'Abebe', size: 40, online: true),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Abebe Kebede',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'online',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: EthioColors.success,
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
            onPressed: () => context.push('/call/1?video=true'),
          ),
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push('/call/1'),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x4),
              children: [
                Center(
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
                      'Today',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                const SizedBox(height: Sp.x4),
                const MessageBubble(
                  text: 'Hello! How are you?',
                  isMine: false,
                  time: '14:30',
                  status: MessageStatus.read,
                ),
                const SizedBox(height: Sp.x2),
                const MessageBubble(
                  text: 'I am fine, thanks! Are we still meeting tomorrow?',
                  isMine: true,
                  time: '14:32',
                  status: MessageStatus.read,
                ),
                const SizedBox(height: Sp.x2),
                MessageBubble(
                  isMine: false,
                  time: '14:33',
                  child: _VoiceNote(
                    duration: '0:12',
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: Sp.x2),
                MessageBubble(
                  isMine: true,
                  time: '14:35',
                  status: MessageStatus.read,
                  child: _PaymentCard(
                    amount: 'ETB 250.00',
                    note: 'Rent contribution',
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: Sp.x2),
                const MessageBubble(
                  text: 'Yes — see you at 9 at Bole. 🙌',
                  isMine: false,
                  time: '14:36',
                  status: MessageStatus.read,
                ),
                const SizedBox(height: Sp.x1),
                Padding(
                  padding: const EdgeInsets.only(left: Sp.x2),
                  child: Text(
                    'typing…',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: pal.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: pal.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.x2,
                  Sp.x2,
                  Sp.x2,
                  Sp.x2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Attach',
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () {},
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
                                controller: _composer,
                                minLines: 1,
                                maxLines: 4,
                                textCapitalization: TextCapitalization.sentences,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _send(),
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
                              onPressed: () {},
                            ),
                            IconButton(
                              tooltip: 'Camera',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 20,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Sp.x1),
                    IconButton(
                      tooltip: _hasText ? 'Send' : 'Record voice note',
                      icon: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: EthioColors.goldGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: EthioColors.black,
                          size: 20,
                        ),
                      ),
                      onPressed: _hasText ? _send : () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
