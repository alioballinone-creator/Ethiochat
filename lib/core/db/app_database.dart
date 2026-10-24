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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // FTS5 for message search will be added in a later migration
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_messages_conv_created
            ON messages(conversation_id, created_at);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_outbox_next_retry
            ON outbox(next_retry_at);
          ''');
        },
        onUpgrade: (Migrator m, int from, int to) async {},
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ethiochat.db'));
    return NativeDatabase.createInBackground(file);
  });
}

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
