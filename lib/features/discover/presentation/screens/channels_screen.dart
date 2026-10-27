import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final Set<String> _following = <String>{'addis-daily'};

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Channels', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'Search channels',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
          itemCount: DemoContent.channels.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: Sp.x3),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(Sp.x4),
                decoration: BoxDecoration(
                  color: pal.chip,
                  borderRadius: Rad.r18,
                  border: Border.all(color: pal.line),
                ),
                child: Row(
                  children: [
                    const EthioIconTile(
                      icon: Icons.wifi_tethering_rounded,
                      background: EthioColors.gold,
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Follow what matters', style: text.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            'News, faith, music and city life from trusted '
                            'Ethiopian voices.',
                            style: text.bodySmall
                                ?.copyWith(color: pal.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            final channel = DemoContent.channels[index - 1];
            final following = _following.contains(channel.id);
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: Rad.r18,
              child: InkWell(
                borderRadius: Rad.r18,
                onTap: () => context.push('/discover/channels/${channel.id}'),
                child: Container(
                  padding: const EdgeInsets.all(Sp.x4),
                  decoration: BoxDecoration(
                    borderRadius: Rad.r18,
                    border: Border.all(color: pal.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: channel.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 30,
                          color: channel.accent,
                        ),
                      ),
                      const SizedBox(width: Sp.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    channel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleMedium,
                                  ),
                                ),
                                if (channel.verified) ...[
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
                              '${channel.handle} · ${channel.followers} followers',
                              style: text.labelSmall
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                            const SizedBox(height: Sp.x1),
                            Text(
                              channel.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Sp.x2),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (!_following.remove(channel.id)) {
                              _following.add(channel.id);
                            }
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                following
                                    ? 'Unfollowed ${channel.name}.'
                                    : 'Following ${channel.name}.',
                              ),
                            ),
                          );
                        },
                        child: Text(following ? 'Following' : 'Follow'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch<void>(
      context: context,
      delegate: _ChannelSearchDelegate(DemoContent.channels),
    );
  }
}

class _ChannelSearchDelegate extends SearchDelegate<void> {
  _ChannelSearchDelegate(this.channels);

  final List<DemoChannel> channels;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Clear',
            onPressed: () => query = '',
            icon: const Icon(Icons.close_rounded),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'Back',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? channels
        : channels
            .where((channel) =>
                channel.name.toLowerCase().contains(q) ||
                channel.handle.toLowerCase().contains(q) ||
                channel.description.toLowerCase().contains(q))
            .toList(growable: false);
    if (matches.isEmpty) {
      return const Center(child: Text('No channels found.'));
    }
    return ListView(
      padding: Sp.screen.copyWith(top: Sp.x3),
      children: [
        for (final channel in matches)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: channel.accent.withValues(alpha: 0.16),
              child: Icon(Icons.play_arrow_rounded, color: channel.accent),
            ),
            title: Text(channel.name),
            subtitle: Text(channel.description, maxLines: 1),
            onTap: () => context.push('/discover/channels/${channel.id}'),
          ),
      ],
    );
  }
}
