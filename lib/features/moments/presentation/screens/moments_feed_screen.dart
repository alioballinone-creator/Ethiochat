import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// 11 — Moments feed.
///
/// Post cards from mutual friends: author, time, text, photo grid, likes and
/// comments. Scrollable on every screen size; no fixed heights.
class MomentsFeedScreen extends StatelessWidget {
  const MomentsFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Moments',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'New moment',
            icon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: EthioColors.goldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: EthioColors.black, size: 20),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: Sp.x2),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: EthioColors.gold,
          onRefresh: () async {},
          child: ListView.separated(
            padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
            itemCount: _posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: Sp.x4),
            itemBuilder: (context, index) => _MomentCard(post: _posts[index]),
          ),
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 2,
        onTap: (i) {
          if (i == 0) Navigator.pushNamed(context, '/chats');
          if (i == 1) Navigator.pushNamed(context, '/contacts');
          if (i == 3) Navigator.pushNamed(context, '/me');
        },
      ),
    );
  }
}

class _MomentPost {
  const _MomentPost({
    required this.author,
    required this.time,
    required this.text,
    this.photos = 0,
    this.likes = 0,
    this.comments = 0,
    this.location,
  });

  final String author;
  final String time;
  final String text;
  final int photos;
  final int likes;
  final int comments;
  final String? location;
}

const _posts = <_MomentPost>[
  _MomentPost(
    author: 'Tigist Alemayehu',
    time: '12 min ago',
    text: 'Morning coffee with the best view in Addis. ☕️',
    photos: 3,
    likes: 18,
    comments: 4,
    location: 'Entoto, Addis Ababa',
  ),
  _MomentPost(
    author: 'Abebe Kebede',
    time: '2 hours ago',
    text: 'Finally tried the new injera place near Bole. Highly recommended.',
    photos: 2,
    likes: 9,
    comments: 1,
    location: 'Bole, Addis Ababa',
  ),
  _MomentPost(
    author: 'EthioChat Team',
    time: 'Yesterday',
    text: 'Tips & tricks: hold the mic to record, slide up to lock. 🎙️',
    likes: 42,
    comments: 7,
  ),
];

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.post});

  final _MomentPost post;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r18,
        border: Border.all(color: pal.line),
      ),
      padding: const EdgeInsets.all(Sp.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EthioAvatar(name: post.author, size: 44),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.time,
                      style: text.labelSmall?.copyWith(color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: () {},
                icon: Icon(Icons.more_horiz_rounded, color: pal.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          Text(post.text, style: text.bodyLarge),
          if (post.photos > 0) ...[
            const SizedBox(height: Sp.x3),
            _PhotoGrid(count: post.photos),
          ],
          if (post.location != null) ...[
            const SizedBox(height: Sp.x3),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: pal.textSecondary),
                const SizedBox(width: Sp.x1),
                Flexible(
                  child: Text(
                    post.location!,
                    style: text.labelSmall?.copyWith(color: pal.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Sp.x3),
          Divider(color: pal.line, height: 1),
          const SizedBox(height: Sp.x1),
          Row(
            children: [
              _Action(
                icon: Icons.favorite_border_rounded,
                label: '${post.likes}',
                onTap: () {},
              ),
              _Action(
                icon: Icons.mode_comment_outlined,
                label: '${post.comments}',
                onTap: () {},
              ),
              const Spacer(),
              _Action(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(1, 9).toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = Sp.x1;
        final columns = shown == 1 ? 1 : (shown == 2 || shown == 4 ? 2 : 3);
        final rows = (shown / columns).ceil();
        final tile = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final height = tile * rows + gap * (rows - 1);

        return SizedBox(
          height: height,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
            ),
            itemCount: shown,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                borderRadius: Rad.r10,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EthioColors.avatarTones[index % EthioColors.avatarTones.length],
                    EthioColors.avatarTones[(index + 2) % EthioColors.avatarTones.length],
                  ],
                ),
              ),
              child: index == shown - 1 && count > 9
                  ? Center(child: Text('+${count - 9}'))
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: Rad.r10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: pal.textSecondary),
            const SizedBox(width: Sp.x1),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: pal.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
