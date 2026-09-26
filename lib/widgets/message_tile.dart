import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'appear_animation.dart';
import 'markdown_view.dart';
import 'typing_indicator.dart';

/// Одно сообщение: пользователь — справа в сером пузыре,
/// ИИ — слева во всю ширину, без пузыря.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.message,
    this.onRetry,
    this.animate = false,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AppearAnimation(
      enabled: animate,
      child: message.isUser
          ? UserBubble(text: message.text)
          : AssistantMessage(
              text: message.text,
              error: message.error,
              onRetry: onRetry,
            ),
    );
  }
}

class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 10, 16, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: GestureDetector(
            onLongPress: () => _copyText(context, text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AssistantMessage extends StatelessWidget {
  const AssistantMessage({
    super.key,
    required this.text,
    this.error,
    this.onRetry,
    this.isStreaming = false,
  });

  final String text;
  final String? error;
  final VoidCallback? onRetry;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isEmpty && isStreaming)
            const TypingIndicator()
          else if (text.isNotEmpty)
            SelectionArea(child: MarkdownView(text: text)),
          if (error != null) ...[
            if (text.isNotEmpty) const SizedBox(height: 8),
            _ErrorCard(message: error!, onRetry: onRetry),
          ],
          if (!isStreaming && text.isNotEmpty && error == null)
            _MessageActions(text: text),
        ],
      ),
    );
  }
}

class _MessageActions extends StatelessWidget {
  const _MessageActions({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: IconButton(
        tooltip: 'Копировать ответ',
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        color: AppColors.textMuted,
        onPressed: () => _copyText(context, text),
        icon: const Icon(Icons.copy_rounded),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final parts = message.split('\n\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  parts.first,
                  style: const TextStyle(color: AppColors.text, height: 1.4),
                ),
              ),
            ],
          ),
          if (parts.length > 1) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                parts.skip(1).join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: AppColors.text),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Повторить'),
              ),
            ),
        ],
      ),
    );
  }
}

void _copyText(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Скопировано'),
        duration: Duration(seconds: 1),
      ),
    );
}
