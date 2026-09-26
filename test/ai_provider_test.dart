import 'dart:convert';
import 'dart:io';

import 'package:ai_chat/models/chat_message.dart';
import 'package:ai_chat/services/ai/ai_exception.dart';
import 'package:ai_chat/services/ai/openai_compatible_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Поднимает локальный HTTP-сервер, имитирующий OpenAI-совместимый API.
Future<HttpServer> _server(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

final _history = [
  ChatMessage(
    id: '1',
    role: MessageRole.user,
    text: 'Привет',
    createdAt: DateTime(2024),
  ),
];

void main() {
  test('потоковый ответ собирается из SSE-кусков', () async {
    Map<String, dynamic>? sentBody;
    final server = await _server((req) async {
      sentBody = jsonDecode(
        await utf8.decoder.bind(req).join(),
      ) as Map<String, dynamic>;
      req.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      for (final piece in ['При', 'вет', '! 👋']) {
        req.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': piece},
              },
            ],
          })}\n\n',
        );
        await req.response.flush();
      }
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
    });
    addTearDown(server.close);

    final provider = OpenAiCompatibleProvider(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    final chunks = await provider
        .streamChat(
          apiKey: 'k',
          model: 'm',
          systemPrompt: 'sys',
          history: _history,
        )
        .toList();

    expect(chunks.join(), 'Привет! 👋');
    expect(sentBody!['stream'], true);
    expect(sentBody!['messages'][0], {'role': 'system', 'content': 'sys'});
    expect(sentBody!['messages'][1], {'role': 'user', 'content': 'Привет'});
  });

  for (final (status, kind) in [
    (401, AiErrorKind.invalidKey),
    (429, AiErrorKind.rateLimit),
    (404, AiErrorKind.modelNotFound),
    (503, AiErrorKind.overloaded),
  ]) {
    test('HTTP $status → $kind', () async {
      final server = await _server((req) async {
        req.response.statusCode = status;
        req.response.write('{"error":{"message":"fail"}}');
        await req.response.close();
      });
      addTearDown(server.close);

      final provider = OpenAiCompatibleProvider(
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      await expectLater(
        provider
            .streamChat(
              apiKey: 'k',
              model: 'm',
              systemPrompt: '',
              history: _history,
            )
            .toList(),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', kind)),
      );
    });
  }

  test('нет соединения → noInternet', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();

    final provider = OpenAiCompatibleProvider(
      baseUrl: 'http://127.0.0.1:$port',
    );
    await expectLater(
      provider
          .streamChat(
            apiKey: 'k',
            model: 'm',
            systemPrompt: '',
            history: _history,
          )
          .toList(),
      throwsA(
        isA<AiException>().having(
          (e) => e.kind,
          'kind',
          AiErrorKind.noInternet,
        ),
      ),
    );
  });

  test('Gemini: неверный ключ (400 API key not valid) → invalidKey', () {
    final e = AiException.fromHttp(
      400,
      'API key not valid. Please pass a valid API key.',
    );
    expect(e.kind, AiErrorKind.invalidKey);
    expect(e.message, contains('Неверный API-ключ'));
  });
}
