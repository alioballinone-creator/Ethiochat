import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../chats/domain/entities/conversation_summary.dart';
import '../../../chats/domain/entities/message_entity.dart' as entity;
import '../../../contacts/domain/entities/contact_entity.dart';

/// Global search across chats, contacts and messages (local database).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String _committed = '';
  int _filter = 0;
  Timer? _debounce;
  Timer? _saveTimer;
  static const _queryKey = 'search.query';
  static const _filterKey = 'search.filter';
  final _recent = <String>[
    'Abebe Kebede',
    'rent',
    'Tigist',
    'Bole',
    'invoice.pdf',
  ];

  static const _filters = ['All', 'Chats', 'Contacts', 'Messages', 'Files'];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreSearchState);
  }

  Future<void> _restoreSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final query = prefs.getString(_queryKey) ?? '';
      setState(() {
        _query = query;
        _committed = query;
        _filter = (prefs.getInt(_filterKey) ?? 0)
            .clamp(0, _filters.length - 1)
            .toInt();
        _controller.text = query;
        _controller.selection = TextSelection.collapsed(offset: query.length);
      });
    } catch (_) {
      // Search remains available with a blank query if storage is unavailable.
    }
  }

  void _scheduleSearchStateSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _persistSearchState);
  }

  Future<void> _persistSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queryKey, _query);
      await prefs.setInt(_filterKey, _filter);
    } catch (_) {
      // Search remains usable when preference storage is unavailable.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _saveTimer?.cancel();
    unawaited(_persistSearchState());
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _query = value.trim());
    _scheduleSearchStateSave();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _committed = value.trim());
    });
  }

  void _useRecent(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    setState(() {
      _query = term;
      _committed = term;
    });
    _scheduleSearchStateSave();
  }

  Future<void> _openConversation(String id) async {
    context.push('/chats/$id');
  }

  Future<void> _openContact(ContactEntity contact) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .openDirectChat(contact.displayName);
    if (!mounted) return;
    final conversation = result.valueOrNull;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull?.message ?? 'Failed')),
      );
      return;
    }
    context.push('/chats/${conversation.id}');
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
    final q = _query.toLowerCase();
    final committed = _committed.toLowerCase();

    final summaries = ref.watch(conversationSummariesProvider).valueOrNull ??
        const <ConversationSummary>[];
    final contacts =
        ref.watch(contactsProvider).valueOrNull ?? const <ContactEntity>[];
    final messageResults = committed.length < 2
        ? const <entity.MessageEntity>[]
        : ref.watch(messageSearchProvider(_committed)).valueOrNull ??
            const <entity.MessageEntity>[];

    final matchingChats = q.isEmpty
        ? const <ConversationSummary>[]
        : summaries
            .where((c) =>
                c.title.toLowerCase().contains(q) ||
                c.preview.toLowerCase().contains(q))
            .toList(growable: false);
    final matchingContacts = q.isEmpty
        ? const <ContactEntity>[]
        : contacts
            .where((c) =>
                c.displayName.toLowerCase().contains(q) ||
                (c.phoneE164 ?? '').contains(q))
            .toList(growable: false);
    final matchingMessages = messageResults;
    final matchingFiles = messageResults
        .where((m) => m.type == entity.MessageType.file)
        .toList(growable: false);
    final showChats = _filter == 0 || _filter == 1;
    final showContacts = _filter == 0 || _filter == 2;
    final showMessages = _filter == 0 || _filter == 3;
    final showFiles = _filter == 0 || _filter == 4;
    final empty = q.isNotEmpty &&
        (!showChats || matchingChats.isEmpty) &&
        (!showContacts || matchingContacts.isEmpty) &&
        (!showMessages || matchingMessages.isEmpty) &&
        (!showFiles || matchingFiles.isEmpty);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Search', style: text.headlineMedium),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: Sp.screen.copyWith(top: Sp.x2),
              child: EthioTextField(
                controller: _controller,
                hint: 'Search chats, contacts and messages',
                autofocus: true,
                prefix: const Icon(Icons.search_rounded, size: 20),
                onChanged: _search,
                suffix: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _emptyState(context, pal, text)
                  : ListView(
                      padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
                      children: [
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: Sp.x2),
                            itemBuilder: (context, i) {
                              final selected = i == _filter;
                              return ChoiceChip(
                                label: Text(_filters[i]),
                                selected: selected,
                                showCheckmark: false,
                                backgroundColor: pal.chip,
                                selectedColor: EthioColors.gold,
                                side: BorderSide(
                                  color:
                                      selected ? Colors.transparent : pal.line,
                                ),
                                labelStyle: text.labelMedium?.copyWith(
                                  color: selected ? EthioColors.black : null,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                onSelected: (_) {
                                  setState(() => _filter = i);
                                  _scheduleSearchStateSave();
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: Sp.x4),
                        if (_filter == 4 && matchingFiles.isEmpty)
                          _NoResults(
                            icon: Icons.folder_open_outlined,
                            title: 'No matching files',
                            subtitle:
                                'Documents shared in chats will appear here.',
                          ),
                        if (empty)
                          _NoResults(
                            icon: Icons.search_off_rounded,
                            title: 'No results for “$_query”',
                            subtitle: 'Try a different name or keyword.',
                          ),
                        if (showChats && matchingChats.isNotEmpty) ...[
                          Text('Chats', style: text.titleMedium),
                          const SizedBox(height: Sp.x2),
                          _Group(
                            children: [
                              for (final chat in matchingChats)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: Sp.x4,
                                    vertical: Sp.x1,
                                  ),
                                  leading: EthioAvatar(
                                    name: chat.title,
                                    imageUrl: chat.conversation.avatarUrl,
                                    size: 44,
                                  ),
                                  title: Text(
                                    chat.title,
                                    style: text.titleMedium,
                                  ),
                                  subtitle: Text(
                                    chat.preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.labelSmall?.copyWith(
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  onTap: () => _openConversation(chat.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: Sp.x4),
                        ],
                        if (showContacts && matchingContacts.isNotEmpty) ...[
                          Text('Contacts', style: text.titleMedium),
                          const SizedBox(height: Sp.x2),
                          _Group(
                            children: [
                              for (final c in matchingContacts)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: Sp.x4,
                                    vertical: Sp.x1,
                                  ),
                                  leading: EthioAvatar(
                                    name: c.displayName,
                                    imageUrl: c.avatarUrl,
                                    size: 44,
                                  ),
                                  title: Text(
                                    c.displayName,
                                    style: text.titleMedium,
                                  ),
                                  subtitle: Text(
                                    c.phoneE164 ?? 'EthioChat contact',
                                    style: text.labelSmall?.copyWith(
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  onTap: () => _openContact(c),
                                ),
                            ],
                          ),
                          const SizedBox(height: Sp.x4),
                        ],
                        if (showMessages && matchingMessages.isNotEmpty) ...[
                          Text('Messages', style: text.titleMedium),
                          const SizedBox(height: Sp.x2),
                          _Group(
                            children: [
                              for (final m in matchingMessages)
                                Builder(
                                  builder: (context) {
                                    final chat = summaries
                                        .where((c) => c.id == m.conversationId)
                                        .toList(growable: false);
                                    final title = chat.isEmpty
                                        ? 'Chat'
                                        : chat.first.title;
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: Sp.x4,
                                        vertical: Sp.x1,
                                      ),
                                      leading:
                                          EthioAvatar(name: title, size: 44),
                                      title: Text(
                                        title,
                                        style: text.titleMedium,
                                      ),
                                      subtitle: Text(
                                        m.body ?? '[${m.type.name}]',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodySmall?.copyWith(
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.chevron_right_rounded,
                                        color: pal.textTertiary,
                                      ),
                                      onTap: () => _openConversation(
                                        m.conversationId,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                        if (showFiles && matchingFiles.isNotEmpty) ...[
                          Text('Files', style: text.titleMedium),
                          const SizedBox(height: Sp.x2),
                          _Group(
                            children: [
                              for (final file in matchingFiles)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: Sp.x4,
                                    vertical: Sp.x1,
                                  ),
                                  leading: const Icon(
                                    Icons.insert_drive_file_outlined,
                                  ),
                                  title: Text(
                                    file.body ?? 'Document',
                                    style: text.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Shared in a chat',
                                    style: text.labelSmall?.copyWith(
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  onTap: () =>
                                      _openConversation(file.conversationId),
                                ),
                            ],
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

  Widget _emptyState(
    BuildContext context,
    EthioPalette pal,
    TextTheme text,
  ) {
    return ListView(
      padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent searches',
                style: text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _recent.isEmpty ? null : () => setState(_recent.clear),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: Sp.x2),
        if (_recent.isEmpty)
          Text(
            'No recent searches',
            style: text.bodyMedium?.copyWith(color: pal.textSecondary),
          )
        else
          Wrap(
            spacing: Sp.x2,
            runSpacing: Sp.x2,
            children: [
              for (final term in _recent)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(term),
                  backgroundColor: pal.chip,
                  side: BorderSide(color: pal.line),
                  onPressed: () => _useRecent(term),
                ),
            ],
          ),
        const SizedBox(height: Sp.x6),
        Text('Browse', style: text.titleMedium),
        const SizedBox(height: Sp.x2),
        _BrowseRow(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Chats',
          subtitle: 'Search by name or group',
          onTap: () => setState(() => _filter = 1),
        ),
        _BrowseRow(
          icon: Icons.people_outline_rounded,
          title: 'Contacts',
          subtitle: 'Find people you know',
          onTap: () => setState(() => _filter = 2),
        ),
        _BrowseRow(
          icon: Icons.image_outlined,
          title: 'Media',
          subtitle: 'Photos, videos, documents',
          onTap: () => _feedback(
            'Type a keyword to search media shared in your chats.',
          ),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: Sp.x10),
      child: Column(
        children: [
          Icon(icon, size: 44, color: pal.textTertiary),
          const SizedBox(height: Sp.x3),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Sp.x1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: pal.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BrowseRow extends StatelessWidget {
  const _BrowseRow({
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

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r18,
        border: Border.all(color: pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: Sp.x4 + 44 + Sp.x3,
                endIndent: Sp.x4,
                color: pal.line,
              ),
          ],
        ],
      ),
    );
  }
}
