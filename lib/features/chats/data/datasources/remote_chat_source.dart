import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteConversation {
  const RemoteConversation({
    required this.id,
    required this.type,
    this.title,
    this.avatarUrl,
    this.lastMessageId,
    this.lastMessageAt,
    this.updatedAt,
  });

  factory RemoteConversation.fromMap(Map<String, dynamic> map) {
    return RemoteConversation(
      id: map['id'] as String,
      type: map['type'] as String? ?? 'direct',
      title: map['title'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      lastMessageId: map['last_message_id'] as String?,
      lastMessageAt: _date(map['last_message_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  final String id;
  final String type;
  final String? title;
  final String? avatarUrl;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final DateTime? updatedAt;
}

class RemoteMember {
  const RemoteMember({
    required this.conversationId,
    required this.userId,
    required this.role,
    this.joinedAt,
  });

  factory RemoteMember.fromMap(Map<String, dynamic> map) {
    return RemoteMember(
      conversationId: map['conversation_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'member',
      joinedAt: _date(map['joined_at']),
    );
  }

  final String conversationId;
  final String userId;
  final String role;
  final DateTime? joinedAt;
}

class RemoteProfile {
  const RemoteProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
  });

  factory RemoteProfile.fromMap(Map<String, dynamic> map) {
    return RemoteProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  final String id;
  final String? displayName;
  final String? avatarUrl;
}

class RemoteMessage {
  const RemoteMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.seq,
    this.body,
    this.media,
    this.replyTo,
    this.editedAt,
    this.deletedAt,
  });

  factory RemoteMessage.fromMap(Map<String, dynamic> map) {
    final rawMedia = map['media'];
    return RemoteMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      type: map['type'] as String? ?? 'text',
      seq: (map['seq'] as num?)?.toInt(),
      body: map['body'] as String?,
      media: rawMedia is Map ? Map<String, dynamic>.from(rawMedia) : null,
      replyTo: map['reply_to'] as String?,
      editedAt: _date(map['edited_at']),
      deletedAt: _date(map['deleted_at']),
      createdAt: _date(map['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final int? seq;
  final String? body;
  final Map<String, dynamic>? media;
  final String? replyTo;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;

  bool get isDeleted => deletedAt != null;
}

class RemoteReceipt {
  const RemoteReceipt({
    required this.messageId,
    required this.userId,
    this.deliveredAt,
    this.readAt,
  });

  factory RemoteReceipt.fromMap(Map<String, dynamic> map) {
    return RemoteReceipt(
      messageId: map['message_id'] as String,
      userId: map['user_id'] as String,
      deliveredAt: _date(map['delivered_at']),
      readAt: _date(map['read_at']),
    );
  }

  final String messageId;
  final String userId;
  final DateTime? deliveredAt;
  final DateTime? readAt;
}

abstract interface class RemoteChatSource {
  Future<List<RemoteConversation>> fetchConversations({int limit = 50});

  Future<List<RemoteMember>> fetchMembers(List<String> conversationIds);

  Future<List<RemoteProfile>> fetchProfiles(Set<String> userIds);

  Future<List<RemoteMessage>> fetchMessages(
    String conversationId, {
    int limit = 50,
    int? beforeSeq,
  });

  Future<List<RemoteReceipt>> fetchReceipts(List<String> messageIds);

  Future<Map<String, String>> signedMediaUrls(Iterable<String> paths);

  void subscribe({
    required void Function(RemoteMessage message) onMessage,
    void Function(RemoteMessage message)? onMessageUpdated,
    void Function(RemoteReceipt receipt)? onReceipt,
    void Function(RemoteConversation conversation)? onConversation,
    void Function(Object error, StackTrace stackTrace)? onError,
  });

  Future<void> dispose();
}

/// Supabase-backed remote source used by the chat sync service.
///
/// Every query relies on the authenticated user's RLS policies. Private media
/// is exposed through short-lived signed URLs rather than public bucket URLs.
class SupabaseRemoteChatSource implements RemoteChatSource {
  SupabaseRemoteChatSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  @override
  Future<List<RemoteConversation>> fetchConversations({int limit = 50}) async {
    final rows = await _client
        .from('conversations')
        .select(
          'id,type,title,avatar_url,last_message_id,last_message_at,updated_at',
        )
        .isFilter('deleted_at', null)
        .order('last_message_at', ascending: false, nullsFirst: false)
        .limit(limit);
    return rows
        .map((row) => RemoteConversation.fromMap(row))
        .toList(growable: false);
  }

  @override
  Future<List<RemoteMember>> fetchMembers(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) return const [];
    final rows = await _client
        .from('conversation_members')
        .select('conversation_id,user_id,role,joined_at')
        .inFilter('conversation_id', conversationIds)
        .isFilter('left_at', null);
    return rows.map((row) => RemoteMember.fromMap(row)).toList(growable: false);
  }

  @override
  Future<List<RemoteProfile>> fetchProfiles(Set<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final rows = await _client
        .from('profiles')
        .select('id,display_name,avatar_url')
        .inFilter('id', userIds.toList(growable: false));
    return rows
        .map((row) => RemoteProfile.fromMap(row))
        .toList(growable: false);
  }

  @override
  Future<List<RemoteMessage>> fetchMessages(
    String conversationId, {
    int limit = 50,
    int? beforeSeq,
  }) async {
    var query = _client
        .from('messages')
        .select(
          'id,conversation_id,sender_id,seq,type,body,media,reply_to,'
          'edited_at,deleted_at,created_at',
        )
        .eq('conversation_id', conversationId);
    if (beforeSeq != null) {
      query = query.lt('seq', beforeSeq);
    }
    final rows = await query.order('seq', ascending: false).limit(limit);
    return rows
        .map((row) => RemoteMessage.fromMap(row))
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  @override
  Future<List<RemoteReceipt>> fetchReceipts(List<String> messageIds) async {
    if (messageIds.isEmpty) return const [];
    final rows = await _client
        .from('message_receipts')
        .select('message_id,user_id,delivered_at,read_at')
        .inFilter('message_id', messageIds)
        .limit(5000);
    return rows
        .map((row) => RemoteReceipt.fromMap(row))
        .toList(growable: false);
  }

  @override
  Future<Map<String, String>> signedMediaUrls(
    Iterable<String> paths,
  ) async {
    final unique = paths
        .where((path) => path.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (unique.isEmpty) return const {};
    final results = await _client.storage
        .from('media')
        .createSignedUrlsResult(unique, 604800);
    return {
      for (final result in results)
        if (result is SignedUrlSuccess) result.path: result.signedUrl,
    };
  }

  @override
  void subscribe({
    required void Function(RemoteMessage message) onMessage,
    void Function(RemoteMessage message)? onMessageUpdated,
    void Function(RemoteReceipt receipt)? onReceipt,
    void Function(RemoteConversation conversation)? onConversation,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    if (_channel != null) return;
    final channel = _client.channel('ethiochat-chat-sync');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        try {
          onMessage(RemoteMessage.fromMap(payload.newRecord));
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
        }
      },
    );
    if (onMessageUpdated != null) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          try {
            onMessageUpdated(RemoteMessage.fromMap(payload.newRecord));
          } catch (error, stackTrace) {
            onError?.call(error, stackTrace);
          }
        },
      );
    }
    if (onReceipt != null) {
      for (final event in [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]) {
        channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'message_receipts',
          callback: (payload) {
            try {
              onReceipt(RemoteReceipt.fromMap(payload.newRecord));
            } catch (error, stackTrace) {
              onError?.call(error, stackTrace);
            }
          },
        );
      }
    }
    if (onConversation != null) {
      for (final event in [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]) {
        channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            try {
              onConversation(RemoteConversation.fromMap(payload.newRecord));
            } catch (error, stackTrace) {
              onError?.call(error, stackTrace);
            }
          },
        );
      }
    }
    _channel = channel.subscribe((status, error) {
      if (error != null) onError?.call(error, StackTrace.current);
    });
  }

  @override
  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
  }
}

DateTime? _date(Object? value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is DateTime) return value.toLocal();
  return null;
}
