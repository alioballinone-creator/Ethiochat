import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/features/chats/data/datasources/outbox_worker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue writes to outbox and message starts pending', () async {
    final now = DateTime.now();
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: 'c1',
            type: 'direct',
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'm1',
            conversationId: 'c1',
            senderId: 'u1',
            type: 'text',
            body: const drift.Value('hello'),
            createdAt: now,
            status: const drift.Value(0),
          ),
        );
    await OutboxWorker.enqueue(
      db,
      messageId: 'm1',
      conversationId: 'c1',
      payload: {'id': 'm1', 'body': 'hello'},
    );
    final outbox = await db.select(db.outbox).get();
    expect(outbox.length, 1);
    expect(outbox.first.messageId, 'm1');
    expect(outbox.first.attempt, 0);
  });
}
