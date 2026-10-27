import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/core/errors/failure.dart';
import 'package:ethiochat/core/errors/result.dart';
import 'package:ethiochat/features/chats/data/datasources/outbox_worker.dart';
import 'package:ethiochat/features/chats/domain/entities/conversation_entity.dart';
import 'package:ethiochat/features/chats/domain/entities/conversation_summary.dart';
import 'package:ethiochat/features/chats/domain/entities/message_entity.dart';
import 'package:ethiochat/features/chats/domain/repositories/chat_repository.dart';
import 'package:ethiochat/features/contacts/domain/entities/contact_entity.dart';
import 'package:uuid/uuid.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this.db);

  final AppDatabase db;
  final _uuid = const Uuid();

  @override
  Stream<List<ConversationSummary>> watchSummaries() {
    final query = db.select(db.conversations).join([
      leftOuterJoin(
        db.messages,
        db.messages.id.equalsExp(db.conversations.lastMessageId),
      ),
    ])
      ..orderBy([
        OrderingTerm.desc(db.conversations.pinned),
        OrderingTerm.desc(db.conversations.lastMessageAt),
      ]);

    return query.watch().map((rows) => rows.map((row) {
          final conversation = row.readTable(db.conversations);
          final last = row.readTableOrNull(db.messages);
          return ConversationSummary(
            conversation: _toConversation(conversation),
            preview: _preview(last),
            lastMessageAt: last?.createdAt ?? conversation.lastMessageAt,
            lastMessageType: last?.type,
          );
        }).toList());
  }

  @override
  Stream<ConversationEntity?> watchConversation(String conversationId) {
    return db.watchConversation(conversationId).map(
          (row) => row == null ? null : _toConversation(row),
        );
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String conversationId) {
    return (db.select(db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..where((m) => m.deletedForMe.equals(false))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toMessage).toList());
  }

  @override
  Stream<List<ContactEntity>> watchContacts() {
    return (db.select(db.contactsLocal)
          ..orderBy([(c) => OrderingTerm.asc(c.displayName)]))
        .watch()
        .map((rows) => rows.map(_toContact).toList());
  }

  Future<bool> _isBlockedConversation(String conversationId) async {
    final conversation = await (db.select(db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    if (conversation == null ||
        conversation.type != ConversationType.direct.name) {
      return false;
    }
    final title = conversation.title?.trim();
    if (title == null || title.isEmpty) return false;
    final blocked = await (db.select(db.contactsLocal)
          ..where((c) => c.displayName.equals(title))
          ..where((c) => c.isBlocked.equals(true)))
        .getSingleOrNull();
    return blocked != null;
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
      if (await _isBlockedConversation(conversationId)) {
        return const Result.failure(
          ValidationFailure(
            'You blocked this contact. Unblock them in Settings to chat.',
          ),
        );
      }
      final id = _uuid.v4();
      final now = DateTime.now();
      await db.transaction(() async {
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
                status: const Value(0),
              ),
            );
        await db.updateConversationLastMessage(
          conversationId: conversationId,
          messageId: id,
          at: now,
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
            'created_at': now.toIso8601String(),
          },
        );
      });
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
  Future<Result<ConversationEntity>> ensureConversation(String id) async {
    try {
      final existing = await (db.select(db.conversations)
            ..where((c) => c.id.equals(id)))
          .getSingleOrNull();
      if (existing != null) {
        return Result.success(_toConversation(existing));
      }
      await db.into(db.conversations).insert(
            ConversationsCompanion.insert(
              id: id,
              type: ConversationType.direct.name,
              title: const Value('Chat'),
            ),
          );
      final row = await (db.select(db.conversations)
            ..where((c) => c.id.equals(id)))
          .getSingle();
      return Result.success(_toConversation(row));
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<ConversationEntity>> openDirectChat(
    String displayName,
  ) async {
    try {
      final name = displayName.trim();
      final existing = await (db.select(db.conversations)
            ..where((c) => c.type.equals(ConversationType.direct.name))
            ..where((c) => c.title.equals(name)))
          .getSingleOrNull();
      if (existing != null) {
        return Result.success(_toConversation(existing));
      }
      final id = _uuid.v4();
      await db.into(db.conversations).insert(
            ConversationsCompanion.insert(
              id: id,
              type: ConversationType.direct.name,
              title: Value(name),
            ),
          );
      final row = await (db.select(db.conversations)
            ..where((c) => c.id.equals(id)))
          .getSingle();
      return Result.success(_toConversation(row));
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<ConversationEntity>> createGroup(
    String title,
    List<String> memberNames,
  ) async {
    try {
      final id = _uuid.v4();
      final name = title.trim().isEmpty
          ? (memberNames.isEmpty ? 'New group' : memberNames.join(', '))
          : title.trim();
      await db.transaction(() async {
        await db.into(db.conversations).insert(
              ConversationsCompanion.insert(
                id: id,
                type: ConversationType.group.name,
                title: Value(name),
              ),
            );
        final messageId = _uuid.v4();
        final now = DateTime.now();
        await db.into(db.messages).insert(
              MessagesCompanion.insert(
                id: messageId,
                conversationId: id,
                senderId: 'system',
                type: MessageType.system.name,
                body: Value(
                  'Group created with ${memberNames.length} member'
                  '${memberNames.length == 1 ? '' : 's'}',
                ),
                createdAt: now,
                status: const Value(3),
              ),
            );
        await db.updateConversationLastMessage(
          conversationId: id,
          messageId: messageId,
          at: now,
        );
        await db.into(db.groupMembers).insert(
              GroupMembersCompanion.insert(
                conversationId: id,
                memberId: 'me',
                displayName: 'You',
                role: const Value('admin'),
                joinedAt: Value(now),
              ),
            );
        for (final member in memberNames) {
          await db.into(db.groupMembers).insert(
                GroupMembersCompanion.insert(
                  conversationId: id,
                  memberId: _uuid.v4(),
                  displayName: member,
                  joinedAt: Value(now),
                ),
              );
        }
      });
      final row = await (db.select(db.conversations)
            ..where((c) => c.id.equals(id)))
          .getSingle();
      return Result.success(_toConversation(row));
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
      final msg = await (db.select(db.messages)
            ..where((m) => m.id.equals(messageId)))
          .getSingle();
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

  @override
  Future<Result<void>> setPinned(String conversationId, bool pinned) {
    return _writeConversation(
      conversationId,
      ConversationsCompanion(pinned: Value(pinned)),
    );
  }

  @override
  Future<Result<void>> setMuted(String conversationId, bool muted) {
    return _writeConversation(
      conversationId,
      ConversationsCompanion(
        mutedUntil: Value(
          muted ? DateTime.now().add(const Duration(days: 365)) : null,
        ),
      ),
    );
  }

  @override
  Future<Result<void>> setArchived(String conversationId, bool archived) {
    return _writeConversation(
      conversationId,
      ConversationsCompanion(archived: Value(archived)),
    );
  }

  @override
  Future<Result<void>> deleteMessage(String messageId) async {
    try {
      final row = await (db.select(db.messages)
            ..where((m) => m.id.equals(messageId)))
          .getSingleOrNull();
      if (row == null) {
        return const Result.failure(NotFoundFailure('Message not found.'));
      }
      await db.transaction(() async {
        await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
            .write(const MessagesCompanion(deletedForMe: Value(true)));
        final conversation = await (db.select(db.conversations)
              ..where((c) => c.id.equals(row.conversationId)))
            .getSingleOrNull();
        if (conversation?.lastMessageId == messageId) {
          final remaining = await (db.select(db.messages)
                ..where((m) => m.conversationId.equals(row.conversationId))
                ..where((m) => m.deletedForMe.equals(false))
                ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
                ..limit(1))
              .getSingleOrNull();
          await (db.update(db.conversations)
                ..where((c) => c.id.equals(row.conversationId)))
              .write(
            ConversationsCompanion(
              lastMessageId: Value(remaining?.id),
              lastMessageAt: Value(remaining?.createdAt),
            ),
          );
        }
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> deleteMessageForEveryone(String messageId) async {
    try {
      final row = await (db.select(db.messages)
            ..where((m) => m.id.equals(messageId)))
          .getSingleOrNull();
      if (row == null) {
        return const Result.failure(NotFoundFailure('Message not found.'));
      }
      if (row.senderId != 'me') {
        return const Result.failure(
          ValidationFailure('You can only delete your own messages.'),
        );
      }
      if (DateTime.now().difference(row.createdAt) >
          const Duration(hours: 24)) {
        return const Result.failure(
          ValidationFailure(
              'Messages can only be deleted for everyone for 24 hours.'),
        );
      }
      await db.transaction(() async {
        await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
            .write(
          const MessagesCompanion(
            deletedEveryone: Value(true),
            body: Value(null),
            mediaJson: Value(null),
          ),
        );
        await (db.delete(db.outbox)
              ..where((o) => o.messageId.equals(messageId)))
            .go();
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> editMessage(String messageId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const Result.failure(
        ValidationFailure('A message cannot be empty.'),
      );
    }
    try {
      final row = await (db.select(db.messages)
            ..where((m) => m.id.equals(messageId)))
          .getSingleOrNull();
      if (row == null) {
        return const Result.failure(NotFoundFailure('Message not found.'));
      }
      if (row.senderId != 'me') {
        return const Result.failure(
          ValidationFailure('You can only edit your own messages.'),
        );
      }
      if (row.deletedForMe || row.deletedEveryone) {
        return const Result.failure(
          ValidationFailure('Deleted messages cannot be edited.'),
        );
      }
      if (row.type != 'text') {
        return const Result.failure(
          ValidationFailure('Only text messages can be edited.'),
        );
      }
      if (DateTime.now().difference(row.createdAt) >
          const Duration(minutes: 15)) {
        return const Result.failure(
          ValidationFailure('Messages can only be edited for 15 minutes.'),
        );
      }
      final editedAt = DateTime.now();
      await db.transaction(() async {
        await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
            .write(
          MessagesCompanion(
            body: Value(trimmed),
            editedAt: Value(editedAt),
          ),
        );
        final outboxRow = await (db.select(db.outbox)
              ..where((o) => o.messageId.equals(messageId)))
            .getSingleOrNull();
        if (outboxRow != null) {
          final payload =
              jsonDecode(outboxRow.payloadJson) as Map<String, dynamic>;
          payload['body'] = trimmed;
          payload['edited_at'] = editedAt.toIso8601String();
          await (db.update(db.outbox)
                ..where((o) => o.messageId.equals(messageId)))
              .write(OutboxCompanion(payloadJson: Value(jsonEncode(payload))));
        }
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<MessageEntity>> forwardMessage(
    String messageId,
    String targetConversationId,
  ) async {
    try {
      final row = await (db.select(db.messages)
            ..where((m) => m.id.equals(messageId)))
          .getSingleOrNull();
      if (row == null) {
        return const Result.failure(NotFoundFailure('Message not found.'));
      }
      if (await _isBlockedConversation(targetConversationId)) {
        return const Result.failure(
          ValidationFailure(
            'You blocked this contact. Unblock them in Settings to chat.',
          ),
        );
      }
      final id = _uuid.v4();
      final now = DateTime.now();
      await db.transaction(() async {
        await db.into(db.messages).insert(
              MessagesCompanion.insert(
                id: id,
                conversationId: targetConversationId,
                senderId: 'me',
                type: row.type,
                body: Value(row.body),
                mediaJson: Value(row.mediaJson),
                createdAt: now,
                status: const Value(0),
              ),
            );
        await db.updateConversationLastMessage(
          conversationId: targetConversationId,
          messageId: id,
          at: now,
        );
        await OutboxWorker.enqueue(
          db,
          messageId: id,
          conversationId: targetConversationId,
          payload: {
            'id': id,
            'conversation_id': targetConversationId,
            'type': row.type,
            'body': row.body,
            'media': row.mediaJson == null ? null : jsonDecode(row.mediaJson!),
            'created_at': now.toIso8601String(),
          },
        );
      });
      return Result.success(
        MessageEntity(
          id: id,
          conversationId: targetConversationId,
          senderId: 'me',
          type: MessageType.values.firstWhere(
            (t) => t.name == row.type,
            orElse: () => MessageType.text,
          ),
          body: row.body,
          media: row.mediaJson == null
              ? null
              : jsonDecode(row.mediaJson!) as Map<String, dynamic>,
          createdAt: now,
          status: MessageStatus.pending,
        ),
      );
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> clearMessages(String conversationId) async {
    try {
      await db.clearMessages(conversationId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> deleteConversation(String conversationId) async {
    try {
      await db.deleteConversationData(conversationId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<ContactEntity>> addContact({
    required String displayName,
    String? phoneE164,
  }) async {
    try {
      final id = _uuid.v4();
      final name = displayName.trim();
      await db.into(db.contactsLocal).insert(
            ContactsLocalCompanion.insert(
              id: id,
              displayName: Value(name),
              phoneE164: Value(phoneE164),
              ethioId: Value('EC-${id.substring(0, 6).toUpperCase()}'),
            ),
          );
      return Result.success(
        ContactEntity(
          id: id,
          displayName: name,
          phoneE164: phoneE164,
          ethioId: 'EC-${id.substring(0, 6).toUpperCase()}',
        ),
      );
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Stream<List<GroupMember>> watchGroupMembers(String conversationId) {
    return (db.select(db.groupMembers)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([
            (m) => OrderingTerm.desc(m.role),
            (m) => OrderingTerm.asc(m.joinedAt),
          ]))
        .watch();
  }

  @override
  Future<Result<void>> addGroupMember(
    String conversationId,
    String displayName, {
    bool admin = false,
  }) async {
    try {
      final name = displayName.trim();
      if (name.isEmpty) {
        return const Result.failure(
          ValidationFailure('Enter a member name.'),
        );
      }
      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              conversationId: conversationId,
              memberId: _uuid.v4(),
              displayName: name,
              role: Value(admin ? 'admin' : 'member'),
            ),
          );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> removeGroupMember(
    String conversationId,
    String memberId,
  ) async {
    try {
      await (db.delete(db.groupMembers)
            ..where((m) => m.conversationId.equals(conversationId))
            ..where((m) => m.memberId.equals(memberId)))
          .go();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> setGroupMemberRole(
    String conversationId,
    String memberId,
    bool admin,
  ) async {
    try {
      await (db.update(db.groupMembers)
            ..where((m) => m.conversationId.equals(conversationId))
            ..where((m) => m.memberId.equals(memberId)))
          .write(
        GroupMembersCompanion(
          role: Value(admin ? 'admin' : 'member'),
        ),
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> setContactBlocked(
    String displayName,
    bool blocked,
  ) async {
    try {
      final name = displayName.trim();
      final existing = await (db.select(db.contactsLocal)
            ..where((c) => c.displayName.equals(name)))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.contactsLocal).insert(
              ContactsLocalCompanion.insert(
                id: _uuid.v4(),
                displayName: Value(name),
                isBlocked: Value(blocked),
              ),
            );
      } else {
        await (db.update(db.contactsLocal)
              ..where((c) => c.id.equals(existing.id)))
            .write(ContactsLocalCompanion(isBlocked: Value(blocked)));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<void>> saveReport({
    required String targetId,
    required String targetName,
    required String reason,
    String? note,
  }) async {
    try {
      await db.into(db.reports).insert(
            ReportsCompanion.insert(
              id: _uuid.v4(),
              targetId: targetId,
              targetName: targetName,
              reason: reason,
              note: Value(note),
            ),
          );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Result<List<MessageEntity>>> searchMessages(String query) async {
    try {
      final rows = await db.searchMessages(query);
      return Result.success(rows.map(_toMessage).toList());
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final conversationRows = await db.select(db.conversations).get();
    final messageRows = await db.select(db.messages).get();
    final contactRows = await db.select(db.contactsLocal).get();
    final reportRows = await db.select(db.reports).get();
    final walletRows = await db.select(db.walletTransactions).get();
    final ledgerRows = await db.select(db.ledgerEntries).get();
    return {
      'format': 'ethiochat.export.v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'conversations': [
        for (final row in conversationRows)
          {
            'id': row.id,
            'type': row.type,
            'title': row.title,
            'lastMessageAt': row.lastMessageAt?.toUtc().toIso8601String(),
            'pinned': row.pinned,
            'archived': row.archived,
          },
      ],
      'messages': [
        for (final row in messageRows)
          {
            'id': row.id,
            'conversationId': row.conversationId,
            'senderId': row.senderId,
            'seq': row.seq,
            'type': row.type,
            'body': row.body,
            'media': row.mediaJson,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
            'deleted': row.deletedForMe || row.deletedEveryone,
          },
      ],
      'contacts': [
        for (final row in contactRows)
          {
            'id': row.id,
            'displayName': row.displayName,
            'phone': row.phoneE164,
            'ethioId': row.ethioId,
            'blocked': row.isBlocked,
          },
      ],
      'reports': [
        for (final row in reportRows)
          {
            'id': row.id,
            'targetName': row.targetName,
            'reason': row.reason,
            'note': row.note,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
          },
      ],
      'walletTransactions': [
        for (final row in walletRows)
          {
            'id': row.id,
            'type': row.type,
            'status': row.status,
            'amountMinor': row.amountMinor,
            'direction': row.direction,
            'note': row.note,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
          },
      ],
      'ledgerEntries': [
        for (final row in ledgerRows)
          {
            'txnId': row.txnId,
            'account': row.account,
            'direction': row.direction,
            'amountMinor': row.amountMinor,
            'currency': row.currency,
          },
      ],
    };
  }

  @override
  Future<Result<void>> deleteAllData() async {
    try {
      await db.clearAllData();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  @override
  Future<void> seedDemoData() async {
    if (await db.conversationCount() > 0) return;
    // Contacts survive deleting every chat; keep the demo feed from returning.
    final existingContacts = await db.select(db.contactsLocal).get();
    if (existingContacts.isNotEmpty) return;

    final now = DateTime.now();
    final contacts = <(String, String, String)>[
      ('u1', 'Abebe Kebede', '+251911234567'),
      ('u2', 'Tigist Alemayehu', '+251912345678'),
      ('u3', 'Dawit Bekele', '+251913456789'),
      ('u4', 'Hanna Girma', '+251914567890'),
      ('u5', 'Samuel Tesfaye', '+251915678901'),
      ('u6', 'Marta Assefa', '+251916789012'),
      ('u7', 'Yonas Alemu', '+251917890123'),
      ('u8', 'Selam Bekele', '+251918901234'),
      ('u9', 'Amanuel Girma', '+251919012345'),
      ('u10', 'Alemayehu Tadesse', '+251910123456'),
    ];

    final seededConversations = <({
      String id,
      String type,
      String title,
      int unread,
      bool pinned,
      List<(String body, bool mine, Duration ago)> messages,
    })>[
      (
        id: '1',
        type: 'direct',
        title: 'Abebe Kebede',
        unread: 2,
        pinned: true,
        messages: [
          ('Hello! How are you?', false, const Duration(hours: 2)),
          (
            'I am fine, thanks! Are we still meeting tomorrow?',
            true,
            const Duration(hours: 1)
          ),
          (
            'Yes — see you at 9 at Bole. 🙌',
            false,
            const Duration(minutes: 40)
          ),
          ('See you tomorrow', false, const Duration(minutes: 12)),
        ],
      ),
      (
        id: '2',
        type: 'direct',
        title: 'Tigist Alemayehu',
        unread: 0,
        pinned: false,
        messages: [
          ('Did you get the invoice?', true, const Duration(hours: 5)),
          ('Thanks! 🙏', false, const Duration(hours: 4)),
        ],
      ),
      (
        id: '3',
        type: 'channel',
        title: 'EthioChat Support',
        unread: 0,
        pinned: false,
        messages: [
          (
            'Welcome to EthioChat 👋 Tap here for help at any time.',
            false,
            const Duration(days: 1)
          ),
        ],
      ),
      (
        id: '4',
        type: 'group',
        title: 'Work group',
        unread: 5,
        pinned: false,
        messages: [
          (
            'Dawit: Meeting moved to 3 PM',
            false,
            const Duration(days: 1, hours: 2)
          ),
        ],
      ),
      (
        id: '5',
        type: 'direct',
        title: 'Hanna Girma',
        unread: 0,
        pinned: false,
        messages: [
          ('Voice message · 0:12', false, const Duration(days: 2)),
        ],
      ),
      (
        id: '6',
        type: 'direct',
        title: 'Selam Bekele',
        unread: 0,
        pinned: false,
        messages: [
          ('Sent ETB 250.00', true, const Duration(days: 3)),
        ],
      ),
    ];

    await db.transaction(() async {
      for (final contact in contacts) {
        await db.into(db.contactsLocal).insert(
              ContactsLocalCompanion.insert(
                id: contact.$1,
                displayName: Value(contact.$2),
                phoneE164: Value(contact.$3),
                ethioId: Value(
                  'EC-${contact.$1.replaceAll('u', '').padLeft(4, '0')}',
                ),
              ),
            );
      }

      for (final seeded in seededConversations) {
        await db.into(db.conversations).insert(
              ConversationsCompanion.insert(
                id: seeded.id,
                type: seeded.type,
                title: Value(seeded.title),
                pinned: Value(seeded.pinned),
                localUnread: Value(seeded.unread),
              ),
            );
        if (seeded.type == 'group') {
          for (final member in const [
            ('me', 'You', 'admin'),
            ('u3', 'Dawit Bekele', 'member'),
            ('u4', 'Hanna Girma', 'member'),
            ('u5', 'Samuel Tesfaye', 'member'),
            ('u6', 'Marta Assefa', 'member'),
          ]) {
            await db.into(db.groupMembers).insert(
                  GroupMembersCompanion.insert(
                    conversationId: seeded.id,
                    memberId: member.$1,
                    displayName: member.$2,
                    role: Value(member.$3),
                    joinedAt: Value(now),
                  ),
                );
          }
        }
        String? lastId;
        DateTime? lastAt;
        var seq = 1;
        for (final message in seeded.messages) {
          final id = '${seeded.id}-m$seq';
          final at = now.subtract(message.$3);
          await db.into(db.messages).insert(
                MessagesCompanion.insert(
                  id: id,
                  conversationId: seeded.id,
                  senderId: message.$2 ? 'me' : 'u-${seeded.id}',
                  seq: Value(seq),
                  type: MessageType.text.name,
                  body: Value(message.$1),
                  createdAt: at,
                  status: const Value(3),
                ),
              );
          lastId = id;
          lastAt = at;
          seq++;
        }
        await db.updateConversationLastMessage(
          conversationId: seeded.id,
          messageId: lastId!,
          at: lastAt!,
        );
        await (db.update(db.conversations)
              ..where((c) => c.id.equals(seeded.id)))
            .write(
          ConversationsCompanion(localUnread: Value(seeded.unread)),
        );
      }
    });
  }

  Future<Result<void>> _writeConversation(
    String conversationId,
    ConversationsCompanion companion,
  ) async {
    try {
      await (db.update(db.conversations)
            ..where((c) => c.id.equals(conversationId)))
          .write(companion);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  ConversationEntity _toConversation(Conversation row) {
    return ConversationEntity(
      id: row.id,
      type: ConversationType.values.firstWhere(
        (t) => t.name == row.type,
        orElse: () => ConversationType.direct,
      ),
      title: row.title,
      avatarUrl: row.avatarUrl,
      lastMessageId: row.lastMessageId,
      lastMessageAt: row.lastMessageAt,
      unread: row.localUnread,
      pinned: row.pinned,
      archived: row.archived,
      mutedUntil: row.mutedUntil,
    );
  }

  MessageEntity _toMessage(Message row) {
    return MessageEntity(
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      seq: row.seq,
      type: MessageType.values.firstWhere(
        (t) => t.name == row.type,
        orElse: () => MessageType.text,
      ),
      body: row.body,
      media: row.mediaJson == null
          ? null
          : jsonDecode(row.mediaJson!) as Map<String, dynamic>,
      replyTo: row.replyTo,
      editedAt: row.editedAt,
      createdAt: row.createdAt,
      status: MessageStatus
          .values[row.status.clamp(0, MessageStatus.values.length - 1).toInt()],
      deletedForMe: row.deletedForMe,
      deletedEveryone: row.deletedEveryone,
    );
  }

  ContactEntity _toContact(ContactRow row) {
    return ContactEntity(
      id: row.id,
      displayName: row.displayName ?? 'Contact',
      phoneE164: row.phoneE164,
      ethioId: row.ethioId,
      avatarUrl: row.avatarUrl,
      isBlocked: row.isBlocked,
    );
  }

  String _preview(Message? message) {
    if (message == null) return 'No messages yet';
    if (message.deletedEveryone) return 'This message was deleted';
    final body = message.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    return switch (message.type) {
      'image' => 'Photo',
      'voice' => 'Voice message',
      'video' => 'Video',
      'file' => 'Document',
      'location' => 'Location',
      'payment' => 'Payment',
      'redpacket' => 'Red packet',
      _ => 'Message',
    };
  }
}
