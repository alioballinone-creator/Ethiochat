import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design/design.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
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
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _images.clear();
        _images.addAll(picked.take(4));
      });
    }
  }

  Future<Uint8List> _compress(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1080,
      minHeight: 1080,
      quality: 80,
    );
    return result;
  }

  Future<void> _submit() async {
    if (_posting) return;
    setState(() => _posting = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');
      final postRes = await client.from('posts').insert({
        'author_id': userId,
        'body': _controller.text.trim(),
        'visibility': _visibility,
      }).select().single();
      final postId = postRes['id'];

      for (final img in _images) {
        final bytes = await img.readAsBytes();
        final compressed = await _compress(bytes);
        final fileName = const Uuid().v4() + p.extension(img.name);
        final path = '$userId/$fileName';
        await client.storage.from('posts').uploadBinary(path, compressed,
            fileOptions: const FileOptions(contentType: 'image/jpeg'));
        final url = client.storage.from('posts').getPublicUrl(path);
        await client.from('post_media').insert({
          'post_id': postId,
          'media_url': url,
          'media_type': 'image',
          'storage_path': path,
        });
      }
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create post. Please try again.')),
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
            child: const Text('Post'),
          ),
        ],
      ),
      body: Padding(
        padding: Sp.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLength: 500,
              maxLines: 5,
              decoration: const InputDecoration(hintText: "What's on your mind?"),
            ),
            const SizedBox(height: Sp.x3),
            DropdownButton<String>(
              value: _visibility,
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'followers', child: Text('Followers')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _visibility = v);
              },
            ),
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
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
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _images.length >= 4 ? null : _pickImages,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
