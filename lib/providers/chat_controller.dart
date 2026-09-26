import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app_config.dart';
import '../models/app_settings.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../services/ai/ai_exception.dart';
import 'app_providers.dart';
import 'settings_provider.dart';
import 'streaming_provider.dart';

const _uuid = Uuid();

class ChatState {
  const ChatState({
    this.chats = const [],
    this.currentChatId,
    this.generatingChatId,
  });

  /// Все чаты, новые сверху.
  final List<Chat> chats;

  /// Открытый чат. null — новый пустой чат (приветственный экран).
  final String? currentChatId;

  /// Чат, для которого сейчас генерируется ответ.
  final String? generatingChatId;

  bool get isGenerating => generatingChatId != null;

  Chat? get currentChat => chatById(currentChatId);

  Chat? chatById(String? id) {
    if (id == null) return null;
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  ChatState copyWith({
    List<Chat>? chats,
    String? Function()? currentChatId,
    String? Function()? generatingChatId,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      currentChatId: currentChatId != null
          ? currentChatId()
          : this.currentChatId,
      generatingChatId: generatingChatId != null
          ? generatingChatId()
          : this.generatingChatId,
    );
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  StreamSubscription<String>? _subscription;
  Timer? _revealTimer;

  /// Текст, уже показанный пользователю.
  String _shown = '';

  /// Текст, полученный от API, но ещё не показанный (плавное «печатание»).
  final StringBuffer _pending = StringBuffer();
  bool _streamDone = false;
  AiException? _streamError;

  @override
  ChatState build() {
    ref.onDispose(_cancelStreaming);
    return ChatState(chats: ref.read(chatRepositoryProvider).loadAll());
  }

  // ---------------------------------------------------------------- Чаты

  void newChat() {
    state = state.copyWith(currentChatId: () => null);
  }

  void selectChat(String id) {
    state = state.copyWith(currentChatId: () => id);
  }

  Future<void> renameChat(String id, String title) async {
    final chat = state.chatById(id);
    final trimmed = title.trim();
    if (chat == null || trimmed.isEmpty) return;
    await _putChat(chat.copyWith(title: trimmed), bumpToTop: false);
  }

  Future<void> deleteChat(String id) async {
    if (state.generatingChatId == id) stopGeneration();
    state = state.copyWith(
      chats: state.chats.where((c) => c.id != id).toList(),
      currentChatId: state.currentChatId == id ? () => null : null,
    );
    await ref.read(chatRepositoryProvider).delete(id);
  }

  Future<void> clearAll() async {
    stopGeneration();
    await ref.read(chatRepositoryProvider).clear();
    await ref.read(settingsRepositoryProvider).clear();
    ref.read(settingsProvider.notifier).reset();
    state = const ChatState();
  }

  // ------------------------------------------------------------ Сообщения

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isGenerating) return;

    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: trimmed,
      createdAt: now,
    );

