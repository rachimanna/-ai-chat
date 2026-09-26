import 'package:ai_chat/main.dart';
import 'package:ai_chat/models/app_settings.dart';
import 'package:ai_chat/models/chat.dart';
import 'package:ai_chat/providers/app_providers.dart';
import 'package:ai_chat/services/storage/chat_repository.dart';
import 'package:ai_chat/widgets/code_block.dart';
import 'package:ai_chat/widgets/markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Хранилище в памяти вместо Hive.
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

void main() {
  testWidgets('без ключа: приветствие и отправка показывают ошибку', (
    tester,
  ) async {
    final repo = _MemoryChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
        ],
        child: const AiChatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Чем могу помочь?'), findsOneWidget);
    expect(find.textContaining('API-ключ в настройках'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Привет');
    await tester.pump();
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();

    expect(find.text('Привет'), findsWidgets);
    expect(find.textContaining('API-ключ не указан'), findsOneWidget);
    expect(repo.loadAll(), hasLength(1));
  });

  testWidgets('Markdown: блок кода с кнопкой «Копировать»', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownView(
              text:
                  '# Заголовок\n\n**жирный** и список:\n\n- раз\n- два\n\n'
                  '```python\nprint("hi")\n```',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.text('python'), findsOneWidget);
    expect(find.text('Копировать'), findsOneWidget);
  });
}
