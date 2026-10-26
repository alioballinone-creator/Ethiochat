import '../../../../core/errors/result.dart';
import '../../../contacts/domain/entities/contact_entity.dart';
import '../entities/conversation_entity.dart';
import '../entities/conversation_summary.dart';
import '../entities/message_entity.dart';

/// Local-first chat data access. Every mutation writes to Drift first and is
/// reflected to the UI through streams, so the app keeps working offline.
abstract class ChatRepository {
  Stream<List<ConversationSummary>> watchSummaries();
  Stream<ConversationEntity?> watchConversation(String conversationId);
  Stream<List<MessageEntity>> watchMessages(String conversationId);
  Stream<List<ContactEntity>> watchContacts();

  Future<Result<MessageEntity>> sendMessage({
    required String conversationId,
    required MessageType type,
    String? body,
    Map<String, dynamic>? media,
    String? replyTo,
  });

  Future<Result<ConversationEntity>> ensureConversation(String id);
  Future<Result<ConversationEntity>> openDirectChat(String displayName);
  Future<Result<ConversationEntity>> createGroup(
    String title,
    List<String> memberNames,
  );

  Future<Result<void>> markRead(String conversationId, int lastReadSeq);
  Future<Result<void>> retryFailed(String messageId);
  Future<Result<void>> setPinned(String conversationId, bool pinned);
  Future<Result<void>> setMuted(String conversationId, bool muted);
  Future<Result<void>> setArchived(String conversationId, bool archived);
  Future<Result<void>> clearMessages(String conversationId);
  Future<Result<void>> deleteConversation(String conversationId);

  Future<Result<ContactEntity>> addContact({
    required String displayName,
    String? phoneE164,
  });

  Future<Result<List<MessageEntity>>> searchMessages(String query);
  Future<void> seedDemoData();
}
