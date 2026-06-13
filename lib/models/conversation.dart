import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

/// Conversation between a customer and driver (one per booking)
@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    @JsonKey(name: 'booking_id') required String bookingId,
    @JsonKey(name: 'customer_id') required String customerId,
    @JsonKey(name: 'driver_id') required String driverId,
    @JsonKey(name: 'last_message_at') DateTime? lastMessageAt,
    @JsonKey(name: 'last_message_preview') String? lastMessagePreview,
    @JsonKey(name: 'customer_last_read_at') DateTime? customerLastReadAt,
    @JsonKey(name: 'driver_last_read_at') DateTime? driverLastReadAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}
