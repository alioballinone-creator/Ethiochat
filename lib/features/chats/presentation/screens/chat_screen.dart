import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/app_spacing.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';
import 'package:ethiochat/features/chats/presentation/widgets/message_bubble.dart';
import 'package:ethiochat/l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: const [
                MessageBubble(
                  text: 'Hello!',
                  type: BubbleType.received,
                  time: '10:30',
                ),
                MessageBubble(
                  text: 'Hi there',
                  type: BubbleType.sent,
                  time: '10:31',
                  status: 'read',
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: l10n.typeMessage,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_outlined),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: EthioColors.goldDeep,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
