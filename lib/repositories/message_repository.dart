import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../providers/supabase_provider.dart';

/// Provider for MessageRepository
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MessageRepository(client);
});

/// Repository for in-app messaging (conversations + messages)
class MessageRepository {
  final SupabaseClient _client;

  MessageRepository(this._client);

  SupabaseQueryBuilder get _messages => _client.from('messages');

  /// Get current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Open (or create) the conversation for a booking.
  ///
  /// Calls the `get_or_create_conversation` RPC, which validates the
  /// participant and messageable status server-side (throws otherwise).
  Future<Conversation> openConversation(String bookingId) async {
    final response = await _client.rpc(
      'get_or_create_conversation',
      params: {'p_booking_id': bookingId},
    );

    // The RPC may return a single object or a one-element list depending
    // on shape; handle both defensively.
    final Map<String, dynamic> row = response is List
        ? response.first as Map<String, dynamic>
        : response as Map<String, dynamic>;

    return Conversation.fromJson(row);
  }

  /// Watch messages in a conversation via Supabase Realtime, ordered oldest
  /// to newest.
  Stream<List<Message>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((j) => Message.fromJson(j)).toList());
  }

  /// One-shot fetch of a conversation's message history (MSG-09),
  /// ordered by `created_at` ascending.
  Future<List<Message>> getMessages(String conversationId) async {
    final response = await _messages
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => Message.fromJson(json))
        .toList();
  }

  /// Send a message into a conversation. Fires a push notification
  /// (fire-and-forget) after the insert succeeds.
  Future<Message> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _messages
        .insert({
          'conversation_id': conversationId,
          'sender_id': _currentUserId,
          'body': body,
        })
        .select()
        .single();

    final message = Message.fromJson(response);

    // Notify the recipient (fire-and-forget)
    _notifyNewMessage(message.id);

    return message;
  }

  /// Send new-message push notification (fire-and-forget)
  void _notifyNewMessage(String messageId) {
    _client.functions.invoke(
      'notify-new-message',
      body: {'messageId': messageId},
    ).then((_) {
      developer.log(
        'New message push sent for $messageId',
        name: 'MessageRepository',
      );
    }).catchError((e) {
      developer.log(
        'Error sending new message push',
        name: 'MessageRepository',
        error: e,
      );
    });
  }

  /// Mark a conversation as read for the current user.
  Future<void> markRead(String conversationId) async {
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  /// Get unread message counts for the current user, keyed by booking ID.
  ///
  /// Returns an empty map when there are no unread messages.
  Future<Map<String, int>> getUnreadCounts() async {
    final response = await _client.rpc('get_my_unread_counts');

    final rows = response as List;
    return rows.fold<Map<String, int>>({}, (map, row) {
      map[row['booking_id'] as String] = row['unread_count'] as int;
      return map;
    });
  }
}
