import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../domain/entities/contact_entity.dart';

/// 06 — Contacts, backed by the local contact table.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _jumpTo(String letter) async {
    final key = _sectionKeys[letter];
    final target = key?.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _openChat(ContactEntity contact) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .openDirectChat(contact.displayName);
    if (!mounted) return;
    final conversation = result.valueOrNull;
    if (conversation == null) {
      _feedback(result.failureOrNull?.message ?? 'Could not open chat');
      return;
    }
    context.push('/chats/${conversation.id}');
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EthioTextField(
              controller: name,
              hint: 'Full name',
              autofocus: true,
            ),
            const SizedBox(height: Sp.x3),
            EthioTextField(
              controller: phone,
              hint: '+251 91 234 5678',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (name.text.trim().length < 2) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (created != true || !mounted) {
      name.dispose();
      phone.dispose();
      return;
    }
    final result = await ref.read(chatRepositoryProvider).addContact(
          displayName: name.text.trim(),
          phoneE164: phone.text.trim().isEmpty ? null : phone.text.trim(),
        );
    if (!mounted) {
      name.dispose();
      phone.dispose();
      return;
    }
    _feedback(
      result.isSuccess
          ? '${result.valueOrNull!.displayName} added'
          : result.failureOrNull!.message,
    );
    name.dispose();
    phone.dispose();
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
    final text = Theme.of(context).textTheme;
    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.valueOrNull ?? const <ContactEntity>[];
    final q = _query.trim().toLowerCase();

    final grouped = <String, List<ContactEntity>>{};
    for (final contact in contacts) {
      if (contact.isBlocked) continue;
      if (q.isNotEmpty &&
          !contact.displayName.toLowerCase().contains(q) &&
          !(contact.phoneE164 ?? '').toLowerCase().contains(q) &&
          !(contact.ethioId ?? '').toLowerCase().contains(q)) {
        continue;
      }
      final letter = contact.displayName.isEmpty
          ? '#'
          : contact.displayName[0].toUpperCase();
      grouped.putIfAbsent(letter, () => <ContactEntity>[]).add(contact);
    }
    final letters = grouped.keys.toList(growable: false)..sort();
    for (final letter in letters) {
      _sectionKeys.putIfAbsent(letter, () => GlobalKey());
    }

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
            onPressed: _addContact,
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
                  child: contactsAsync.isLoading && contacts.isEmpty
                      ? const ContactListSkeleton()
                      : ListView(
                          controller: _scrollController,
                          padding:
                              Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                          children: [
                            if (q.isEmpty) ...[
                              _ShortcutRow(
                                icon: Icons.person_add_alt_1_outlined,
                                title: 'New friends',
                                subtitle: 'Friend requests waiting for you',
                                onTap: () => context.push('/contacts/requests'),
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
                                onTap: () => context.push('/discover/official'),
                              ),
                              _ShortcutRow(
                                icon: Icons.qr_code_scanner_rounded,
                                title: 'Scan QR',
                                subtitle: 'Add a friend by code',
                                onTap: () => context.push('/scan'),
                              ),
                              _ShortcutRow(
                                icon: Icons.block_outlined,
                                title: 'Blocked contacts',
                                subtitle: 'Review people you blocked',
                                onTap: () => context
                                    .push('/me/settings/privacy/blocked'),
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
                                    Text(
                                      'No contacts found',
                                      style: text.titleMedium,
                                    ),
                                    const SizedBox(height: Sp.x1),
                                    Text(
                                      'Try another name or add someone new.',
                                      textAlign: TextAlign.center,
                                      style: text.bodyMedium?.copyWith(
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: Sp.x4),
                                    EthioButton(
                                      label: 'Add contact',
                                      expand: false,
                                      onPressed: _addContact,
                                    ),
                                  ],
                                ),
                              )
                            else
                              for (final letter in letters) ...[
                                Padding(
                                  key: _sectionKeys[letter],
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
                                for (final contact in grouped[letter]!)
                                  ListTile(
                                    onTap: () => _openChat(contact),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: Sp.x1,
                                      vertical: Sp.x1,
                                    ),
                                    leading: EthioAvatar(
                                      name: contact.displayName,
                                      imageUrl: contact.avatarUrl,
                                      size: 48,
                                    ),
                                    title: Text(
                                      contact.displayName,
                                      style: text.titleMedium,
                                    ),
                                    subtitle: Text(
                                      contact.phoneE164 ??
                                          'Hey there! I am using EthioChat.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.labelSmall?.copyWith(
                                        color: pal.textSecondary,
                                      ),
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
                    _jumpTo(letter);
                  },
                ),
              ),
          ],
        ),
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