    var chat = state.currentChat;
    if (chat == null) {
      chat = Chat(
        id: _uuid.v4(),
        title: _titleFrom(trimmed),
        createdAt: now,
        updatedAt: now,
        messages: [userMessage],
      );
    } else {
      chat = chat.copyWith(
        updatedAt: now,
        messages: [...chat.messages, userMessage],
        title: chat.messages.isEmpty ? _titleFrom(trimmed) : null,
      );
    }
    state = state.copyWith(currentChatId: () => chat!.id);
    await _putChat(chat);
    _generate(chat.id);
  }

  /// Повторить последний ответ, если он завершился ошибкой.
  Future<void> retry() async {
    final chat = state.currentChat;
    if (chat == null || state.isGenerating || chat.messages.isEmpty) return;
    final messages = [...chat.messages];
    if (!messages.last.isUser) messages.removeLast();
    await _putChat(chat.copyWith(messages: messages), bumpToTop: false);
    _generate(chat.id);
  }

  void stopGeneration() {
    if (!state.isGenerating) return;
    _subscription?.cancel();
    _subscription = null;
    _pending.clear();
    _streamDone = true;
    _finish();
  }

  // ------------------------------------------------------------ Генерация

  void _generate(String chatId) {
    final chat = state.chatById(chatId);
    if (chat == null) return;
    final settings = ref.read(settingsProvider);

    _shown = '';
    _pending.clear();
    _streamDone = false;
    _streamError = null;
    state = state.copyWith(generatingChatId: () => chatId);
    ref.read(streamingProvider.notifier).start(chatId);

    if (!settings.hasApiKey) {
      _streamError = const AiException(AiErrorKind.noKey);
      _streamDone = true;
      _finish();
      return;
    }

    // В API отправляем всю историю чата (контекст), кроме неудачных ответов.
    final history = chat.messages
        .where((m) => !m.hasError || m.text.isNotEmpty)
        .where((m) => m.text.trim().isNotEmpty)
        .toList();

    final stream = ref
        .read(aiProviderFactory)(settings.provider)
        .streamChat(
          apiKey: settings.apiKey.trim(),
          model: settings.model,
          systemPrompt: _systemPrompt(settings),
          history: history,
        );

    _subscription = stream.listen(
      _pending.write,
      onError: (Object e) {
        _streamError = AiException.from(e);
        _streamDone = true;
      },
      onDone: () => _streamDone = true,
      cancelOnError: true,
    );
    _revealTimer = Timer.periodic(const Duration(milliseconds: 32), _reveal);
  }

  /// Постепенно показывает накопленный текст — эффект печатания.
  void _reveal(Timer _) {
    if (_pending.isNotEmpty) {
      final pending = _pending.toString();
      // Чем больше накопилось, тем быстрее догоняем.
      var take = math.min(
        pending.length,
        math.max(3, (pending.length / 6).ceil()),
      );
      // Не разрываем суррогатную пару (эмодзи).
      if (take < pending.length &&
          pending.codeUnitAt(take - 1) >= 0xD800 &&
          pending.codeUnitAt(take - 1) <= 0xDBFF) {
        take++;
      }
      _shown += pending.substring(0, take);
      _pending
        ..clear()
        ..write(pending.substring(take));
      ref.read(streamingProvider.notifier).setText(_shown);
    } else if (_streamDone) {
      _finish();
    }
  }

  void _finish() {
    final chatId = state.generatingChatId;
    _revealTimer?.cancel();
    _revealTimer = null;
    _subscription = null;
    if (chatId == null) return;

    final error = _streamError;
    final chat = state.chatById(chatId);
    if (chat != null && (_shown.isNotEmpty || error != null)) {
      final reply = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: _shown,
        createdAt: DateTime.now(),
        error: error == null
            ? null
            : error.details == null
            ? error.message
            : '${error.message}\n\n${error.details}',
      );
      _putChat(
        chat.copyWith(
          messages: [...chat.messages, reply],
          updatedAt: DateTime.now(),
        ),
      );
    }
    state = state.copyWith(generatingChatId: () => null);
    ref.read(streamingProvider.notifier).clear();
    _shown = '';
  }

  void _cancelStreaming() {
    _subscription?.cancel();
    _revealTimer?.cancel();
  }

  // ------------------------------------------------------------ Помощники

  Future<void> _putChat(Chat chat, {bool bumpToTop = true}) async {
    final others = state.chats.where((c) => c.id != chat.id).toList();
    final List<Chat> chats;
    if (bumpToTop) {
      chats = [chat, ...others];
    } else {
      chats = [...state.chats];
      final i = chats.indexWhere((c) => c.id == chat.id);
      if (i >= 0) {
        chats[i] = chat;
      } else {
        chats.insert(0, chat);
      }
    }
    state = state.copyWith(chats: chats);
    await ref.read(chatRepositoryProvider).save(chat);
  }

  static String _titleFrom(String text) {
    final line = text.split('\n').first.trim();
    return line.length > 40 ? '${line.substring(0, 40).trimRight()}…' : line;
  }

  static String _systemPrompt(AppSettings s) {
    final buffer = StringBuffer(AppConfig.baseSystemPrompt);
    final about = s.aboutMe.trim();
    if (about.isNotEmpty) {
      buffer
        ..write('\n\nИнформация о пользователе (учитывай её в ответах):\n')
        ..write(about);
    }
    return buffer.toString();
  }
}
