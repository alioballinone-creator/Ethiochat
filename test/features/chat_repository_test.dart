import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/features/chats/data/repositories/chat_repository_impl.dart';
import 'package:ethiochat/features/chats/domain/entities/conversation_entity.dart';
import 'package:ethiochat/features/chats/domain/entities/message_entity.dart';
import 'package:ethiochat/features/chats/domain/repositories/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ChatRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
    await repo.seedDemoData();
  });

  tearDown(() async {
    await db.close();
  });

  test('seedDemoData is idempotent and loads demo conversations', () async {
    await repo.seedDemoData();

    expect(await db.conversationCount(), 6);

    final summaries = await repo.watchSummaries().first;
    expect(summaries, hasLength(6));
    // Pinned conversations sort first; conversation 1 is pinned.
    expect(summaries.first.id, '1');
    expect(summaries.first.title, 'Abebe Kebede');
    expect(summaries.first.pinned, isTrue);
    expect(summaries.first.unread, 2);
    expect(summaries.first.preview, 'See you tomorrow');

    final contacts = await repo.watchContacts().first;
    expect(contacts, hasLength(10));
    expect(
      contacts.map((c) => c.displayName),
      containsAll(<String>['Abebe Kebede', 'Tigist Alemayehu']),
    );

    final messages = await repo.watchMessages('1').first;
    expect(messages, hasLength(4));
    expect(messages.last.body, 'See you tomorrow');
  });

  test('sendMessage persists, updates preview and queues an outbox row',
      () async {
    final result = await repo.sendMessage(
      conversationId: '1',
      type: MessageType.text,
      body: 'Hello from the test',
    );

    expect(result.isSuccess, isTrue);
    final sent = result.valueOrNull!;
    expect(sent.id, isNotEmpty);

    final messages = await repo.watchMessages('1').first;
    expect(messages.last.body, 'Hello from the test');
    expect(messages.last.senderId, 'me');

    final summaries = await repo.watchSummaries().first;
    final chat = summaries.firstWhere((s) => s.id == '1');
    expect(chat.preview, 'Hello from the test');
    expect(chat.lastMessageAt, isNotNull);

    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.messageId, sent.id);
  });

  test('openDirectChat reuses an existing direct conversation', () async {
    final existing = await repo.openDirectChat('Abebe Kebede');
    expect(existing.valueOrNull?.id, '1');

    final created = await repo.openDirectChat('New Person');
    expect(created.isSuccess, isTrue);
    expect(created.valueOrNull?.title, 'New Person');
    expect(created.valueOrNull?.id, isNot('1'));

    expect(await db.conversationCount(), 7);
  });

  test('createGroup inserts a group with a system message', () async {
    final result = await repo.createGroup(
      'Weekend plans',
      <String>['Abebe Kebede', 'Hanna Girma'],
    );

    expect(result.isSuccess, isTrue);
    final group = result.valueOrNull!;
    expect(group.type, ConversationType.group);
    expect(group.title, 'Weekend plans');

    final messages = await repo.watchMessages(group.id).first;
    expect(messages, hasLength(1));
    expect(messages.single.type, MessageType.system);
    expect(messages.single.body, contains('2 members'));
  });

  test('pin, mute and archive persist', () async {
    expect((await repo.setPinned('2', true)).isSuccess, isTrue);
    expect((await repo.setMuted('2', true)).isSuccess, isTrue);
    expect((await repo.setArchived('2', true)).isSuccess, isTrue);

    var conversation = await repo.watchConversation('2').first;
    expect(conversation?.pinned, isTrue);
    expect(conversation?.mutedUntil, isNotNull);
    expect(conversation?.archived, isTrue);

    await repo.setPinned('2', false);
    await repo.setMuted('2', false);
    await repo.setArchived('2', false);

    conversation = await repo.watchConversation('2').first;
    expect(conversation?.pinned, isFalse);
    expect(conversation?.mutedUntil, isNull);
    expect(conversation?.archived, isFalse);
  });

  test('markRead clears the unread counter', () async {
    await repo.markRead('1', 0);

    final conversation = await repo.watchConversation('1').first;
    expect(conversation?.unread, 0);
  });

  test('searchMessages finds text across conversations', () async {
    final result = await repo.searchMessages('invoice');

    expect(result.isSuccess, isTrue);
    final hits = result.valueOrNull!;
    expect(hits, hasLength(1));
    expect(hits.single.conversationId, '2');
    expect(hits.single.body, contains('invoice'));
  });

  test('addContact appends a contact', () async {
    final before = await repo.watchContacts().first;

    final result = await repo.addContact(
      displayName: 'Meseret Haile',
      phoneE164: '+251900000000',
    );

    expect(result.isSuccess, isTrue);
    final after = await repo.watchContacts().first;
    expect(after, hasLength(before.length + 1));
    expect(
      after.map((c) => c.displayName),
      contains('Meseret Haile'),
    );
  });

  test('editMessage updates recent own text and rejects old messages',
      () async {
    final sent = await repo.sendMessage(
      conversationId: '1',
      type: MessageType.text,
      body: 'original',
    );
    final id = sent.valueOrNull!.id;

    expect((await repo.editMessage(id, '  updated  ')).isSuccess, isTrue);
    var messages = await repo.watchMessages('1').first;
    var row = messages.firstWhere((m) => m.id == id);
    expect(row.body, 'updated');
    expect(row.editedAt, isNotNull);

    final old = messages.firstWhere((m) => m.senderId == 'me');
    final rejected = await repo.editMessage(old.id, 'too late');
    expect(rejected.isSuccess, isFalse);
    expect(rejected.failureOrNull?.message, contains('15 minutes'));

    messages = await repo.watchMessages('1').first;
    row = messages.firstWhere((m) => m.id == id);
    expect(row.body, 'updated');
  });

  test('deleteMessageForEveryone clears content and updates the preview',
      () async {
    final sent = await repo.sendMessage(
      conversationId: '1',
      type: MessageType.text,
      body: 'secret',
    );
    final id = sent.valueOrNull!.id;

    expect((await repo.deleteMessageForEveryone(id)).isSuccess, isTrue);
    final row =
        (await repo.watchMessages('1').first).firstWhere((m) => m.id == id);
    expect(row.deletedEveryone, isTrue);
    expect(row.body, isNull);
    final summary =
        (await repo.watchSummaries().first).firstWhere((s) => s.id == '1');
    expect(summary.preview, 'This message was deleted');

    final old = (await repo.watchMessages('1').first)
        .firstWhere((m) => m.senderId != 'me');
    final rejected = await repo.deleteMessageForEveryone(old.id);
    expect(rejected.isSuccess, isFalse);
  });

  test('clearMessages removes messages but keeps the conversation', () async {
    expect((await repo.clearMessages('1')).isSuccess, isTrue);

    expect(await repo.watchMessages('1').first, isEmpty);
    final conversation = await repo.watchConversation('1').first;
    expect(conversation, isNotNull);

    final chat =
        (await repo.watchSummaries().first).firstWhere((s) => s.id == '1');
    expect(chat.preview, 'No messages yet');
    expect(chat.lastMessageAt, isNull);
  });

  test('moments persist, toggle likes and cascade comments', () async {
    var moments = await repo.watchMoments().first;
    expect(moments, hasLength(3));

    expect((await repo.createMoment('Hello moments')).isSuccess, isTrue);
    moments = await repo.watchMoments().first;
    expect(moments, hasLength(4));
    final created = moments.first;
    expect(created.authorId, 'me');
    expect(created.body, 'Hello moments');

    expect((await repo.toggleMomentLike(created.id)).isSuccess, isTrue);
    expect(await repo.watchLikedMomentIds().first, contains(created.id));
    moments = await repo.watchMoments().first;
    expect(moments.first.likeCount, 1);

    expect((await repo.addMomentComment(created.id, 'Nice')).isSuccess, isTrue);
    final comments = await repo.momentComments(created.id);
    expect(comments, hasLength(1));
    expect(comments.single.body, 'Nice');
    moments = await repo.watchMoments().first;
    expect(moments.first.commentCount, 1);

    expect((await repo.deleteMoment(created.id)).isSuccess, isTrue);
    expect(await repo.watchMoments().first, hasLength(3));
    expect(await repo.momentComments(created.id), isEmpty);
  });

  test('exportData contains local account data without secrets', () async {
    final data = await repo.exportData();

    expect(data['format'], 'ethiochat.export.v1');
    expect(data['conversations'], hasLength(6));
    expect(data['messages'], isNotEmpty);
    expect(data['contacts'], hasLength(10));
    expect(data['walletTransactions'], isA<List<dynamic>>());
    expect(data.toString(), isNot(contains('pin_hash')));
    expect(data.toString(), isNot(contains('pinHash')));
  });

  test('deleteAllData removes chats, contacts and wallet history', () async {
    expect((await repo.deleteAllData()).isSuccess, isTrue);

    expect(await db.conversationCount(), 0);
    expect(await db.select(db.messages).get(), isEmpty);
    expect(await db.select(db.contactsLocal).get(), isEmpty);
    expect(await db.select(db.walletTransactions).get(), isEmpty);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
  });

  test('deleteConversation removes the conversation and its messages',
      () async {
    await repo.sendMessage(
      conversationId: '1',
      type: MessageType.text,
      body: 'to be deleted',
    );

    expect((await repo.deleteConversation('1')).isSuccess, isTrue);

    expect(await db.conversationCount(), 5);
    expect(await repo.watchConversation('1').first, isNull);
    expect(await repo.watchMessages('1').first, isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });
}
