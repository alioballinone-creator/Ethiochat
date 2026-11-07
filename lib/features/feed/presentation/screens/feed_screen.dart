import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';
import '../feed_utils.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _offline = false;
  String? _error;
  int _offset = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore) _loadPosts(loadMore: true);
    }
  }

  Future<bool> _isOffline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.none) ||
          (r.isNotEmpty && r.every((e) => e == ConnectivityResult.none));
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    final offline = await _isOffline();
    if (offline) {
      if (mounted) {
        setState(() {
          _offline = true;
          _loading = false;
          _loadingMore = false;
          if (!loadMore && _posts.isEmpty) _error = 'You are offline.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _offline = false;
        _error = null;
        if (loadMore) {
          _loadingMore = true;
        } else {
          _loading = true;
          _offset = 0;
        }
      });
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final blocked = <String>{};
      if (userId != null) {
        try {
          final blocks = await client
              .from('blocks')
              .select('blocked_id')
              .eq('owner_id', userId);
          for (final b in (blocks as List)) {
            blocked.add(b['blocked_id'].toString());
          }
        } catch (_) {}
      }
      final start = loadMore ? _offset : 0;
      final res = await client
          .from('posts')
          .select(
              '*, post_media(*), profiles!posts_author_id_fkey(display_name, avatar_url)')
          .filter('deleted_at', 'is', null)
          .eq('is_hidden', false)
          .order('created_at', ascending: false)
          .range(start, start + 19);
      final items = <Map<String, dynamic>>[];
      for (final item in (res as List)) {
        final map = Map<String, dynamic>.from(item as Map);
        final authorId = map['author_id']?.toString();
        if (authorId != null && blocked.contains(authorId)) continue;
        final media = (map['post_media'] as List?) ?? const [];
        final resolved = <Map<String, dynamic>>[];
        for (final m in media) {
          final mm = Map<String, dynamic>.from(m as Map);
          mm['resolved_url'] =
              await FeedUtils.resolveMediaUrl(client, mm, expiresIn: 3600);
          resolved.add(mm);
        }
        map['post_media'] = resolved;
        items.add(map);
      }
      if (mounted) {
        setState(() {
          if (loadMore) {
            _posts = [..._posts, ...items];
          } else {
            _posts = items;
          }
          _offset = (loadMore ? _offset : 0) + items.length;
          _hasMore = items.length >= 20;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = 'Failed to load feed. Please try again.';
        });
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final existing = await client
          .from('post_reactions')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) {
        await client
            .from('post_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await client.from('post_reactions').insert(
            {'post_id': postId, 'user_id': userId, 'reaction_type': 'like'});
      }
      await _loadPosts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to update reaction. Please try again.')),
        );
      }
    }
  }

  Future<void> _reportPost(String postId) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('reports').insert({
        'reporter_id': userId,
        'target_type': 'post',
        'target_id': postId,
        'reason': 'inappropriate',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted')),
        );
      }
    } catch (_) {}
  }

  Future<void> _blockAuthor(String authorId) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('blocks').upsert({
        'owner_id': userId,
        'blocked_id': authorId,
      }, onConflict: 'owner_id,blocked_id');
      if (mounted) _loadPosts();
    } catch (_) {}
  }

  Widget _stateView(IconData icon, String message,
      {bool retry = false, Key? key}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(Sp.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: Sp.x3),
            Text(message, textAlign: TextAlign.center),
            if (retry) ...[
              const SizedBox(height: Sp.x3),
              FilledButton(
                  onPressed: () => _loadPosts(), child: const Text('Retry')),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await context.push('/feed/create');
              if (created == true) _loadPosts();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPosts(),
        child: Builder(builder: (context) {
          if (_loading && _posts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && _posts.isEmpty) {
            return ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              _stateView(
                  _offline ? Icons.wifi_off_rounded : Icons.error_outline,
                  _error!,
                  retry: true,
                  key: const Key('feed-error-state')),
            ]);
          }
          if (_posts.isEmpty) {
            return ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              _stateView(Icons.dynamic_feed_outlined,
                  'No posts yet. Follow people or share something.',
                  key: const Key('feed-empty-state')),
            ]);
          }
          return ListView.builder(
            controller: _scrollController,
            padding: Sp.screen,
            itemCount: _posts.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(Sp.x4),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final post = _posts[index];
              final media = (post['post_media'] as List?) ?? const [];
              final profiles = post['profiles'] as Map<String, dynamic>?;
              final authorId = post['author_id']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: Sp.x4),
                child: Padding(
                  padding: const EdgeInsets.all(Sp.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          EthioAvatar(
                              name: (profiles?['display_name'] as String?) ??
                                  'User',
                              size: 40),
                          const SizedBox(width: Sp.x3),
                          Expanded(
                            child: Text(
                                (profiles?['display_name'] as String?) ??
                                    'User',
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'report') {
                                await _reportPost(post['id'].toString());
                              } else if (v == 'block' && authorId != null) {
                                await _blockAuthor(authorId);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                  value: 'report', child: Text('Report post')),
                              PopupMenuItem(
                                  value: 'block', child: Text('Block user')),
                            ],
                          ),
                        ],
                      ),
                      if ((post['body'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: Sp.x3),
                        Text(post['body'].toString()),
                      ],
                      if (media.isNotEmpty) ...[
                        const SizedBox(height: Sp.x3),
                        Wrap(
                          spacing: Sp.x2,
                          runSpacing: Sp.x2,
                          children: [
                            for (final m in media.take(4))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  ((m as Map)['resolved_url'] as String?) ?? '',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 150,
                                    height: 150,
                                    color: pal.surface2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: Sp.x3),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () => _toggleLike(post['id'].toString()),
                          ),
                          Text('${post['like_count'] ?? 0}'),
                          const SizedBox(width: Sp.x3),
                          IconButton(
                            icon: const Icon(Icons.comment_outlined),
                            onPressed: () async {
                              await context.push('/feed/post/${post['id']}');
                              _loadPosts();
                            },
                          ),
                          Text('${post['comment_count'] ?? 0}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => FeedUtils.sharePost(post),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
