import 'dart:async';

import 'package:ai_chat/models/ai_provider_type.dart';
import 'package:ai_chat/models/app_settings.dart';
import 'package:ai_chat/models/chat.dart';
import 'package:ai_chat/models/chat_message.dart';
import 'package:ai_chat/providers/app_providers.dart';
import 'package:ai_chat/providers/chat_controller.dart';
import 'package:ai_chat/providers/streaming_provider.dart';
import 'package:ai_chat/services/ai/ai_provider.dart';
import 'package:ai_chat/services/storage/chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryChatRepository implements ChatRepository {
  final chats = <String, Chat>{};

  @override
  List<Chat> loadAll() => chats.values.toList();

  @override
  Future<void> save(Chat chat) async => chats[chat.id] = chat;

  @override
  Future<void> delete(String id) async => chats.remove(id);

  @override
  Future<void> clear() async => chats.clear();
}

class _FakeAi implements AiProvider {
  final controller = StreamController<String>();
  List<ChatMessage>? lastHistory;
  String? lastSystemPrompt;

  @override
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    lastHistory = history;
    lastSystemPrompt = systemPrompt;
    return controller.stream;
  }

  @override
  Future<List<String>> listModels(String apiKey) async => [];
}

void main() {
  late _FakeAi ai;
  late _MemoryChatRepository repo;
  late ProviderContainer container;

  setUp(() {
    ai = _FakeAi();
    repo = _MemoryChatRepository();
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            aboutMe: 'Меня зовут Аня',
            apiKeys: {AiProviderType.gemini: 'key'},
          ),
        ),
        aiProviderFactory.overrideWithValue((_) => ai),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('ответ печатается постепенно и сохраняется в чат', () async {
    final controller = container.read(chatControllerProvider.notifier);
    await controller.sendMessage('Привет');

    expect(container.read(chatControllerProvider).isGenerating, isTrue);
    expect(ai.lastHistory!.single.text, 'Привет');
    expect(ai.lastSystemPrompt, contains('Меня зовут Аня'));

    ai.controller.add('Здравствуйте! Чем могу помочь?');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final partial = container.read(streamingProvider)!.text;
    expect(partial, isNotEmpty);
    expect(partial.length, lessThan('Здравствуйте! Чем могу помочь?'.length));

    await ai.controller.close();
    while (container.read(chatControllerProvider).isGenerating) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final chat = container.read(chatControllerProvider).currentChat!;
    expect(chat.title, 'Привет');
    expect(chat.messages.map((m) => m.text), [
      'Привет',
      'Здравствуйте! Чем могу помочь?',
    ]);
    expect(repo.chats[chat.id]!.messages, hasLength(2));
    expect(container.read(streamingProvider), isNull);
  });

  test('«Стоп» прерывает генерацию и сохраняет показанный текст', () async {
    final controller = container.read(chatControllerProvider.notifier);
    await controller.sendMessage('Расскажи историю');
    ai.controller.add('Жили-были ');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    controller.stopGeneration();

    final state = container.read(chatControllerProvider);
    expect(state.isGenerating, isFalse);
    expect(state.currentChat!.messages.last.text, 'Жили-были ');
  });
}
