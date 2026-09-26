import 'package:ai_chat/models/chat.dart';
import 'package:ai_chat/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chat сохраняется в JSON и восстанавливается', () {
    final chat = Chat(
      id: 'c1',
      title: 'Тест',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      messages: [
        ChatMessage(
          id: 'm1',
          role: MessageRole.user,
          text: 'Вопрос',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1500),
        ),
        ChatMessage(
          id: 'm2',
          role: MessageRole.assistant,
          text: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1600),
          error: 'Ошибка',
        ),
      ],
    );

    final restored = Chat.fromJson(chat.toJson());
    expect(restored.id, 'c1');
    expect(restored.title, 'Тест');
    expect(restored.updatedAt, chat.updatedAt);
    expect(restored.messages, hasLength(2));
    expect(restored.messages.first.isUser, isTrue);
    expect(restored.messages.last.error, 'Ошибка');
  });
}
