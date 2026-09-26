import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import 'ai_exception.dart';

/// Общий интерфейс для всех провайдеров ИИ.
abstract class AiProvider {
  /// Потоково получает ответ модели. Каждое событие — очередной кусок текста.
  /// Отмена подписки на поток прерывает запрос.
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  });

  /// Список доступных моделей (для выбора в настройках).
  Future<List<String>> listModels(String apiKey);
}

/// Вспомогательные методы для HTTP и Server-Sent Events.
mixin SseHttpMixin {
  static const connectTimeout = Duration(seconds: 30);
  static const idleTimeout = Duration(seconds: 90);

  /// Отправляет запрос и возвращает поток JSON-объектов из строк `data: ...`.
  Stream<Map<String, dynamic>> postSse(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          ...headers,
        })
        ..body = jsonEncode(body);

      final http.StreamedResponse response;
      try {
        response = await client.send(request).timeout(connectTimeout);
      } catch (e) {
        throw AiException.from(e);
      }

      if (response.statusCode != 200) {
        final text = await response.stream.bytesToString();
        throw AiException.fromHttp(response.statusCode, text);
      }

      final lines = response.stream
          .timeout(idleTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      try {
        await for (final line in lines) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          final Object? json;
          try {
            json = jsonDecode(data);
          } on FormatException {
            continue;
          }
          if (json is Map<String, dynamic>) yield json;
        }
      } on AiException {
        rethrow;
      } catch (e) {
        throw AiException.from(e);
      }
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(connectTimeout);
      if (response.statusCode != 200) {
        throw AiException.fromHttp(
          response.statusCode,
          utf8.decode(response.bodyBytes),
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      throw AiException.from(e);
    }
  }
}
