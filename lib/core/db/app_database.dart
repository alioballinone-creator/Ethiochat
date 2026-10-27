import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'drift_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Conversations,
    Messages,
    MessageReceipts,
    Outbox,
    ContactsLocal,
    WalletTransactions,
    LedgerEntries,
    GroupMembers,
    Reports,
    MomentsLocal,
    MomentLikes,
    MomentComments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_messages_conv_created
            ON messages(conversation_id, created_at);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_outbox_next_retry
            ON outbox(next_retry_at);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_wallet_created
            ON wallet_transactions(created_at DESC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_ledger_account
            ON ledger_entries(account, created_at);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_group_members_conversation
            ON group_members(conversation_id, joined_at);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_moments_created
            ON moments_local(created_at DESC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_moment_comments_moment
            ON moment_comments(moment_id, created_at);
          ''');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(walletTransactions);
            await m.createTable(ledgerEntries);
            await m.createTable(reports);
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_wallet_created
              ON wallet_transactions(created_at DESC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_ledger_account
              ON ledger_entries(account, created_at);
            ''');
          }
          if (from < 3) {
            await m.createTable(groupMembers);
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_group_members_conversation
              ON group_members(conversation_id, joined_at);
            ''');
          }
          if (from < 4) {
            await m.createTable(momentsLocal);
            await m.createTable(momentLikes);
            await m.createTable(momentComments);
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_moments_created
              ON moments_local(created_at DESC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_moment_comments_moment
              ON moment_comments(moment_id, created_at);
            ''');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          await customStatement('PRAGMA temp_store = MEMORY;');
        },
      );

  Future<List<Message>> messagesForConversation(
    String conversationId, {
    int limit = 30,
    int? beforeSeq,
  }) {
    final query = select(messages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..where((m) => m.deletedForMe.equals(false))
      ..orderBy([(m) => OrderingTerm.desc(m.seq.isNull())])
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
      ..limit(limit);
    if (beforeSeq != null) {
      query.where((m) => m.seq.isSmallerThanValue(beforeSeq));
    }
    return query.get();
  }

  Stream<Conversation?> watchConversation(String id) {
    return (select(conversations)..where((c) => c.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<List<Message>> searchMessages(String query, {int limit = 50}) {
    final needle = '%${query.trim()}%';
    return (select(messages)
          ..where((m) => m.deletedForMe.equals(false))
          ..where((m) => m.body.like(needle))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> conversationCount() async {
    final c = countAll();
    final row = await (selectOnly(conversations)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<void> updateConversationLastMessage({
    required String conversationId,
    required String messageId,
    required DateTime at,
    bool incrementUnread = false,
  }) async {
    final existing = await (select(conversations)
          ..where((c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    if (existing == null) return;
    await (update(conversations)..where((c) => c.id.equals(conversationId)))
        .write(
      ConversationsCompanion(
        lastMessageId: Value(messageId),
        lastMessageAt: Value(at),
        updatedAt: Value(DateTime.now()),
        localUnread: Value(
          incrementUnread ? existing.localUnread + 1 : existing.localUnread,
        ),
      ),
    );
  }

  Future<void> clearMessages(String conversationId) async {
    await transaction(() async {
      final ids = await (select(messages)
            ..where((m) => m.conversationId.equals(conversationId)))
          .get();
      for (final m in ids) {
        await (delete(messageReceipts)..where((r) => r.messageId.equals(m.id)))
            .go();
      }
      await (delete(outbox)
            ..where((o) => o.conversationId.equals(conversationId)))
          .go();
      await (delete(messages)
            ..where((m) => m.conversationId.equals(conversationId)))
          .go();
      await (update(conversations)..where((c) => c.id.equals(conversationId)))
          .write(const ConversationsCompanion(
        lastMessageId: Value(null),
        lastMessageAt: Value(null),
        localUnread: Value(0),
      ));
    });
  }

  Future<void> deleteConversationData(String conversationId) async {
    await transaction(() async {
      final ids = await (select(messages)
            ..where((m) => m.conversationId.equals(conversationId)))
          .get();
      for (final m in ids) {
        await (delete(messageReceipts)..where((r) => r.messageId.equals(m.id)))
            .go();
      }
      await (delete(outbox)
            ..where((o) => o.conversationId.equals(conversationId)))
          .go();
      await (delete(messages)
            ..where((m) => m.conversationId.equals(conversationId)))
          .go();
      await (delete(conversations)..where((c) => c.id.equals(conversationId)))
          .go();
    });
  }

  Stream<List<Conversation>> watchConversations() {
    final query = select(conversations)
      ..where((c) => c.archived.equals(false))
      ..orderBy([
        (c) => OrderingTerm.desc(c.pinned),
        (c) => OrderingTerm.desc(c.lastMessageAt),
      ]);
    return query.watch();
  }

  Future<void> markRead(String conversationId, int lastReadSeq) async {
    await (update(conversations)..where((c) => c.id.equals(conversationId)))
        .write(const ConversationsCompanion(localUnread: Value(0)));
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(messageReceipts).go();
      await delete(outbox).go();
      await delete(messages).go();
      await delete(groupMembers).go();
      await delete(conversations).go();
      await delete(contactsLocal).go();
      await delete(reports).go();
      await delete(momentComments).go();
      await delete(momentLikes).go();
      await delete(momentsLocal).go();
      await delete(walletTransactions).go();
      await delete(ledgerEntries).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ethiochat.db'));
    return NativeDatabase.createInBackground(file);
  });
}
