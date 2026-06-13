import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../repositories/message_repository.dart';

/// Opens (or creates) the conversation for a booking. Family keyed by bookingId.
final conversationProvider = FutureProvider.family<Conversation, String>((ref, bookingId) async {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.openConversation(bookingId);
});

/// Live message stream for a conversation. Family keyed by conversationId.
final messagesStreamProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchMessages(conversationId);
});

/// Map of bookingId -> unread message count for the current user (for badges).
final unreadCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.getUnreadCounts();
});
