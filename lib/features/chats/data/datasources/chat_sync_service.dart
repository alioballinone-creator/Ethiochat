import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import 'remote_chat_source.dart';

class ChatSyncReport {
  const ChatSyncReport({
    this.conversations = 0,
    this.messages = 0,
    this.mediaUrls = 0,
  });

  final int conversations;
  final int messages;
  final int mediaUrls;
}

/// Pulls RLS-scoped conversations and messages into the local Drift database.
///
/// The local database remains the UI's source of truth. Remote ids are merged
/// without resetting local pin, mute, archive, read or delete-for-me state.
class ChatSyncService {
  ChatSyncService({
    required this.db,
    required this.source,
    required this.currentUserId,
    this.conversationLimit = 50,
    this.messageLimit = 50,
  });

  final AppDatabase db;
  final RemoteChatSource source;
  final String currentUserId;
  final int conversationLimit;
  final int messageLimit;

  bool _syncing = false;

  Future<ChatSyncReport> sync({bool refreshMessages = false}) async {
    if (_syncing) return const ChatSyncReport();
    _syncing = true;
    try {
      final conversations =
          await source.fetchConversations(limit: conversationLimit);
      if (conversations.isEmpty) return const ChatSyncReport();

      final conversationIds = conversations
          .map((conversation) => conversation.id)
          .toList(growable: false);
      final members = await source.fetchMembers(conversationIds);
      final memberIds = members
          .map((member) => member.userId)
          .where((id) => id != currentUserId)
          .toSet();
      final profiles = await source.fetchProfiles(memberIds);
      final profilesById = {
        for (final profile in profiles) profile.id: profile,
      };

      final localById = await _existingConversations(conversationIds);
      final needsMessages = conversations.where((conversation) {
        if (refreshMessages) return true;
        final local = localById[conversation.id];
        if (local == null || local.syncedAt == null) return true;
        if (conversation.lastMessageId != null &&
            conversation.lastMessageId != local.lastMessageId) {
          return true;
        }
        final remoteAt = conversation.lastMessageAt;
        return remoteAt != null && remoteAt.isAfter(local.syncedAt!);
      }).toList(growable: false);

      final messagesByConversation = <String, List<RemoteMessage>>{};
      for (final conversation in needsMessages) {
        messagesByConversation[conversation.id] = await source.fetchMessages(
          conversation.id,
          limit: messageLimit,
        );
      }

      final mediaPaths = <String>{
        for (final messages in messagesByConversation.values)
          for (final message in messages)
            if (message.media?['storage_path'] is String)
              message.media!['storage_path'] as String,
      };
      var signedUrls = const <String, String>{};
      if (mediaPaths.isNotEmpty) {
        try {
          signedUrls = await source.signedMediaUrls(mediaPaths);
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Could not refresh chat media URLs',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      var importedMessages = 0;
      final syncedAt = DateTime.now();
      await db.transaction(() async {
        for (final conversation in conversations) {
          final conversationMembers = members
              .where((member) => member.conversationId == conversation.id)
              .toList(growable: false);
          final otherMember = conversationMembers
              .where((member) => member.userId != currentUserId)
              .firstOrNull;
          final otherProfile =
              otherMember == null ? null : profilesById[otherMember.userId];
          final title = _conversationTitle(
            conversation,
            otherProfile,
          );
          final avatarUrl = conversation.avatarUrl ?? otherProfile?.avatarUrl;

          await _upsertConversation(
            conversation,
            title: title,
            avatarUrl: avatarUrl,
            syncedAt: syncedAt,
          );

          if (conversation.type == 'group') {
            await _upsertMembers(
              conversationMembers,
              profilesById,
            );
          }

          final messages = messagesByConversation[conversation.id];
          if (messages == null) continue;
          final existing = await _existingMessages(
            messages.map((message) => message.id).toList(growable: false),
          );
          for (final message in messages) {
            final isNew = !existing.containsKey(message.id);
            await _writeMessage(
              message,
              signedUrls: signedUrls,
              existing: existing[message.id],
            );
            if (isNew) importedMessages++;
          }
        }
      });

      return ChatSyncReport(
        conversations: conversations.length,
        messages: importedMessages,
        mediaUrls: signedUrls.length,
      );
    } finally {
      _syncing = false;
    }
  }

  /// Imports a realtime message. Returns false when the conversation is not
  /// available locally yet, so the caller can perform a metadata sync.
  Future<bool> importMessage(
    RemoteMessage message, {
    bool incrementUnread = true,
  }) async {
    final conversation = await (db.select(db.conversations)
          ..where((row) => row.id.equals(message.conversationId)))
        .getSingleOrNull();
    if (conversation == null) return false;

    var signedUrls = const <String, String>{};
    final storagePath = message.media?['storage_path'];
    if (storagePath is String && storagePath.isNotEmpty) {
      try {
        signedUrls = await source.signedMediaUrls([storagePath]);
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Could not sign realtime chat media',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    await db.transaction(() async {
      final existing = await (db.select(db.messages)
            ..where((row) => row.id.equals(message.id)))
          .getSingleOrNull();
      await _writeMessage(
        message,
        signedUrls: signedUrls,
        existing: existing,
      );

      final isLatest = conversation.lastMessageAt == null ||
          !message.createdAt.isBefore(conversation.lastMessageAt!);
      if (!isLatest) return;
      await db.updateConversationLastMessage(
        conversationId: message.conversationId,
        messageId: message.id,
        at: message.createdAt,
        incrementUnread: existing == null &&
            incrementUnread &&
            message.senderId != currentUserId,
      );
    });
    return true;
  }

  Future<Map<String, Conversation>> _existingConversations(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await (db.select(db.conversations)
          ..where((row) => row.id.isIn(ids)))
        .get();
    return {for (final row in rows) row.id: row};
  }

  Future<Map<String, Message>> _existingMessages(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (db.select(db.messages)..where((row) => row.id.isIn(ids))).get();
    return {for (final row in rows) row.id: row};
  }

  String? _conversationTitle(
    RemoteConversation conversation,
    RemoteProfile? otherProfile,
  ) {
    final title = conversation.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final displayName = otherProfile?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return switch (conversation.type) {
      'group' => 'Group',
      'channel' => 'Channel',
      _ => 'Chat',
    };
  }

  Future<void> _upsertConversation(
    RemoteConversation conversation, {
    required String? title,
    required String? avatarUrl,
    required DateTime syncedAt,
  }) async {
    final updatedAt = conversation.updatedAt ?? syncedAt;
    final insert = ConversationsCompanion.insert(
      id: conversation.id,
      type: conversation.type,
      title: Value(title),
      avatarUrl: Value(avatarUrl),
      lastMessageId: Value(conversation.lastMessageId),
      lastMessageAt: Value(conversation.lastMessageAt),
      updatedAt: Value(updatedAt),
      syncedAt: Value(syncedAt),
    );
    final update = ConversationsCompanion(
      type: Value(conversation.type),
      title: Value(title),
      avatarUrl: Value(avatarUrl),
      lastMessageId: Value(conversation.lastMessageId),
      lastMessageAt: Value(conversation.lastMessageAt),
      updatedAt: Value(updatedAt),
      syncedAt: Value(syncedAt),
    );
    await db.into(db.conversations).insert(
          insert,
          onConflict: DoUpdate((_) => update),
        );
  }

  Future<void> _upsertMembers(
    List<RemoteMember> members,
    Map<String, RemoteProfile> profilesById,
  ) async {
    for (final member in members) {
      final displayName = member.userId == currentUserId
          ? 'You'
          : profilesById[member.userId]?.displayName?.trim();
      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              conversationId: member.conversationId,
              memberId: member.userId,
              displayName: displayName == null || displayName.isEmpty
                  ? 'Member'
                  : displayName,
              role: Value(member.role),
              joinedAt: Value(member.joinedAt ?? DateTime.now()),
            ),
            onConflict: DoUpdate(
              (_) => GroupMembersCompanion(
                displayName: Value(
                  displayName == null || displayName.isEmpty
                      ? 'Member'
                      : displayName,
                ),
                role: Value(member.role),
              ),
            ),
          );
    }
  }

