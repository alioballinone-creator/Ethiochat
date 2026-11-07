import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';
import '../feed_utils.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _media = [];
  final _commentCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final post = await client
          .from('posts')
          .select(
              '*, post_media(*), profiles!posts_author_id_fkey(display_name, avatar_url)')
          .eq('id', widget.postId)
          .maybeSingle();
      final comments = await client
          .from('post_comments')
          .select(
              '*, profiles!post_comments_author_id_fkey(display_name, avatar_url)')
          .eq('post_id', widget.postId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: true);
      final media = <Map<String, dynamic>>[];
      for (final m in ((post?['post_media'] as List?) ?? const [])) {
        final mm = Map<String, dynamic>.from(m as Map);
        mm['resolved_url'] =
            await FeedUtils.resolveMediaUrl(client, mm, expiresIn: 3600);
        media.add(mm);
      }
      if (mounted) {
        setState(() {
          _post = post == null ? null : Map<String, dynamic>.from(post);
          _media = media;
          _comments = [
            for (final c in (comments as List))
              Map<String, dynamic>.from(c as Map)
          ];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final existing = await client
          .from('post_reactions')
          .select()
          .eq('post_id', widget.postId)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) {
        await client
            .from('post_reactions')
            .delete()
            .eq('post_id', widget.postId)
            .eq('user_id', userId);
      } else {
        await client.from('post_reactions').insert({
          'post_id': widget.postId,
          'user_id': userId,
          'reaction_type': 'like'
        });
      }
      _load();
    } catch (_) {}
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('post_comments').insert({
        'post_id': widget.postId,
        'author_id': userId,
        'body': text,
      });
      _commentCtrl.clear();
      _load();
    } catch (_) {}
  }

  Future<void> _editPost() async {
    final current = (_post?['body'] ?? '').toString();
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(controller: ctrl, maxLength: 500, maxLines: 4),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.from('posts').update({
        'body': ctrl.text.trim(),
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.postId);
      _load();
    }
  }

  Future<void> _deletePost() async {
    await Supabase.instance.client
        .from('posts')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq(
            'id', widget.postId);
    if (mounted) context.pop();
  }

  Future<void> _editComment(Map<String, dynamic> c) async {
    final ctrl = TextEditingController(text: (c['body'] ?? '').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(controller: ctrl, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.from('post_comments').update({
        'body': ctrl.text.trim(),
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', c['id']);
      _load();
    }
  }

  Future<void> _deleteComment(String id) async {
    await Supabase.instance.client.from('post_comments').update(
        {'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    final isOwner = post != null && post['author_id'] == me;
    final profiles = post?['profiles'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (post != null)
            IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => FeedUtils.sharePost(post)),
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editPost();
                if (v == 'delete') _deletePost();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : post == null
              ? const Center(child: Text('Post not found'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: Sp.screen,
                        children: [
                          Row(children: [
                            EthioAvatar(
                                name: (profiles?['display_name'] as String?) ??
                                    'User',
                                size: 40),
                            const SizedBox(width: Sp.x3),
                            Text((profiles?['display_name'] as String?) ??
                                'User'),
                          ]),
                          if ((post['body'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: Sp.x3),
                            Text(post['body'].toString()),
                          ],
                          if (_media.isNotEmpty) ...[
                            const SizedBox(height: Sp.x3),
                            for (final m in _media)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Sp.x2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                      m['resolved_url']?.toString() ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(height: 120)),
                                ),
                              ),
                          ],
                          const SizedBox(height: Sp.x3),
                          Row(children: [
                            IconButton(
                                icon: const Icon(Icons.favorite_border),
                                onPressed: _toggleLike),
                            Text('${post['like_count'] ?? 0}'),
                          ]),
                          const Divider(),
                          Text('Comments (${_comments.length})',
                              style: Theme.of(context).textTheme.titleSmall),
                          for (final c in _comments)
                            Builder(builder: (context) {
                              final cProfiles =
                                  c['profiles'] as Map<String, dynamic>?;
                              final own = c['author_id'] == me;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: EthioAvatar(
                                    name: (cProfiles?['display_name']
                                            as String?) ??
                                        'User',
                                    size: 32),
                                title: Text(
                                    (cProfiles?['display_name'] as String?) ??
                                        'User'),
                                subtitle: Text(c['body']?.toString() ?? ''),
                                trailing: own
                                    ? PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') _editComment(c);
                                          if (v == 'delete')
                                            _deleteComment(c['id'].toString());
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'))
                                        ],
                                      )
                                    : null,
                              );
                            }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                          left: Sp.x4,
                          right: Sp.x4,
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom + Sp.x2,
                          top: Sp.x2),
                      child: Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _commentCtrl,
                                decoration: const InputDecoration(
                                    hintText: 'Add a comment...'))),
                        IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _addComment),
                      ]),
                    ),
                  ],
                ),
    );
  }
}
