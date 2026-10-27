import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';

class ChannelDetailScreen extends StatefulWidget {
  const ChannelDetailScreen({super.key, required this.channelId});

  final String channelId;

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  var _postIndex = 0;
  var _playing = false;
  var _followed = true;
  final _liked = <String>{};
  final _comments = <String, List<String>>{};

  DemoChannel get _channel => DemoContent.channel(widget.channelId);
  DemoPost get _post => _channel.posts[_postIndex];

  String get _postKey => '${_channel.id}-$_postIndex';

  Future<void> _comment() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final comments = _comments.putIfAbsent(_postKey, () => <String>[]);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheetState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                    child: Row(
                      children: [
                        Text(
                          'Comments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text('${comments.length}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Sp.x6),
                      child: Text(
                        'No comments yet. Start the conversation.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(
                        shrinkWrap: true,
                        padding: Sp.screen,
                        children: [
                          for (final comment in comments)
                            ListTile(
                              dense: true,
                              leading:
                                  const EthioAvatar(name: 'Viewer', size: 32),
                              title: Text(comment),
                              subtitle: const Text('just now'),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: Sp.screen.copyWith(top: Sp.x2),
                    child: Row(
                      children: [
                        Expanded(
                          child: EthioTextField(
                            controller: controller,
                            hint: 'Add a comment',
                          ),
                        ),
                        const SizedBox(width: Sp.x2),
                        IconButton(
                          tooltip: 'Send comment',
                          icon: const Icon(
                            Icons.send_rounded,
                            color: EthioColors.goldDeep,
                          ),
                          onPressed: () {
                            final value = controller.text.trim();
                            if (value.isEmpty) return;
                            setSheetState(() => comments.add(value));
                            controller.clear();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(
        text: '${_post.title} — ${_channel.name} on EthioChat',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Channel link copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final likeKey = _postKey;
    final liked = _liked.contains(likeKey);
    final commentCount = _comments[_postKey]?.length ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              title: Text(_channel.name, style: text.titleMedium),
              actions: [
                IconButton(
                  tooltip: 'Share channel',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: _share,
                ),
                const SizedBox(width: Sp.x1),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: Sp.screen.copyWith(top: Sp.x2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Sp.x5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _channel.accent,
                            _channel.accent.withValues(alpha: 0.72),
                          ],
                        ),
                        borderRadius: Rad.r24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 32,
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
                                            _channel.name,
                                            style: text.titleLarge?.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (_channel.verified) ...[
                                          const SizedBox(width: Sp.x1),
                                          const Icon(
                                            Icons.verified_rounded,
                                            size: 17,
                                            color: EthioColors.gold,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${_channel.handle} · ${_channel.followers}'
                                      ' followers',
                                      style: text.labelSmall?.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _followed = !_followed),
                                style: TextButton.styleFrom(
                                  backgroundColor: _followed
                                      ? Colors.white.withValues(alpha: 0.16)
                                      : EthioColors.gold,
                                  foregroundColor: _followed
                                      ? Colors.white
                                      : EthioColors.black,
                                ),
                                child: Text(_followed ? 'Following' : 'Follow'),
                              ),
                            ],
                          ),
                          const SizedBox(height: Sp.x4),
                          Text(
                            _channel.description,
                            style: text.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Sp.x4),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: EthioColors.black,
                          borderRadius: Rad.r24,
                          border: Border.all(color: pal.line),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: Rad.r24,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _channel.accent.withValues(alpha: 0.7),
                                    EthioColors.black,
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: IconButton.filled(
                                tooltip: _playing ? 'Pause' : 'Play',
                                style: IconButton.styleFrom(
                                  backgroundColor: EthioColors.gold,
                                  foregroundColor: EthioColors.black,
                                ),
                                iconSize: 34,
                                onPressed: () =>
                                    setState(() => _playing = !_playing),
                                icon: Icon(
                                  _playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                            ),
                            Positioned(
                              left: Sp.x4,
                              right: Sp.x4,
                              bottom: Sp.x4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.title,
                                    style: text.titleMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(height: Sp.x2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _playing ? 0.42 : 0.18,
                                      minHeight: 3,
                                      color: EthioColors.gold,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  const SizedBox(height: Sp.x1),
                                  Row(
                                    children: [
                                      Text(
                                        _playing ? '0:18' : '0:00',
                                        style: text.labelSmall?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _post.duration,
                                        style: text.labelSmall?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.x3),
                    Text(_post.title, style: text.titleLarge),
                    const SizedBox(height: Sp.x1),
                    Text(
                      '${_post.caption} · ${_post.views} views',
                      style: text.bodySmall?.copyWith(
                        color: pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Sp.x3),
                    Row(
                      children: [
                        _ActionChip(
                          icon: liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: '${liked ? 1 : 0}',
                          color: liked ? EthioColors.danger : null,
                          onTap: () {
                            setState(() {
                              if (!_liked.remove(likeKey)) _liked.add(likeKey);
                            });
                          },
                        ),
                        const SizedBox(width: Sp.x2),
                        _ActionChip(
                          icon: Icons.mode_comment_outlined,
                          label: '$commentCount',
                          onTap: _comment,
                        ),
                        const SizedBox(width: Sp.x2),
                        _ActionChip(
                          icon: Icons.ios_share_rounded,
                          label: 'Share',
                          onTap: _share,
                        ),
                      ],
                    ),
                    Divider(height: Sp.x6, color: pal.line),
                    Text('More from this channel', style: text.titleMedium),
                    const SizedBox(height: Sp.x2),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _channel.posts.length,
              itemBuilder: (context, index) {
                final post = _channel.posts[index];
                final selected = index == _postIndex;
                return Padding(
                  padding: Sp.screen.copyWith(bottom: Sp.x2),
                  child: Material(
                    color: selected
                        ? pal.chip
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: Rad.r14,
                    child: InkWell(
                      borderRadius: Rad.r14,
                      onTap: () => setState(() {
                        _postIndex = index;
                        _playing = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(Sp.x3),
                        decoration: BoxDecoration(
                          borderRadius: Rad.r14,
                          border: Border.all(color: pal.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _channel.accent.withValues(alpha: 0.16),
                                borderRadius: Rad.r10,
                              ),
                              child: const Icon(Icons.play_arrow_rounded),
                            ),
                            const SizedBox(width: Sp.x3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleMedium,
                                  ),
                                  Text(
                                    '${post.duration} · ${post.views} views',
                                    style: text.labelSmall?.copyWith(
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.equalizer_rounded,
                                color: EthioColors.goldDeep,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + Sp.x6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Rad.r14,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.x3,
          vertical: Sp.x2,
        ),
        decoration: BoxDecoration(
          color: pal.chip,
          borderRadius: Rad.r14,
          border: Border.all(color: pal.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Sp.x1),
            Text(label),
          ],
        ),
      ),
    );
  }
}
