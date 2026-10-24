import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_entity.freezed.dart';

enum MessageStatus { pending, sent, delivered, read, failed }

enum MessageType {
  text,
  image,
  voice,
  video,
  file,
  location,
  contact,
  sticker,
  payment,
  redpacket,
  system
}

@freezed
class MessageEntity with _$MessageEntity {
  const factory MessageEntity({
    required String id,
    required String conversationId,
    required String senderId,
    int? seq,
    required MessageType type,
    String? body,
    Map<String, dynamic>? media,
    String? replyTo,
    DateTime? editedAt,
    required DateTime createdAt,
    @Default(MessageStatus.pending) MessageStatus status,
    @Default(false) bool deletedForMe,
    @Default(false) bool deletedEveryone,
  }) = _MessageEntity;
}
