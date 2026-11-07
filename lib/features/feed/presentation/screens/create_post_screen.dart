import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';
import '../post_upload_utils.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int maxChars = 500;
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  String _visibility = 'public';
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.clear();
        _images.addAll(picked.take(4));
      });
    }
  }

  Future<Uint8List> _compress(Uint8List bytes) async {
    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1080,
      minHeight: 1080,
      quality: 80,
      format: CompressFormat.jpeg,
    );
  }

  Future<void> _rollback(SupabaseClient client, String? postId,
      List<String> uploadedPaths) async {
    for (final p in uploadedPaths) {
      try {
        await client.storage.from('posts').remove([p]);
      } catch (_) {}
    }
    if (postId != null) {
      try {
        await client.from('posts').delete().eq('id', postId);
      } catch (_) {}
    }
  }

  Future<void> _submit() async {
    if (_posting) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text or at least one image.')),
      );
      return;
    }
    setState(() => _posting = true);
    final client = Supabase.instance.client;
    String? postId;
    final uploadedPaths = <String>[];
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');
      final postRes = await client
          .from('posts')
          .insert({
            'author_id': userId,
            'body': text,
            'visibility': _visibility,
          })
          .select('id')
          .single();
      postId = postRes['id']?.toString();

      for (final img in _images) {
        final bytes = await img.readAsBytes();
        final compressed = await _compress(bytes);
        final path = PostUploadSpec.newObjectPath(userId);
        await client.storage.from('posts').uploadBinary(
              path,
              compressed,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        uploadedPaths.add(path);
        // Use signed URL for private bucket; store path for resolution.
        final signed = await client.storage
            .from('posts')
            .createSignedUrl(path, 60 * 60 * 24 * 7);
        await client.from('post_media').insert({
          'post_id': postId,
          'media_url': signed,
          'media_type': 'image',
          'storage_path': path,
        });
      }
      if (mounted) context.pop(true);
    } catch (e) {
      await _rollback(client, postId, uploadedPaths);
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to create post. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create post'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _submit,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
      body: Padding(
        padding: Sp.screen,
        child: ListView(
          children: [
            TextField(
              controller: _controller,
              maxLength: maxChars,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                counterText: '',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_controller.text.characters.length}/$maxChars',
                key: const Key('create-post-char-counter'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Sp.x3),
            DropdownButtonFormField<String>(
              key: const Key('create-post-visibility'),
              value: _visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(
                    value: 'followers', child: Text('Followers')),
              ],
              onChanged: _posting
                  ? null
                  : (v) {
                      if (v != null) setState(() => _visibility = v);
                    },
            ),
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [
                for (final img in _images)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(img.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_images.length < 4)
                  OutlinedButton.icon(
                    key: const Key('create-post-add-image'),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Add images'),
                    onPressed: _posting ? null : _pickImages,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
