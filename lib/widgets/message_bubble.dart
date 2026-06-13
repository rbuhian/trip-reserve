import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';

/// A single chat message bubble. Styled differently for the current user's
/// own messages ("mine", right-aligned, primary-tinted) versus the other
/// party's messages ("theirs", left-aligned, neutral surface).
class MessageBubble extends StatelessWidget {
  final String body;
  final DateTime createdAt;
  final bool isMine;

  const MessageBubble({
    super.key,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    final Color bubbleColor = isMine
        ? AppColors.primary
        : colorScheme.surfaceContainerHighest;
    final Color textColor = isMine ? AppColors.white : colorScheme.onSurface;
    final Color timeColor = isMine
        ? AppColors.white.withOpacity(0.7)
        : colorScheme.onSurfaceVariant;

    const radius = Radius.circular(16);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isMine ? radius : const Radius.circular(4),
      bottomRight: isMine ? const Radius.circular(4) : radius,
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: isMine
              ? null
              : Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              style: TextStyle(
                fontSize: 15,
                height: 1.3,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(createdAt),
              style: TextStyle(
                fontSize: 10.5,
                color: timeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
