import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/features/chats/data/datasources/chat_sync_service.dart';
import 'package:ethiochat/features/chats/data/datasources/remote_chat_source.dart';
import 'package:flutter_test/flutter_test.dart';

const _conversationId = '11111111-1111-4111-8111-111111111111';
const _myId = '22222222-2222-4222-8222-222222222222';
const _otherId = '33333333-3333-4333-8333-333333333333';
const _messageId = '44444444-4444-4444-8444-444444444444';
const _ownMessageId = '55555555-5555-4555-8555-555555555555';
const _storagePath = '$_conversationId/$_messageId.jpg';
const _signedUrl = 'https://example.test/signed/photo.jpg';

void main() {
  late AppDatabase db;
  late FakeRemoteChatSource source;
  late ChatSyncService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    source = FakeRemoteChatSource();
    service = ChatSyncService(
      db: db,
      source: source,
      currentUserId: _myId,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('hydrates conversations, member names, messages and media URLs',
      () async {
    final at = DateTime.utc(2026, 10, 27, 10, 30);
    source.conversations = [
      RemoteConversation(
        id: _conversationId,
        type: 'direct',
        lastMessageId: _messageId,
        lastMessageAt: at,
        updatedAt: at,
      ),
    ];
    source.members = [
      RemoteMember(
        conversationId: _conversationId,
        userId: _myId,
        role: 'member',
        joinedAt: at,
      ),
      RemoteMember(
        conversationId: _conversationId,
        userId: _otherId,
        role: 'member',
        joinedAt: at,
      ),
    ];
    source.profiles = [
      RemoteProfile(
        id: _otherId,
        displayName: 'Tigist Alemayehu',
        avatarUrl: 'https://example.test/avatar.jpg',
      ),
    ];
    source.messages[_conversationId] = [
      RemoteMessage(
        id: _messageId,
        conversationId: _conversationId,
        senderId: _otherId,
        type: 'image',
        seq: 7,
        media: {'storage_path': _storagePath, 'name': 'photo.jpg'},
        createdAt: at,
      ),
    ];
    source.signedUrls[_storagePath] = _signedUrl;

    final report = await service.sync();

    expect(report.conversations, 1);
    expect(report.messages, 1);
    expect(report.mediaUrls, 1);

    final conversation = await (db.select(db.conversations)
          ..where((row) => row.id.equals(_conversationId)))
        .getSingle();
    expect(conversation.title, 'Tigist Alemayehu');
    expect(conversation.avatarUrl, 'https://example.test/avatar.jpg');
    expect(conversation.lastMessageId, _messageId);

    final message = await (db.select(db.messages)
          ..where((row) => row.id.equals(_messageId)))
        .getSingle();
    expect(message.senderId, _otherId);
    expect(message.seq, 7);
    expect(message.status, 1);
    final media = jsonDecode(message.mediaJson!) as Map<String, dynamic>;
    expect(media['url'], _signedUrl);
    expect(media['storage_path'], _storagePath);
  });

  test('preserves local pin, unread and delete-for-me state', () async {
    final firstAt = DateTime.utc(2026, 10, 27, 9);
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: _conversationId,
            type: 'direct',
            title: const drift.Value('Local title'),
            pinned: const drift.Value(true),
            archived: const drift.Value(true),
            localUnread: const drift.Value(4),
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: _messageId,
            conversationId: _conversationId,
            senderId: _otherId,
            type: 'text',
            body: const drift.Value('old body'),
            createdAt: firstAt,
            status: const drift.Value(3),
            deletedForMe: const drift.Value(true),
          ),
        );

    source.conversations = [
      RemoteConversation(
        id: _conversationId,
        type: 'direct',
        title: 'Remote title',
        lastMessageId: _messageId,
        lastMessageAt: firstAt,
      ),
    ];
    source.members = [
      RemoteMember(
        conversationId: _conversationId,
        userId: _otherId,
        role: 'member',
      ),
    ];
    source.messages[_conversationId] = [
      RemoteMessage(
        id: _messageId,
        conversationId: _conversationId,
        senderId: _otherId,
        type: 'text',
        body: 'new body',
        seq: 2,
        createdAt: firstAt,
      ),
    ];

    await service.sync();
    await service.sync();

    final conversation = await (db.select(db.conversations)
          ..where((row) => row.id.equals(_conversationId)))
        .getSingle();
    expect(conversation.title, 'Remote title');
    expect(conversation.pinned, isTrue);
    expect(conversation.archived, isTrue);
    expect(conversation.localUnread, 4);

    final message = await (db.select(db.messages)
          ..where((row) => row.id.equals(_messageId)))
        .getSingle();
    expect(message.body, 'new body');
    expect(message.deletedForMe, isTrue);
    expect(message.status, 3);
    expect(source.messageFetches, 1);
  });

  test('imports realtime messages once and increments unread for incoming',
      () async {
    final at = DateTime.utc(2026, 10, 27, 11);
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: _conversationId,
            type: 'direct',
          ),
        );

    final incoming = RemoteMessage(
      id: _messageId,
      conversationId: _conversationId,
      senderId: _otherId,
      type: 'text',
      body: 'hello',
      seq: 1,
      createdAt: at,
    );
    expect(await service.importMessage(incoming), isTrue);
    expect(await service.importMessage(incoming), isTrue);

    var conversation = await (db.select(db.conversations)
          ..where((row) => row.id.equals(_conversationId)))
        .getSingle();
    expect(conversation.localUnread, 1);
    expect(conversation.lastMessageId, _messageId);

    final own = RemoteMessage(
      id: _ownMessageId,
      conversationId: _conversationId,
      senderId: _myId,
      type: 'text',
      body: 'mine',
      seq: 2,
      createdAt: at.add(const Duration(minutes: 1)),
    );
    await service.importMessage(own);

    conversation = await (db.select(db.conversations)
          ..where((row) => row.id.equals(_conversationId)))
        .getSingle();
    expect(conversation.localUnread, 1);
    final ownMessage = await (db.select(db.messages)
          ..where((row) => row.id.equals(_ownMessageId)))
        .getSingle();
    expect(ownMessage.senderId, 'me');
    expect(ownMessage.status, 1);
  });

  test('applies receipts without downgrading read messages', () async {
    final at = DateTime.utc(2026, 10, 27, 11, 30);
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: _conversationId,
            type: 'direct',
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: _ownMessageId,
            conversationId: _conversationId,
            senderId: 'me',
            type: 'text',
            body: const drift.Value('hello'),
            seq: const drift.Value(1),
            createdAt: at,
          ),
        );

    await service.importReceipt(
      RemoteReceipt(
        messageId: _ownMessageId,
        userId: _otherId,
        deliveredAt: at,
        readAt: at.add(const Duration(seconds: 2)),
      ),
    );

    var message = await (db.select(db.messages)
          ..where((row) => row.id.equals(_ownMessageId)))
        .getSingle();
    expect(message.status, 3);
    final receipt = await (db.select(db.messageReceipts)
          ..where((row) => row.messageId.equals(_ownMessageId)))
        .getSingle();
    expect(receipt.userId, _otherId);
    expect(receipt.readAt, isNotNull);

    await service.importReceipt(
      RemoteReceipt(
        messageId: _ownMessageId,
        userId: _otherId,
        deliveredAt: at.add(const Duration(seconds: 3)),
      ),
    );
    message = await (db.select(db.messages)
          ..where((row) => row.id.equals(_ownMessageId)))
        .getSingle();
    expect(message.status, 3, reason: 'read must never regress to delivered');
  });

  test('propagates remote deletion and clears content', () async {
    final at = DateTime.utc(2026, 10, 27, 12, 15);
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: _conversationId,
            type: 'direct',
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: _messageId,
            conversationId: _conversationId,
            senderId: _otherId,
            type: 'image',
            body: const drift.Value('secret'),
            mediaJson: drift.Value('{"storage_path":"$_storagePath"}'),
            seq: const drift.Value(3),
            createdAt: at,
            status: const drift.Value(3),
          ),
        );

    source.conversations = [
      RemoteConversation(
        id: _conversationId,
        type: 'direct',
        lastMessageId: _messageId,
        lastMessageAt: at,
      ),
    ];
    source.messages[_conversationId] = [
      RemoteMessage(
        id: _messageId,
        conversationId: _conversationId,
        senderId: _otherId,
        type: 'image',
        seq: 3,
        createdAt: at,
        deletedAt: at.add(const Duration(minutes: 1)),
      ),
    ];

    await service.sync();

    final message = await (db.select(db.messages)
          ..where((row) => row.id.equals(_messageId)))
        .getSingle();
    expect(message.deletedEveryone, isTrue);
    expect(message.body, isNull);
    expect(message.mediaJson, isNull);
    expect(message.status, 3);
    expect(source.signedUrls, isEmpty);
  });

  test('loads older pages without duplicating existing messages', () async {
    final at = DateTime.utc(2026, 10, 27, 8);
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: _conversationId,
            type: 'direct',
          ),
        );
    for (final seq in [10, 11]) {
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: '00000000-0000-4000-8000-0000000000$seq',
              conversationId: _conversationId,
              senderId: _otherId,
              type: 'text',
              body: drift.Value('message $seq'),
              seq: drift.Value(seq),
              createdAt: at.add(Duration(minutes: seq)),
            ),
          );
    }
    source.messages[_conversationId] = [
      RemoteMessage(
        id: '00000000-0000-4000-8000-000000000005',
        conversationId: _conversationId,
        senderId: _otherId,
        type: 'text',
        body: 'older 5',
        seq: 5,
        createdAt: at.add(const Duration(minutes: 5)),
      ),
      RemoteMessage(
        id: '00000000-0000-4000-8000-000000000006',
        conversationId: _conversationId,
        senderId: _otherId,
        type: 'text',
        body: 'older 6',
        seq: 6,
        createdAt: at.add(const Duration(minutes: 6)),
      ),
    ];

    expect(await service.syncOlder(_conversationId), 2);
    expect(await service.syncOlder(_conversationId), 0);
    final count = await db.messages.count().getSingle();
    expect(count, 4);
  });

  test('hydrates group membership names and roles', () async {
    final at = DateTime.utc(2026, 10, 27, 12);
    source.conversations = [
      RemoteConversation(
        id: _conversationId,
        type: 'group',
        title: 'Weekend plans',
        updatedAt: at,
      ),
    ];
    source.members = [
      RemoteMember(
        conversationId: _conversationId,
        userId: _myId,
        role: 'owner',
        joinedAt: at,
      ),
      RemoteMember(
        conversationId: _conversationId,
        userId: _otherId,
        role: 'admin',
        joinedAt: at,
      ),
    ];
    source.profiles = [
      RemoteProfile(id: _otherId, displayName: 'Dawit Bekele'),
    ];

    await service.sync();

    final members = await (db.select(db.groupMembers)
          ..where((row) => row.conversationId.equals(_conversationId)))
        .get();
    expect(members.length, 2);
    expect(
      members.singleWhere((row) => row.memberId == _myId).displayName,
      'You',
    );
    final other = members.singleWhere((row) => row.memberId == _otherId);
    expect(other.displayName, 'Dawit Bekele');
    expect(other.role, 'admin');
  });
}

