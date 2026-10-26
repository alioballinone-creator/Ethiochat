import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/core/errors/failure.dart';
import 'package:ethiochat/core/errors/result.dart';
import 'package:ethiochat/features/chats/data/datasources/outbox_worker.dart';
import 'package:ethiochat/features/chats/domain/entities/conversation_entity.dart';
import 'package:ethiochat/features/chats/domain/entities/message_entity.dart';
import 'package:ethiochat/features/chats/domain/repositories/chat_repository.dart';
import 'package:uuid/uuid.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this.db);
  final AppDatabase db;
  final _uuid = const Uuid();

  @override
  Stream<List<ConversationEntity>> watchConversations() {
    return db.watchConversations().map((rows) => rows.map((r) {
      return ConversationEntity(
        id: r.id,
        type: ConversationType.direct,
        title: r.title,
        avatarUrl: r.avatarUrl,
        lastMessageId: r.lastMessageId,
        lastMessageAt: r.lastMessageAt,
        unread: r.localUnread,
        pinned: r.pinned,
        archived: r.archived,
        mutedUntil: r.mutedUntil,
      );
    }).toList());
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String conversationId) {
    return (db.select(db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..where((m) => m.deletedForMe.equals(false))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch()
        .map((rows) => rows.map((r) {
              return MessageEntity(
                id: r.id,
                conversationId: r.conversationId,
                senderId: r.senderId,
                seq: r.seq,
                type: MessageType.text,
                body: r.body,
                media: r.mediaJson == null
                    ? null
                    : jsonDecode(r.mediaJson!) as Map<String, dynamic>,
                replyTo: r.replyTo,
                editedAt: r.editedAt,
                createdAt: r.createdAt,
                status: MessageStatus.values[r.status.clamp(0, 4)],
                deletedForMe: r.deletedForMe,
                deletedEveryone: r.deletedEveryone,
              );
            }).toList());
  }

  @override
  Future<Result<MessageEntity>> sendMessage({
    required String conversationId,
    required MessageType type,
    String? body,
    Map<String, dynamic>? media,
    String? replyTo,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();
      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderId: 'me',
          type: type.name,
          body: Value(body),
          mediaJson: Value(media == null ? null : jsonEncode(media)),
          replyTo: Value(replyTo),
          createdAt: now,
          status: const Value(0), // pending
        ),
      );
      await OutboxWorker.enqueue(
        db,
        messageId: id,
        conversationId: conversationId,
        payload: {
          'id': id,
          'conversation_id': conversationId,
          'type': type.name,
          'body': body,
          'media': media,
          'reply_to': replyTo,
        },
      );
      return Result.success(
        MessageEntity(
          id: id,
          conversationId: conversationId,
          senderId: 'me',
          type: type,
          body: body,
          media: media,
          replyTo: replyTo,
          createdAt: now,
        ),
      );
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> markRead(String conversationId, int lastReadSeq) async {
    try {
      await db.markRead(conversationId, lastReadSeq);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> retryFailed(String messageId) async {
    try {
      await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
          .write(const MessagesCompanion(status: Value(0)));
      final msg = await (db.select(db.messages)..where((m) => m.id.equals(messageId))).getSingle();
      await OutboxWorker.enqueue(
        db,
        messageId: messageId,
        conversationId: msg.conversationId,
        payload: {'id': messageId, 'conversation_id': msg.conversationId},
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }
}
