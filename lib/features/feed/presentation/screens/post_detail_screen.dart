import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
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
          .select('*, post_media(*), profiles!posts_author_id_fkey(display_name, avatar_url)')
          .eq('id', widget.postId)
          .maybeSingle();
      final comments = await client
          .from('post_comments')
          .select('*, profiles!post_comments_author_id_fkey(display_name, avatar_url)')
          .eq('post_id', widget.postId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _post = post;
          _comments = List<Map<String, dynamic>>.from(comments);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load post. Please try again.')),
        );
      }
    }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add comment. Please try again.')),
        );
      }
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
        await client.from('post_reactions').delete().eq('post_id', widget.postId).eq('user_id', userId);
      } else {
        await client.from('post_reactions').insert({'post_id': widget.postId, 'user_id': userId, 'reaction_type': 'like'});
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update reaction. Please try again.')),
        );
      }
    }
  }

  Future<void> _share() async {
    try {
      await Share.share('Check out this post on EthioChat');
    } catch (_) {}
  }

  Future<void> _deletePost() async {
    try {
      final client = Supabase.instance.client;
      await client.from('posts').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', widget.postId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete post. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final post = _post;
    final client = Supabase.instance.client;
    final isOwner = post != null && post['author_id'] == client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _deletePost();
              },
              itemBuilder: (context) => const [
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
                          Row(
                            children: [
                              EthioAvatar(name: post['profiles']?['display_name'] ?? 'User', size: 40),
                              const SizedBox(width: Sp.x3),
                              Text(post['profiles']?['display_name'] ?? 'User'),
                            ],
                          ),
                          if (post['body'] != null && post['body'].toString().isNotEmpty) ...[
                            const SizedBox(height: Sp.x3),
                            Text(post['body'].toString()),
                          ],
                          const SizedBox(height: Sp.x3),
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.favorite_border), onPressed: _toggleLike),
                              Text('${post['like_count'] ?? 0}'),
                              IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
                            ],
                          ),
                          const Divider(),
                          Text('Comments (${_comments.length})', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: Sp.x2),
                          for (final c in _comments)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: EthioAvatar(name: c['profiles']?['display_name'] ?? 'User', size: 32),
                              title: Text(c['profiles']?['display_name'] ?? 'User'),
                              subtitle: Text(c['body']?.toString() ?? ''),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: Sp.x4,
                        right: Sp.x4,
                        bottom: MediaQuery.of(context).viewInsets.bottom + Sp.x2,
                        top: Sp.x2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentCtrl,
                              decoration: const InputDecoration(hintText: 'Add a comment...'),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.send), onPressed: _addComment),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
