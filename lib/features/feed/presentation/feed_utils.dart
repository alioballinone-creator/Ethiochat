import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedUtils {
  static Future<String> resolveMediaUrl(
    SupabaseClient client,
    Map<String, dynamic> media, {
    int expiresIn = 3600,
  }) async {
    final path = media['storage_path']?.toString();
    if (path != null && path.isNotEmpty) {
      try {
        return await client.storage
            .from('posts')
            .createSignedUrl(path, expiresIn);
      } catch (_) {}
    }
    return media['media_url']?.toString() ?? '';
  }

  static Future<void> sharePost(Map<String, dynamic> post) async {
    final body = (post['body'] ?? '').toString().trim();
    final text = body.isEmpty
        ? 'Check out this post on EthioChat'
        : '$body\n\n— EthioChat';
    await Share.share(text);
  }
}
