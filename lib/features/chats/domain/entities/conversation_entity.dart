import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_entity.freezed.dart';

enum ConversationType { direct, group, channel }

@freezed
class ConversationEntity with _$ConversationEntity {
  const factory ConversationEntity({
    required String id,
    required ConversationType type,
    String? title,
    String? avatarUrl,
    String? lastMessageId,
    DateTime? lastMessageAt,
    @Default(0) int unread,
    @Default(false) bool pinned,
    @Default(false) bool archived,
    DateTime? mutedUntil,
  }) = _ConversationEntity;
}
