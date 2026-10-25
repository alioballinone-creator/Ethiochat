import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EthioChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat, color: Colors.amber),
              title: const Text('Chats'),
              subtitle: const Text('Start messaging'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/chats'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.amber),
              title: const Text('Wallet'),
              subtitle: const Text('Send, receive, and pay'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/wallet'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.amber),
              title: const Text('Moments'),
              subtitle: const Text('Share your story'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/moments'),
            ),
          ),
        ],
      ),
    );
  }
}