class FakeRemoteChatSource implements RemoteChatSource {
  List<RemoteConversation> conversations = [];
  List<RemoteMember> members = [];
  List<RemoteProfile> profiles = [];
  Map<String, List<RemoteMessage>> messages = {};
  Map<String, List<RemoteReceipt>> receipts = {};
  Map<String, String> signedUrls = {};
  int messageFetches = 0;

  @override
  Future<List<RemoteConversation>> fetchConversations({int limit = 50}) async {
    return conversations;
  }

  @override
  Future<List<RemoteMember>> fetchMembers(List<String> conversationIds) async {
    return members
        .where((member) => conversationIds.contains(member.conversationId))
        .toList(growable: false);
  }

  @override
  Future<List<RemoteProfile>> fetchProfiles(Set<String> userIds) async {
    return profiles
        .where((profile) => userIds.contains(profile.id))
        .toList(growable: false);
  }

  @override
  Future<List<RemoteMessage>> fetchMessages(
    String conversationId, {
    int limit = 50,
    int? beforeSeq,
  }) async {
    messageFetches++;
    final rows = messages[conversationId] ?? const <RemoteMessage>[];
    return rows
        .where((row) => beforeSeq == null || (row.seq ?? 0) < beforeSeq)
        .toList(growable: false);
  }

  @override
  Future<List<RemoteReceipt>> fetchReceipts(List<String> messageIds) async {
    return [
      for (final row in receipts.values.expand((rows) => rows))
        if (messageIds.contains(row.messageId)) row,
    ];
  }

  @override
  Future<Map<String, String>> signedMediaUrls(
    Iterable<String> paths,
  ) async {
    return {
      for (final path in paths)
        if (signedUrls[path] != null) path: signedUrls[path]!,
    };
  }

  @override
  void subscribe({
    required void Function(RemoteMessage message) onMessage,
    void Function(RemoteMessage message)? onMessageUpdated,
    void Function(RemoteReceipt receipt)? onReceipt,
    void Function(RemoteConversation conversation)? onConversation,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {}

  @override
  Future<void> dispose() async {}
}
