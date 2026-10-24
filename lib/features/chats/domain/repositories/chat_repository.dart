import '../../../../core/errors/result.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

abstract class ChatRepository {
  Stream<List<ConversationEntity>> watchConversations();
  Stream<List<MessageEntity>> watchMessages(String conversationId);
  Future<Result<MessageEntity>> sendMessage({
    required String conversationId,
    required MessageType type,
    String? body,
    Map<String, dynamic>? media,
    String? replyTo,
  });
  Future<Result<void>> markRead(String conversationId, int lastReadSeq);
  Future<Result<void>> retryFailed(String messageId);
}
