import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/env.dart';

/// Sends queued messages to Supabase after uploading any local media.
///
/// Demo conversations (non-UUID ids) are local-only. A configured backend
/// without a session throws so queued work is retried instead of being dropped.
class SupabaseOutboxTransport {
  SupabaseOutboxTransport({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<void> send(Map<String, dynamic> payload) async {
    if (!Env.hasSupabase) return;
    final client = _supabase;
    if (client.auth.currentUser == null) {
      throw StateError('Sign in before sending queued work.');
    }

    final kind = payload['kind'] as String? ?? 'message';
    final messageId = payload['id'] as String?;
    final conversationId = payload['conversation_id'] as String?;
    if (conversationId == null ||
        !Uuid.isValidUUID(fromString: conversationId)) {
      throw const FormatException(
          'Queued work has an invalid conversation id.');
    }

    if (kind == 'read') {
      final seq = (payload['seq'] as num?)?.toInt() ?? 0;
      await client.rpc<dynamic>(
        'mark_conversation_read',
        params: {'p_conversation': conversationId, 'p_seq': seq},
      );
      return;
    }

    if (messageId == null || !Uuid.isValidUUID(fromString: messageId)) {
      throw const FormatException('Queued work has an invalid message id.');
    }

    if (kind == 'edit') {
      final body = payload['body'] as String?;
      if (body == null || body.trim().isEmpty) {
        throw const FormatException('Edited messages need text.');
      }
      await client.from('messages').update({'body': body}).eq('id', messageId);
      return;
    }

    if (kind == 'delete') {
      await client.from('messages').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'body': null,
        'media': null,
      }).eq('id', messageId);
      return;
    }

    final localMedia = payload['media'];
    var media = localMedia is Map
        ? Map<String, dynamic>.from(localMedia)
        : <String, dynamic>{};
    final localPath = media['path'] as String?;
    if (media['uploaded'] != true &&
        localPath != null &&
        localPath.isNotEmpty) {
      final file = File(localPath);
      if (!await file.exists()) {
        throw StateError('Media file is missing and must be reselected.');
      }
      var extension = p.extension(media['name'] as String? ?? localPath);
      if (extension.isEmpty) extension = p.extension(localPath);
      final storagePath = '$conversationId/$messageId$extension';
      // Storage uploads are atomic and this path is idempotent. If the network
      // drops, the outbox retries the upload from the still-present local file.
      await client.storage.from('media').upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: true,
            ),
          );
      media = {
        ...media,
        'bucket': 'media',
        'storage_path': storagePath,
        'uploaded': true,
      };
    }

    try {
      await client.rpc<dynamic>(
        'send_message',
        params: {
          'p_id': messageId,
          'p_conversation': conversationId,
          'p_type': payload['type'] as String? ?? 'text',
          'p_body': payload['body'] as String?,
          'p_media': media.isEmpty ? null : media,
          'p_reply_to': payload['reply_to'] as String?,
        },
      );
    } on PostgrestException catch (error) {
      // A lost response can make a retry hit the message primary key. Treat
      // that one unique violation as an idempotent success.
      if (error.code == '23505') return;
      rethrow;
    }
  }

  String _contentType(String extension) {
    return switch (extension.toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.m4a' => 'audio/mp4',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.amr' => 'audio/amr',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.heic' => 'image/heic',
      '.pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
