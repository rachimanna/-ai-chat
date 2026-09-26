import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_config.dart';
import '../models/chat_message.dart';
import '../providers/chat_controller.dart';
import '../providers/settings_provider.dart';
import '../providers/streaming_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/appear_animation.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_tile.dart';
import '../widgets/welcome_view.dart';
import 'settings_screen.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider.select((s) => s.currentChat));
    final isGenerating = ref.watch(
      chatControllerProvider.select((s) => s.isGenerating),
    );
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    return Scaffold(
      drawer: const ChatDrawer(),
      drawerEdgeDragWidth: 40,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Меню',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(chat?.title),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chat?.title ?? AppConfig.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                settings.model,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Новый чат',
            icon: const Icon(Icons.edit_square),
            onPressed: chat == null ? null : controller.newChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: chat == null || chat.isEmpty
                    ? WelcomeView(
                        key: const ValueKey('welcome'),
                        showKeyHint: !settings.hasApiKey,
                        onOpenSettings: () => _openSettings(context),
                        onSuggestion: controller.sendMessage,
                      )
                    : _MessageList(
                        key: ValueKey(chat.id),
                        chatId: chat.id,
                        messages: chat.messages,
                        onRetry: controller.retry,
                      ),
              ),
            ),
          ),
          ChatInput(
            isGenerating: isGenerating,
            onSend: controller.sendMessage,
            onStop: controller.stopGeneration,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends ConsumerStatefulWidget {
  const _MessageList({
    super.key,
    required this.chatId,
    required this.messages,
    required this.onRetry,
  });

  final String chatId;
  final List<ChatMessage> messages;
  final VoidCallback onRetry;

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  final _scroll = ScrollController();
  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 300;
      if (show != _showScrollDown) setState(() => _showScrollDown = show);
    });
  }

  @override
  void didUpdateWidget(_MessageList old) {
    super.didUpdateWidget(old);
    // Новое сообщение пользователя — мягко прокручиваем вниз.
    if (widget.messages.length > old.messages.length &&
        widget.messages.last.isUser &&
        _scroll.hasClients &&
        _scroll.offset > 0) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStreamingHere = ref.watch(
      streamingProvider.select((s) => s?.chatId == widget.chatId),
    );
    final messages = widget.messages;
    final extra = isStreamingHere ? 1 : 0;
    final lastIndex = messages.length - 1;
    final now = DateTime.now();

    return Stack(
      children: [
        // reverse: true — список «прилипает» к низу, и новые токены
        // не требуют ручной прокрутки.
        ListView.builder(
          controller: _scroll,
          reverse: true,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          itemCount: messages.length + extra,
          itemBuilder: (context, index) {
            if (isStreamingHere && index == 0) {
              return const _StreamingMessage(key: ValueKey('streaming'));
            }
            final i = lastIndex - (index - extra);
            final m = messages[i];
            return MessageTile(
              key: ValueKey(m.id),
              message: m,
              animate:
                  m.isUser &&
                  now.difference(m.createdAt) < const Duration(seconds: 2),
              onRetry: i == lastIndex && m.hasError ? widget.onRetry : null,
            );
          },
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedScale(
              scale: _showScrollDown ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Material(
                color: AppColors.surfaceHigh,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.border),
                ),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Вниз',
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  onPressed: _scrollToBottom,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ответ, который печатается прямо сейчас. Перерисовывается только он.
class _StreamingMessage extends ConsumerWidget {
  const _StreamingMessage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(streamingProvider.select((s) => s?.text ?? ''));
    return AppearAnimation(
      child: RepaintBoundary(
        child: AssistantMessage(text: text, isStreaming: true),
      ),
    );
  }
}
