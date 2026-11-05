import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
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
      if (!_loading && _hasMore) {
        _loadPosts(loadMore: true);
      }
    }
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _loading = true;
        _offset = 0;
        _posts = [];
      });
    } else {
      setState(() => _loading = true);
    }

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      // Get blocked users
      final blocked = <String>{};
      if (userId != null) {
        final blocks = await client
            .from('blocks')
            .select('blocked_id')
            .eq('owner_id', userId);
        for (final b in blocks) {
          blocked.add(b['blocked_id'].toString());
        }
      }
      var query = client
          .from('posts')
          .select(
              '*, post_media(*), profiles!posts_author_id_fkey(display_name, avatar_url)')
          .isFilter('deleted_at', null)
          .eq('is_hidden', false)
          .order('created_at', ascending: false)
          .range(loadMore ? _offset : 0, (loadMore ? _offset : 0) + 19);
      final res = await query;
      final items = <Map<String, dynamic>>[];
      for (final item in res) {
        final authorId = item['author_id']?.toString();
        if (authorId != null && blocked.contains(authorId)) continue;
        items.add(item);
      }
      setState(() {
        if (loadMore) {
          _posts.addAll(items);
          _offset += items.length;
        } else {
          _posts = items;
          _offset = items.length;
        }
        _hasMore = items.length >= 20;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load feed. Please try again.')),
        );
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
      _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to update reaction. Please try again.')),
        );
      }
    }
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
            onPressed: () => context.push('/feed/create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPosts(),
        child: ListView.builder(
          controller: _scrollController,
          padding: Sp.screen,
          itemCount: _posts.length + 1,
          itemBuilder: (context, index) {
            if (index == _posts.length) {
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(Sp.x4),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const SizedBox.shrink();
            }
            final post = _posts[index];
            final media = (post['post_media'] as List?) ?? const [];
            final profiles = post['profiles'] as Map<String, dynamic>?;
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
                            name: (profiles?['display_name'] as String?) ?? 'User',
                            size: 40),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((profiles?['display_name'] as String?) ?? 'User',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              Text(post['created_at']?.toString() ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: pal.textSecondary)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            final messenger = ScaffoldMessenger.of(context);
                            final client = Supabase.instance.client;
                            final userId = client.auth.currentUser?.id;
                            if (v == 'report' && userId != null) {
                              await client.from('reports').insert({
                                'reporter_id': userId,
                                'target_type': 'moment',
                                'target_id': post['id'],
                                'reason': 'inappropriate',
                              });
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Report submitted')),
                              );
                            } else if (v == 'block' &&
                                post['author_id'] != null &&
                                userId != null) {
                              await client.from('blocks').insert({
                                'owner_id': userId,
                                'blocked_id': post['author_id'],
                              });
                              if (mounted) _loadPosts();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'report', child: Text('Report post')),
                            const PopupMenuItem(
                                value: 'block', child: Text('Block user')),
                          ],
                        ),
                      ],
                    ),
                    if (post['body'] != null &&
                        post['body'].toString().isNotEmpty) ...[
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
                                ((m as Map<String, dynamic>)['media_url'] as String?) ?? '',
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
                          onPressed: () => _toggleLike(post['id']),
                        ),
                        Text('${post['like_count'] ?? 0}'),
                        const SizedBox(width: Sp.x3),
                        IconButton(
                          icon: const Icon(Icons.comment_outlined),
                          onPressed: () =>
                              context.push('/feed/post/${post['id']}'),
                        ),
                        Text('${post['comment_count'] ?? 0}'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () {
                            // Use share sheet - simple placeholder
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
