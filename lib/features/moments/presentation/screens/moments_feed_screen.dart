import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// 11 — Moments feed.
///
/// Post cards from mutual friends: author, time, text, photo grid, likes and
/// comments. Likes and comments update immediately; new posts appear at the
/// top of the feed.
class MomentsFeedScreen extends StatefulWidget {
  const MomentsFeedScreen({super.key});

  @override
  State<MomentsFeedScreen> createState() => _MomentsFeedScreenState();
}

class _MomentsFeedScreenState extends State<MomentsFeedScreen> {
  late final List<_MomentPost> _posts = List<_MomentPost>.of(_seedPosts);
  final Set<_MomentPost> _liked = <_MomentPost>{};
  final Map<_MomentPost, List<String>> _comments =
      <_MomentPost, List<String>>{};

  void _toggleLike(_MomentPost post) {
    setState(() {
      if (_liked.remove(post)) {
        post.likes--;
      } else {
        _liked.add(post);
        post.likes++;
      }
    });
  }

  Future<void> _comment(_MomentPost post) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final comments = _comments.putIfAbsent(post, () => <String>[]);
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
                        Text(
                          '${post.comments}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Sp.x6),
                      child: Text(
                        'No comments yet. Be the first to reply.',
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
                              leading: const EthioAvatar(name: 'You', size: 32),
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
                            hint: 'Write a comment',
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
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() {
                              comments.add(text);
                              post.comments++;
                            });
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

  Future<void> _share(_MomentPost post) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy post text'),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Send in a chat'),
              onTap: () => Navigator.pop(sheetContext, 'chat'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share to another app'),
              onTap: () => Navigator.pop(sheetContext, 'system'),
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    if (target == 'chat') {
      context.push('/new-chat');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          target == 'copy'
              ? 'Post text copied to clipboard.'
              : 'Opening the system share sheet…',
        ),
      ),
    );
    if (target == 'copy') {
      await Clipboard.setData(ClipboardData(text: post.text));
    }
  }

  Future<void> _newMoment() async {
    final controller = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New moment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 240,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Share something with your friends…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length < 2) return;
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (created == null || !mounted) {
      controller.dispose();
      return;
    }
    controller.dispose();
    setState(() {
      _posts.insert(
        0,
        _MomentPost(
          author: 'You',
          time: 'Just now',
          text: created,
          isMine: true,
        ),
      );
    });
  }

  void _more(_MomentPost post) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: post.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post text copied.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide this moment'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _posts.remove(post));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Moment hidden from your feed.')),
                );
              },
            ),
            if (post.isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: EthioColors.danger,
                ),
                title: const Text(
                  'Delete moment',
                  style: TextStyle(color: EthioColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _posts.remove(post));
                },
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
  }

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
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: EthioColors.black,
                size: 20,
              ),
            ),
            onPressed: _newMoment,
          ),
          const SizedBox(width: Sp.x2),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: EthioColors.gold,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (mounted) setState(() {});
          },
          child: _posts.isEmpty
              ? ListView(
                  padding: Sp.screen,
                  children: [
                    const SizedBox(height: Sp.x10),
                    Icon(
                      Icons.photo_library_outlined,
                      size: 44,
                      color: EthioPalette.of(context).textTertiary,
                    ),
                    const SizedBox(height: Sp.x3),
                    Center(
                      child: Text(
                        'No moments yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: Sp.x1),
                    Center(
                      child: Text(
                        'Share a photo or a thought with your friends.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Sp.x4),
                    Center(
                      child: EthioButton(
                        label: 'New moment',
                        expand: false,
                        onPressed: _newMoment,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Sp.x4),
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return _MomentCard(
                      post: post,
                      liked: _liked.contains(post),
                      onLike: () => _toggleLike(post),
                      onComment: () => _comment(post),
                      onShare: () => _share(post),
                      onMore: () => _more(post),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _MomentPost {
  _MomentPost({
    required this.author,
    required this.time,
    required this.text,
    this.photos = 0,
    this.likes = 0,
    this.comments = 0,
    this.location,
    this.isMine = false,
  });

  final String author;
  final String time;
  final String text;
  final int photos;
  int likes;
  int comments;
  final String? location;
  final bool isMine;
}

final _seedPosts = <_MomentPost>[
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
  const _MomentCard({
    required this.post,
    required this.liked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  final _MomentPost post;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

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
                      style:
                          text.labelSmall?.copyWith(color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: onMore,
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
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likes}',
                color: liked ? EthioColors.danger : null,
                onTap: onLike,
              ),
              _Action(
                icon: Icons.mode_comment_outlined,
                label: '${post.comments}',
                onTap: onComment,
              ),
              const Spacer(),
              _Action(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: onShare,
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
                    EthioColors
                        .avatarTones[index % EthioColors.avatarTones.length],
                    EthioColors.avatarTones[
                        (index + 2) % EthioColors.avatarTones.length],
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
  const _Action({
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
      borderRadius: Rad.r10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color ?? pal.textSecondary),
            const SizedBox(width: Sp.x1),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color ?? pal.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
