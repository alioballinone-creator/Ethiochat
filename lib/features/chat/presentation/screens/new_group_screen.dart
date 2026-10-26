import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// New group — search, multi-select contacts and name the group.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  final _selected = <String>{};
  String _query = '';

  static const _contacts = [
    'Abebe Kebede',
    'Tigist Alemayehu',
    'Dawit Bekele',
    'Hanna Girma',
    'Samuel Tesfaye',
    'Marta Assefa',
    'Yonas Alemu',
    'Selam Bekele',
  ];

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

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _contacts
        : _contacts.where((c) => c.toLowerCase().contains(q)).toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('New group', style: text.headlineMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x2),
            child: EthioButton(
              label: 'Create',
              size: EthioButtonSize.small,
              expand: false,
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      context.go('/chats/1');
                    },
            ),
          ),
          const SizedBox(width: Sp.x4),
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
                              EthioAvatar(name: name, size: 52),
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
              child: ListView.builder(
                padding: Sp.screen.copyWith(bottom: Sp.x8),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final name = filtered[i];
                  final checked = _selected.contains(name);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Sp.x1,
                      vertical: Sp.x1,
                    ),
                    onTap: () => _toggle(name),
                    leading: EthioAvatar(name: name, size: 48),
                    title: Text(name, style: text.titleMedium),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: checked ? EthioColors.goldGradient : null,
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
