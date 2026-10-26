import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// 06 — Contacts.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _query = '';

  static const _people = <String>[
    'Abebe Kebede',
    'Alemayehu Tadesse',
    'Amanuel Girma',
    'Dawit Bekele',
    'Hanna Girma',
    'Marta Assefa',
    'Samuel Tesfaye',
    'Selam Bekele',
    'Tigist Alemayehu',
    'Yonas Alemu',
  ];

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();

    final grouped = <String, List<String>>{};
    for (final person in _people) {
      if (q.isNotEmpty && !person.toLowerCase().contains(q)) continue;
      grouped.putIfAbsent(person[0].toUpperCase(), () => <String>[]).add(person);
    }
    final letters = grouped.keys.toList(growable: false)..sort();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Contacts', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push('/new-chat'),
          ),
          IconButton(
            tooltip: 'Add contact',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
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
                  child: ListView(
                    padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                    children: [
                      if (q.isEmpty) ...[
                        _ShortcutRow(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'New friends',
                          subtitle: 'Invite people to EthioChat',
                          onTap: () {},
                        ),
                        _ShortcutRow(
                          icon: Icons.group_add_outlined,
                          title: 'Group chats',
                          subtitle: 'Your groups in one place',
                          onTap: () => context.push('/new-group'),
                        ),
                        _ShortcutRow(
                          icon: Icons.verified_outlined,
                          title: 'Official accounts',
                          subtitle: 'Banks, telecom and news',
                          onTap: () {},
                        ),
                        _ShortcutRow(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Scan QR',
                          subtitle: 'Add a friend by code',
                          onTap: () {},
                        ),
                        const SizedBox(height: Sp.x4),
                      ],
                      if (letters.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: Sp.x10),
                          child: Column(
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
                                'Try another name.',
                                style: text.bodyMedium
                                    ?.copyWith(color: pal.textSecondary),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final letter in letters) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Sp.x1,
                              Sp.x3,
                              Sp.x1,
                              Sp.x1,
                            ),
                            child: Text(
                              letter,
                              style: text.labelMedium
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                          ),
                          for (final person in grouped[letter]!)
                            ListTile(
                              onTap: () => context.push('/chats/1'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: Sp.x1,
                                vertical: Sp.x1,
                              ),
                              leading: EthioAvatar(name: person, size: 48),
                              title: Text(person, style: text.titleMedium),
                              subtitle: Text(
                                'Hey there! I am using EthioChat.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall
                                    ?.copyWith(color: pal.textSecondary),
                              ),
                            ),
                        ],
                    ],
                  ),
                ),
              ],
            ),
            if (q.isEmpty && letters.isNotEmpty)
              Positioned(
                right: Sp.x1,
                top: 80,
                bottom: 80,
                child: _IndexRail(
                  letters: letters,
                  onLetter: (letter) {
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 1,
        onTap: (i) {
          if (i == 0) context.go('/chats');
          if (i == 2) context.go('/discover');
          if (i == 3) context.go('/me');
        },
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r14,
        border: Border.all(color: pal.line),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sp.x4,
          vertical: Sp.x1,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: pal.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: pal.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: pal.textTertiary),
      ),
    );
  }
}

class _IndexRail extends StatelessWidget {
  const _IndexRail({required this.letters, required this.onLetter});

  final List<String> letters;
  final ValueChanged<String> onLetter;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return GestureDetector(
      onVerticalDragUpdate: (_) => onLetter(''),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final letter in letters)
              GestureDetector(
                onTap: () => onLetter(letter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.x2,
                    vertical: 2,
                  ),
                  child: Text(
                    letter,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: pal.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
