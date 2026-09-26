import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Текст ответа, который ИИ печатает прямо сейчас.
///
/// Вынесен в отдельный провайдер, чтобы при каждом новом куске текста
/// перерисовывалось только одно сообщение, а не весь список (60 fps).
class StreamingState {
  const StreamingState({required this.chatId, this.text = ''});

  final String chatId;
  final String text;
}

final streamingProvider = NotifierProvider<StreamingNotifier, StreamingState?>(
  StreamingNotifier.new,
);

class StreamingNotifier extends Notifier<StreamingState?> {
  @override
  StreamingState? build() => null;

  void start(String chatId) => state = StreamingState(chatId: chatId);

  void setText(String text) {
    final current = state;
    if (current != null) {
      state = StreamingState(chatId: current.chatId, text: text);
    }
  }

  void clear() => state = null;
}