  Future<void> _writeMessage(
    RemoteMessage message, {
    required Map<String, String> signedUrls,
    Message? existing,
  }) async {
    final senderId =
        message.senderId == currentUserId ? 'me' : message.senderId;
    final media = _messageMedia(message, signedUrls);
    final mediaJson = media == null ? null : jsonEncode(media);
    if (existing == null) {
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: message.id,
              conversationId: message.conversationId,
              senderId: senderId,
              seq: Value(message.seq),
              type: message.type,
              body: Value(message.body),
              mediaJson: Value(mediaJson),
              replyTo: Value(message.replyTo),
              editedAt: Value(message.editedAt),
              createdAt: message.createdAt,
              status: const Value(1),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return;
    }
    await (db.update(db.messages)..where((row) => row.id.equals(message.id)))
        .write(
      MessagesCompanion(
        senderId: Value(senderId),
        seq: Value(message.seq),
        type: Value(message.type),
        body: Value(message.body),
        mediaJson: Value(mediaJson),
        replyTo: Value(message.replyTo),
        editedAt: Value(message.editedAt),
        createdAt: Value(message.createdAt),
        status: Value(existing.status == 3 ? 3 : 1),
      ),
    );
  }

  Map<String, dynamic>? _messageMedia(
    RemoteMessage message,
    Map<String, String> signedUrls,
  ) {
    final raw = message.media;
    if (raw == null) return null;
    final media = Map<String, dynamic>.from(raw);
    final storagePath = media['storage_path'];
    if (storagePath is String) {
      final url = signedUrls[storagePath];
      if (url != null) media['url'] = url;
    }
    return media;
  }
}
