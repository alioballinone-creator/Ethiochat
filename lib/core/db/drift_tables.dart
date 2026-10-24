import 'package:drift/drift.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get lastMessageId => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get localUnread => integer().withDefault(const Constant(0))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get mutedUntil => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get senderId => text()();
  IntColumn get seq => integer().nullable()();
  TextColumn get type => text()();
  TextColumn get body => text().nullable()();
  TextColumn get mediaJson => text().nullable()();
  TextColumn get replyTo => text().nullable()();
  DateTimeColumn get editedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  BoolColumn get deletedForMe => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedEveryone => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MessageReceipts extends Table {
  TextColumn get messageId => text().references(Messages, #id)();
  TextColumn get userId => text()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {messageId, userId};
}

class Outbox extends Table {
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class ContactsLocal extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get phoneE164 => text().nullable()();
  TextColumn get ethioId => text().nullable()();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
