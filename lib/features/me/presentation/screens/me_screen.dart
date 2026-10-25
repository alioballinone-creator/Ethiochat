import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
      ),
      body: ListView(
        children: [
          const UserAccountsDrawerHeader(
            accountName: Text('User'),
            accountEmail: Text('+251...'),
            currentAccountPicture: CircleAvatar(
              child: Icon(Icons.person),
            ),
            decoration: BoxDecoration(color: Colors.amber),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Wallet'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/wallet'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
