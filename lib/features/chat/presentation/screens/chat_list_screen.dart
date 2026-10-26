import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
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
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: EthioColors.goldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: EthioColors.black),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: 80),
          children: [
            Wrap(
              spacing: Sp.x2,
              children: [
                Chip(
                  label: const Text('All'),
                  backgroundColor: EthioColors.gold,
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: EthioColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                  side: BorderSide.none,
                ),
                Chip(
                  label: const Text('Unread'),
                  backgroundColor: pal.chip,
                  side: BorderSide(color: pal.line),
                ),
                Chip(
                  label: const Text('Groups'),
                  backgroundColor: pal.chip,
                  side: BorderSide(color: pal.line),
                ),
                Chip(
                  label: const Text('Official'),
                  backgroundColor: pal.chip,
                  side: BorderSide(color: pal.line),
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            const ChatListTile(
              title: 'Abebe Kebede',
              preview: 'See you tomorrow',
              time: '14:32',
              unread: 2,
            ),
            const ChatListTile(
              title: 'Tigist Alemayehu',
              preview: 'Thanks!',
              time: '12:15',
            ),
            const ChatListTile(
              title: 'EthioChat Support',
              preview: 'Welcome to EthioChat',
              time: 'Yesterday',
            ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 0,
        onTap: (i) {
          if (i == 1) Navigator.pushNamed(context, '/contacts');
          if (i == 2) Navigator.pushNamed(context, '/discover');
          if (i == 3) Navigator.pushNamed(context, '/me');
        },
      ),
    );
  }
}
