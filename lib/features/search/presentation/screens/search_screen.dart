import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// Global search across chats, contacts and messages.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int _filter = 0;

  static const _filters = ['All', 'Chats', 'Contacts', 'Messages', 'Files'];

  static const _recent = [
    'Abebe Kebede',
    'rent',
    'Tigist',
    'Bole',
    'invoice.pdf',
  ];

  static const _contacts = [
    ('Abebe Kebede', 'See you tomorrow'),
    ('Tigist Alemayehu', 'Thanks!'),
    ('Dawit Bekele', 'On my way'),
  ];

  static const _messages = [
    ('Abebe Kebede', 'I will send the rent tomorrow morning'),
    ('Tigist Alemayehu', 'Thanks for the invoice'),
    ('Work group', 'Meeting moved to 3 PM'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) => setState(() => _query = value.trim());

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final q = _query.toLowerCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Search', style: text.headlineMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
                  : _results(context, pal, text, q),
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
            Text('Recent searches', style: text.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: Sp.x2),
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
                onPressed: () {
                  _controller.text = term;
                  _search(term);
                },
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
          onTap: () {},
        ),
        _BrowseRow(
          icon: Icons.people_outline_rounded,
          title: 'Contacts',
          subtitle: 'Find people you know',
          onTap: () {},
        ),
        _BrowseRow(
          icon: Icons.image_outlined,
          title: 'Media',
          subtitle: 'Photos, videos, documents',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    EthioPalette pal,
    TextTheme text,
    String q,
  ) {
    final contacts = _contacts
        .where((c) => c.$1.toLowerCase().contains(q))
        .toList(growable: false);
    final messages = _messages
        .where((m) =>
            m.$1.toLowerCase().contains(q) || m.$2.toLowerCase().contains(q))
        .toList(growable: false);

    final showContacts = _filter == 0 || _filter == 2;
    final showMessages = _filter == 0 || _filter == 3;
    final empty =
        (!showContacts || contacts.isEmpty) && (!showMessages || messages.isEmpty);

    return ListView(
      padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: Sp.x2),
            itemBuilder: (context, i) {
              final selected = i == _filter;
              return ChoiceChip(
                label: Text(_filters[i]),
                selected: selected,
                showCheckmark: false,
                backgroundColor: pal.chip,
                selectedColor: EthioColors.gold,
                side: BorderSide(color: selected ? Colors.transparent : pal.line),
                labelStyle: text.labelMedium?.copyWith(
                  color: selected ? EthioColors.black : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _filter = i),
              );
            },
          ),
        ),
        const SizedBox(height: Sp.x4),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: Sp.x10),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 44, color: pal.textTertiary),
                const SizedBox(height: Sp.x3),
                Text('No results for “$_query”', style: text.titleMedium),
                const SizedBox(height: Sp.x1),
                Text(
                  'Try a different name or keyword.',
                  style: text.bodyMedium?.copyWith(color: pal.textSecondary),
                ),
              ],
            ),
          ),
        if (showContacts && contacts.isNotEmpty) ...[
          Text('Contacts', style: text.titleMedium),
          const SizedBox(height: Sp.x2),
          _Group(
            children: [
              for (final c in contacts)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4,
                    vertical: Sp.x1,
                  ),
                  leading: EthioAvatar(name: c.$1, size: 44),
                  title: Text(c.$1, style: text.titleMedium),
                  subtitle: Text(
                    c.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: pal.textSecondary),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: Sp.x4),
        ],
        if (showMessages && messages.isNotEmpty) ...[
          Text('Messages', style: text.titleMedium),
          const SizedBox(height: Sp.x2),
          _Group(
            children: [
              for (final m in messages)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4,
                    vertical: Sp.x1,
                  ),
                  leading: EthioAvatar(name: m.$1, size: 44),
                  title: Text(m.$1, style: text.titleMedium),
                  subtitle: Text(
                    m.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: pal.textSecondary),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: pal.textTertiary,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ],
      ],
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
