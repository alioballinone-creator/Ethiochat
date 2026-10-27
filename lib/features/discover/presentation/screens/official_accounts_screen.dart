import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';

class OfficialAccountsScreen extends StatefulWidget {
  const OfficialAccountsScreen({super.key});

  @override
  State<OfficialAccountsScreen> createState() => _OfficialAccountsScreenState();
}

class _OfficialAccountsScreenState extends State<OfficialAccountsScreen> {
  final Set<String> _following = <String>{'ethio-telecom'};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final q = _query.toLowerCase();
    final accounts = DemoContent.officialAccounts
        .where((account) =>
            q.isEmpty ||
            account.name.toLowerCase().contains(q) ||
            account.category.toLowerCase().contains(q))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Official Accounts', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: Sp.screen.copyWith(top: Sp.x2),
              child: EthioTextField(
                hint: 'Search banks, telecom and news',
                prefix: const Icon(Icons.search_rounded, size: 20),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: accounts.isEmpty
                  ? EthioEmptyState(
                      icon: Icons.verified_outlined,
                      title: 'No accounts found',
                      message: 'Try a different name or category.',
                      action: EthioButton(
                        label: 'Clear search',
                        expand: false,
                        onPressed: () => setState(() => _query = ''),
                      ),
                    )
                  : ListView(
                      padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Sp.x4),
                          decoration: BoxDecoration(
                            color: pal.chip,
                            borderRadius: Rad.r18,
                            border: Border.all(color: pal.line),
                          ),
                          child: Row(
                            children: [
                              const EthioIconTile(
                                icon: Icons.verified_user_outlined,
                                background: EthioColors.gold,
                              ),
                              const SizedBox(width: Sp.x3),
                              Expanded(
                                child: Text(
                                  'Only verified organisations get the gold '
                                  'badge. Look for it before you trust a message.',
                                  style: text.bodySmall?.copyWith(
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Sp.x3),
                        for (final account in accounts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.x2),
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: Rad.r18,
                              child: InkWell(
                                borderRadius: Rad.r18,
                                onTap: () => context.push(
                                  '/discover/official/${account.id}',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(Sp.x4),
                                  decoration: BoxDecoration(
                                    borderRadius: Rad.r18,
                                    border: Border.all(color: pal.line),
                                  ),
                                  child: Row(
                                    children: [
                                      EthioAvatar(
                                        name: account.name,
                                        size: 52,
                                      ),
                                      const SizedBox(width: Sp.x3),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    account.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: text.titleMedium,
                                                  ),
                                                ),
                                                if (account.verified) ...[
                                                  const SizedBox(width: Sp.x1),
                                                  const Icon(
                                                    Icons.verified_rounded,
                                                    size: 16,
                                                    color: EthioColors.goldDeep,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${account.category} · '
                                              '${account.followers} followers',
                                              style: text.labelSmall?.copyWith(
                                                color: pal.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: Sp.x1),
                                            Text(
                                              account.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: text.bodySmall?.copyWith(
                                                color: pal.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: Sp.x2),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            if (!_following
                                                .remove(account.id)) {
                                              _following.add(account.id);
                                            }
                                          });
                                        },
                                        child: Text(
                                          _following.contains(account.id)
                                              ? 'Following'
                                              : 'Follow',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
