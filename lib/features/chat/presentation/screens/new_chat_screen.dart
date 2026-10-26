import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// New chat — pick a contact or start a group.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  String _query = '';

  static const _contacts = [
    ('Abebe Kebede', 'online'),
    ('Tigist Alemayehu', 'last seen 12:15'),
    ('Dawit Bekele', 'last seen yesterday'),
    ('Hanna Girma', 'online'),
    ('Samuel Tesfaye', 'last seen 09:02'),
    ('Marta Assefa', 'last seen Monday'),
    ('Yonas Alemu', 'online'),
    ('Selam Bekele', 'last seen 21:40'),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _contacts
        : _contacts
            .where((c) => c.$1.toLowerCase().contains(q))
            .toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('New chat', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'New group',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => context.push('/new-group'),
          ),
          const SizedBox(width: Sp.x2),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: Sp.screen.copyWith(top: Sp.x2),
              child: EthioTextField(
                hint: 'Search contacts',
                prefix: const Icon(Icons.search_rounded, size: 20),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: Sp.screen,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 44,
                              color: pal.textTertiary,
                            ),
                            const SizedBox(height: Sp.x3),
                            Text('No contacts found', style: text.titleMedium),
                            const SizedBox(height: Sp.x1),
                            Text(
                              'Try another name or invite a friend.',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                      children: [
                        _ActionRow(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'New contact',
                          onTap: () {},
                        ),
                        _ActionRow(
                          icon: Icons.group_add_outlined,
                          title: 'New group',
                          onTap: () => context.push('/new-group'),
                        ),
                        const SizedBox(height: Sp.x4),
                        Text('Contacts', style: text.titleMedium),
                        const SizedBox(height: Sp.x2),
                        for (final c in filtered)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Sp.x1,
                              vertical: Sp.x1,
                            ),
                            leading: EthioAvatar(name: c.$1, size: 48),
                            title: Text(c.$1, style: text.titleMedium),
                            subtitle: Text(
                              c.$2,
                              style: text.labelSmall
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                            trailing: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 20,
                              color: pal.textTertiary,
                            ),
                            onTap: () => context.go('/chats/1'),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x1),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: EthioColors.goldGradient,
          borderRadius: Rad.r14,
        ),
        child: Icon(icon, color: EthioColors.black, size: 22),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: EthioPalette.of(context).textTertiary,
      ),
    );
  }
}
