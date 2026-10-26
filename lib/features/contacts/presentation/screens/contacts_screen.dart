import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Contacts',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: 80),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Rad.r14,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: pal.chip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_add_outlined),
                  ),
                  const SizedBox(width: Sp.x3),
                  Text(
                    'New friends',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x2),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Rad.r14,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: pal.chip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups_outlined),
                  ),
                  const SizedBox(width: Sp.x3),
                  Text(
                    'Group chats',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            Text(
              'A',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: pal.textSecondary,
                  ),
            ),
            const SizedBox(height: Sp.x2),
            ListTile(
              leading: const EthioAvatar(name: 'Abebe Kebede'),
              title: Text('Abebe Kebede', style: Theme.of(context).textTheme.titleMedium),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const EthioAvatar(name: 'Alemayehu T'),
              title: Text('Alemayehu Tadesse', style: Theme.of(context).textTheme.titleMedium),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 1,
        onTap: (i) {
          if (i == 0) Navigator.pushNamed(context, '/chats');
          if (i == 2) Navigator.pushNamed(context, '/discover');
          if (i == 3) Navigator.pushNamed(context, '/me');
        },
      ),
    );
  }
}
