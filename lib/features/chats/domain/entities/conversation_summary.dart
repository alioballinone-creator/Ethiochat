import 'conversation_entity.dart';

/// A conversation plus the last message preview used by the chat list.
class ConversationSummary {
  const ConversationSummary({
    required this.conversation,
    this.preview = 'No messages yet',
    this.lastMessageAt,
    this.lastMessageType,
  });

  final ConversationEntity conversation;
  final String preview;
  final DateTime? lastMessageAt;
  final String? lastMessageType;

  String get id => conversation.id;
  String get title => conversation.title ?? 'Chat';
  int get unread => conversation.unread;
  bool get pinned => conversation.pinned;
  bool get archived => conversation.archived;
  bool get muted => conversation.mutedUntil != null;
  ConversationType get type => conversation.type;
}
