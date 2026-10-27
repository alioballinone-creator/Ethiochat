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
  BoolColumn get deletedEveryone =>
      boolean().withDefault(const Constant(false))();

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

@DataClassName('ContactRow')
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

/// Cached wallet transaction list. The immutable double-entry ledger is the
/// source of truth for the balance; rows here make the local timeline fast.
@DataClassName('WalletTransaction')
class WalletTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('me'))();
  TextColumn get type => text()();
  TextColumn get status => text().withDefault(const Constant('success'))();
  IntColumn get amountMinor => integer()();
  TextColumn get direction => text()();
  TextColumn get counterparty => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get idempotencyKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local mirror of `public.ledger_entries`; every transaction writes two rows.
@DataClassName('LedgerEntry')
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get txnId => text()();
  TextColumn get account => text()();
  TextColumn get direction => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('ETB'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GroupMember')
class GroupMembers extends Table {
  TextColumn get conversationId => text()();
  TextColumn get memberId => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text().withDefault(const Constant('member'))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {conversationId, memberId};
}

@DataClassName('ReportRow')
class Reports extends Table {
  TextColumn get id => text()();
  TextColumn get targetId => text()();
  TextColumn get targetName => text()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Locally cached moments. Comments and likes cascade with the post.
@DataClassName('MomentRow')
class MomentsLocal extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get body => text().nullable()();
  TextColumn get mediaJson => text().nullable()();
  TextColumn get visibility => text().withDefault(const Constant('friends'))();
  IntColumn get likeCount => integer().withDefault(const Constant(0))();
  IntColumn get commentCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MomentLikeRow')
class MomentLikes extends Table {
  TextColumn get momentId =>
      text().references(MomentsLocal, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {momentId, userId};
}

@DataClassName('MomentCommentRow')
class MomentComments extends Table {
  TextColumn get id => text()();
  TextColumn get momentId =>
      text().references(MomentsLocal, #id, onDelete: KeyAction.cascade)();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
