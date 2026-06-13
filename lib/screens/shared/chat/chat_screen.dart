import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/conversation.dart';
import '../../../models/message.dart';
import '../../../providers/message_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../../../repositories/message_repository.dart';
import '../../../widgets/message_bubble.dart';

/// Per-booking chat screen shared by customers and drivers.
class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String? title;

  const ChatScreen({super.key, required this.bookingId, this.title});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Mark the conversation as read and refresh unread badges. Scheduled in a
  /// post-frame callback so it never runs during build.
  void _markRead(String conversationId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(messageRepositoryProvider).markRead(conversationId);
        ref.invalidate(unreadCountsProvider);
      } catch (_) {
        // Non-critical; ignore mark-read failures.
      }
    });
  }

  Future<void> _send(String conversationId) async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .sendMessage(conversationId: conversationId, body: text);
      _inputController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync = ref.watch(conversationProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Chat'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
      ),
      body: SafeArea(
        child: conversationAsync.when(
          data: (conversation) => _buildChat(context, conversation),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(context),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          const Text('Unable to load this conversation'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                ref.invalidate(conversationProvider(widget.bookingId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(BuildContext context, Conversation conversation) {
    final currentUserId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final messagesAsync = ref.watch(messagesStreamProvider(conversation.id));

    // Mark read when messages arrive (and on first resolve) while open.
    ref.listen<AsyncValue<List<Message>>>(
      messagesStreamProvider(conversation.id),
      (previous, next) {
        final messages = next.valueOrNull;
        if (messages != null && messages.isNotEmpty) {
          _markRead(conversation.id);
        }
      },
    );

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return _buildEmptyState(context);
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  // reverse:true -> render newest first from the end of list.
                  final message = messages[messages.length - 1 - index];
                  return MessageBubble(
                    body: message.body,
                    createdAt: message.createdAt,
                    isMine: message.senderId == currentUserId,
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load messages.\n${error.toString()}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        _buildInputBar(context, conversation.id),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Say hello! 👋',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, String conversationId) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSendButton(conversationId),
        ],
      ),
    );
  }

  Widget _buildSendButton(String conversationId) {
    final canSend = _inputController.text.trim().isNotEmpty && !_isSending;
    return Material(
      color: canSend ? AppColors.accent : AppColors.disabled,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: canSend ? () => _send(conversationId) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.send, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}
