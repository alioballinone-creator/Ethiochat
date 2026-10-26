import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../contacts/domain/entities/contact_entity.dart';

/// New group — search, multi-select contacts and name the group.
class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _name = TextEditingController();
  final _selected = <String>{};
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    setState(() {
      if (!_selected.remove(name)) _selected.add(name);
    });
  }

  Future<void> _create() async {
    if (_selected.isEmpty || _creating) return;
    setState(() => _creating = true);
    final result = await ref.read(chatRepositoryProvider).createGroup(
          _name.text.trim(),
          _selected.toList(growable: false),
        );
    if (!mounted) return;
    setState(() => _creating = false);
    final conversation = result.valueOrNull;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result.failureOrNull?.message ?? 'Could not create group'),
        ),
      );
      return;
    }
    context.go('/chats/${conversation.id}');
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
        title: Text('New group', style: text.headlineMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Sp.x4),
            child: SizedBox(
              width: 96,
              child: EthioButton(
                label: _creating ? 'Creating…' : 'Create',
                size: EthioButtonSize.small,
                expand: false,
                onPressed: _selected.isEmpty || _creating ? null : _create,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_selected.isNotEmpty)
              SizedBox(
                height: 92,
                child: ListView.separated(
                  padding: Sp.screen.copyWith(top: Sp.x3),
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Sp.x3),
                  itemBuilder: (context, i) {
                    final name = _selected.elementAt(i);
                    return SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              EthioAvatar(name: name),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: InkWell(
                                  onTap: () => _toggle(name),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: EthioColors.blackSoft,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Sp.x1),
                          Text(
                            name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: Sp.screen.copyWith(top: Sp.x2),
              child: Column(
                children: [
                  EthioTextField(
                    controller: _name,
                    hint: 'Group name (optional)',
                    maxLength: 40,
                  ),
                  const SizedBox(height: Sp.x3),
                  EthioTextField(
                    hint: 'Search contacts',
                    prefix: const Icon(Icons.search_rounded, size: 20),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x3),
            Expanded(
              child: contactsAsync.isLoading && contacts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: Sp.screen.copyWith(bottom: Sp.x8),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final contact = filtered[i];
                        final checked = _selected.contains(contact.displayName);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Sp.x1,
                            vertical: Sp.x1,
                          ),
                          onTap: () => _toggle(contact.displayName),
                          leading: EthioAvatar(
                            name: contact.displayName,
                            imageUrl: contact.avatarUrl,
                            size: 48,
                          ),
                          title: Text(
                            contact.displayName,
                            style: text.titleMedium,
                          ),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient:
                                  checked ? EthioColors.goldGradient : null,
                              color: checked ? null : pal.chip,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: checked ? Colors.transparent : pal.line,
                                width: 1.5,
                              ),
                            ),
                            child: checked
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: EthioColors.black,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
