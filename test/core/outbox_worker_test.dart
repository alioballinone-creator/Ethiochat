import 'package:connectivity_plus/connectivity_plus.dart';
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

  Future<void> seedPendingMessage(String id) async {
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: 'c1',
            type: 'direct',
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: id,
            conversationId: 'c1',
            senderId: 'me',
            type: 'text',
            body: const drift.Value('hello'),
            createdAt: DateTime.now(),
            status: const drift.Value(0),
          ),
        );
    await OutboxWorker.enqueue(
      db,
      messageId: id,
      conversationId: 'c1',
      payload: {'id': id, 'conversation_id': 'c1', 'body': 'hello'},
    );
  }

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

  test('delivers a queued message through the transport', () async {
    await seedPendingMessage('m1');
    final payloads = <Map<String, dynamic>>[];
    final worker = OutboxWorker(
      db: db,
      connectivity: Connectivity(),
      transport: (payload) async => payloads.add(payload),
    );

    expect(await worker.processPending(), isTrue);

    expect(payloads.single['id'], 'm1');
    expect(await db.select(db.outbox).get(), isEmpty);
    final message = await (db.select(db.messages)
          ..where((m) => m.id.equals('m1')))
        .getSingle();
    expect(message.status, 1);
  });

  test('keeps a failed message queued with backoff metadata', () async {
    await seedPendingMessage('m2');
    final worker = OutboxWorker(
      db: db,
      connectivity: Connectivity(),
      transport: (_) async => throw StateError('offline'),
    );

    await worker.processPending();

    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempt, 1);
    expect(row.lastError, 'send_failed');
    expect(row.nextRetryAt, greaterThan(DateTime.now().millisecondsSinceEpoch));
    final message = await (db.select(db.messages)
          ..where((m) => m.id.equals('m2')))
        .getSingle();
    expect(message.status, 0);
  });

  test('does not mark queued message sent without a transport', () async {
    await seedPendingMessage('m3');
    final worker = OutboxWorker(
      db: db,
      connectivity: Connectivity(),
    );

    await worker.processPending();

    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempt, 1);
    expect(row.lastError, 'send_failed');
    final message = await (db.select(db.messages)
          ..where((m) => m.id.equals('m3')))
        .getSingle();
    expect(message.status, 0);
  });

  test('invalid message payload remains visible as failed', () async {
    await seedPendingMessage('m4');
    await (db.update(db.outbox)..where((o) => o.messageId.equals('m4'))).write(
      const OutboxCompanion(payloadJson: drift.Value('{invalid')),
    );
    final worker = OutboxWorker(
      db: db,
      connectivity: Connectivity(),
      transport: (_) async {},
    );

    await worker.processPending();

    expect(await db.select(db.outbox).get(), isEmpty);
    final message = await (db.select(db.messages)
          ..where((m) => m.id.equals('m4')))
        .getSingle();
    expect(message.status, 4);
  });
}
