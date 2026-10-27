import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';

class OfficialAccountScreen extends StatefulWidget {
  const OfficialAccountScreen({super.key, required this.accountId});

  final String accountId;

  @override
  State<OfficialAccountScreen> createState() => _OfficialAccountScreenState();
}

class _OfficialAccountScreenState extends State<OfficialAccountScreen> {
  var _following = true;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final account = DemoContent.officialAccount(widget.accountId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _showMore(context, account),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Rad.r18,
                border: Border.all(color: pal.line),
              ),
              child: Column(
                children: [
                  EthioAvatar(name: account.name, size: 72),
                  const SizedBox(height: Sp.x3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          textAlign: TextAlign.center,
                          style: text.titleLarge,
                        ),
                      ),
                      if (account.verified) ...[
                        const SizedBox(width: Sp.x1),
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: EthioColors.goldDeep,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${account.handle} · ${account.category}',
                    style: text.labelSmall?.copyWith(color: pal.textSecondary),
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    account.description,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: pal.textSecondary),
                  ),
                  const SizedBox(height: Sp.x4),
                  Row(
                    children: [
                      Expanded(
                        child: EthioButton(
                          label: _following ? 'Following' : 'Follow',
                          kind: _following
                              ? EthioButtonKind.secondary
                              : EthioButtonKind.primary,
                          onPressed: () =>
                              setState(() => _following = !_following),
                        ),
                      ),
                      const SizedBox(width: Sp.x2),
                      IconButton.outlined(
                        tooltip: 'Message account',
                        onPressed: () => context.push('/new-chat'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            Row(
              children: [
                Text('Latest updates', style: text.titleMedium),
                const Spacer(),
                Text(
                  '${account.followers} followers',
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: Sp.x2),
            for (var i = 0; i < account.articles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.x2),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: Rad.r18,
                  child: InkWell(
                    borderRadius: Rad.r18,
                    onTap: () => context.push(
                      '/discover/official/${account.id}/article/$i',
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(Sp.x4),
                      decoration: BoxDecoration(
                        borderRadius: Rad.r18,
                        border: Border.all(color: pal.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Sp.x2,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.chip,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  account.articles[i].category,
                                  style: text.labelSmall,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                account.articles[i].date,
                                style: text.labelSmall?.copyWith(
                                  color: pal.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Sp.x2),
                          Text(
                            account.articles[i].title,
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: Sp.x1),
                          Text(
                            account.articles[i].summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: Sp.x2),
                          Row(
                            children: [
                              Text(
                                'Read article',
                                style: text.labelMedium?.copyWith(
                                  color: EthioColors.goldDeep,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: Sp.x1),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: EthioColors.goldDeep,
                              ),
                            ],
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
    );
  }

  void _showMore(BuildContext context, DemoOfficialAccount account) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Mute updates'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${account.name} muted for 8 hours.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report account'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(
                  '/report?target=${Uri.encodeComponent(account.name)}'
                  '&type=account',
                );
              },
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
  }
}
