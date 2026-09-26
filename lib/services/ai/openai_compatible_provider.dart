import '../../models/chat_message.dart';
import 'ai_exception.dart';
import 'ai_provider.dart';

/// Любой OpenAI-совместимый API: OpenRouter, Groq, и т.п.
class OpenAiCompatibleProvider with SseHttpMixin implements AiProvider {
  OpenAiCompatibleProvider({
    required this.baseUrl,
    this.extraHeaders = const {},
  });

  final String baseUrl;
  final Map<String, String> extraHeaders;

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    ...extraHeaders,
  };

  @override
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    final body = <String, dynamic>{
      'model': model,
      'stream': true,
      'messages': [
        if (systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        for (final m in history)
          {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
      ],
    };

    await for (final json in postSse(
      Uri.parse('$baseUrl/chat/completions'),
      headers: _headers(apiKey),
      body: body,
    )) {
      if (json['error'] is Map) {
        final err = json['error'] as Map;
        throw AiException.fromHttp(
          (err['code'] as num?)?.toInt() ?? 500,
          '${err['message']}',
        );
      }
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final delta = (choices.first as Map)['delta'];
      final content = delta is Map ? delta['content'] : null;
      if (content is String && content.isNotEmpty) yield content;
    }
  }

  @override
  Future<List<String>> listModels(String apiKey) async {
    final json = await getJson(
      Uri.parse('$baseUrl/models'),
      headers: _headers(apiKey),
    );
    final models =
        (json['data'] as List? ?? const [])
            .map((m) => (m as Map)['id'] as String)
            .toList()
          ..sort();
    return models;
  }
}
