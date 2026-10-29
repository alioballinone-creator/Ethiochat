import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../contacts/domain/entities/contact_entity.dart';

/// New chat — pick a contact or start a group. Opens a real conversation row.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  String _query = '';

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
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New contact'),
        content: EthioTextField(
          controller: name,
          hint: 'Full name',
          autofocus: true,
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
      return;
    }
    final result = await ref.read(chatRepositoryProvider).addContact(
          displayName: name.text.trim(),
        );
    name.dispose();
    if (!mounted) return;
    if (result.isSuccess) {
      await _openChat(result.valueOrNull!);
    } else {
      _feedback(result.failureOrNull!.message);
    }
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
    ref.watch(demoSeedProvider);
    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.valueOrNull ?? const <ContactEntity>[];
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? contacts
        : contacts
            .where((c) => c.displayName.toLowerCase().contains(q))
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
              child: contactsAsync.isLoading && contacts.isEmpty
                  ? const ContactListSkeleton()
                  : ListView(
                      padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                      children: [
                        _ActionRow(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'New contact',
                          onTap: _addContact,
                        ),
                        _ActionRow(
                          icon: Icons.group_add_outlined,
                          title: 'New group',
                          onTap: () => context.push('/new-group'),
                        ),
                        const SizedBox(height: Sp.x4),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: Sp.x8),
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
                                  'Try another name or invite a friend.',
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    color: pal.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: Sp.x4),
                                EthioButton(
                                  label: 'New contact',
                                  expand: false,
                                  onPressed: _addContact,
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Text('Contacts', style: text.titleMedium),
                          const SizedBox(height: Sp.x2),
                          for (final c in filtered)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: Sp.x1,
                                vertical: Sp.x1,
                              ),
                              leading: EthioAvatar(
                                name: c.displayName,
                                imageUrl: c.avatarUrl,
                                size: 48,
                              ),
                              title: Text(
                                c.displayName,
                                style: text.titleMedium,
                              ),
                              subtitle: Text(
                                c.phoneE164 ??
                                    'Hey there! I am using EthioChat.',
                                style: text.labelSmall?.copyWith(
                                  color: pal.textSecondary,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 20,
                                color: pal.textTertiary,
                              ),
                              onTap: () => _openChat(c),
                            ),
                        ],
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
