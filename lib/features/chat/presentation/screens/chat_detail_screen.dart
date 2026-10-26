import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';

class ChatDetailScreen extends StatelessWidget {
  final String chatId;
  const ChatDetailScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
    return Scaffold(
      backgroundColor: pal.wallpaper,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const EthioAvatar(name: 'Abebe', size: 40),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abebe Kebede',
                    style: Theme.of(context).textTheme.titleMedium,
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
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: Sp.screen,
              children: [
                const SizedBox(height: Sp.x4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1),
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
                  text: 'I am fine, thanks!',
                  isMine: true,
                  time: '14:32',
                  status: MessageStatus.read,
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
                padding: const EdgeInsets.all(Sp.x3),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: pal.line),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Message',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: EthioColors.goldGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic_rounded, color: EthioColors.black),
                      ),
                      onPressed: () {},
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
