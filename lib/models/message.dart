import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// In-app message within a conversation
@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    @JsonKey(name: 'conversation_id') required String conversationId,
    @JsonKey(name: 'sender_id') required String senderId,
    required String body,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
