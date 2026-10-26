import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../contacts/domain/entities/contact_entity.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../domain/entities/conversation_entity.dart';
import '../domain/entities/conversation_summary.dart';
import '../domain/entities/message_entity.dart';
import '../domain/repositories/chat_repository.dart';

/// The single entry point the UI uses for all chat persistence.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Conversation list, ordered by pinned then most recent activity.
final conversationSummariesProvider =
    StreamProvider.autoDispose<List<ConversationSummary>>((ref) {
  return ref.watch(chatRepositoryProvider).watchSummaries();
});

final conversationProvider =
    StreamProvider.autoDispose.family<ConversationEntity?, String>(
  (ref, conversationId) {
    return ref.watch(chatRepositoryProvider).watchConversation(conversationId);
  },
);

final messagesProvider =
    StreamProvider.autoDispose.family<List<MessageEntity>, String>(
  (ref, conversationId) {
    return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
  },
);

final contactsProvider = StreamProvider.autoDispose<List<ContactEntity>>((ref) {
  return ref.watch(chatRepositoryProvider).watchContacts();
});

/// Seeds the local database with demo content on first launch.
/// Idempotent: does nothing once conversations exist.
final demoSeedProvider = FutureProvider<void>((ref) {
  return ref.watch(chatRepositoryProvider).seedDemoData();
});

final messageSearchProvider =
    FutureProvider.autoDispose.family<List<MessageEntity>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return const [];
    final result =
        await ref.watch(chatRepositoryProvider).searchMessages(query);
    return result.valueOrNull ?? const [];
  },
);
