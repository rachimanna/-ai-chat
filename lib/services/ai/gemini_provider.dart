import '../../models/chat_message.dart';
import 'ai_exception.dart';
import 'ai_provider.dart';

/// Google Gemini API (https://ai.google.dev).
class GeminiProvider with SseHttpMixin implements AiProvider {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    final uri = Uri.parse('$_base/models/$model:streamGenerateContent?alt=sse');
    final body = <String, dynamic>{
      if (systemPrompt.isNotEmpty)
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      'contents': [
        for (final m in history)
          {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
      ],
    };

    var gotText = false;
    await for (final json in postSse(
      uri,
      headers: {'x-goog-api-key': apiKey},
      body: body,
    )) {
      if (json['error'] is Map) {
        final err = json['error'] as Map;
        throw AiException.fromHttp(
          (err['code'] as num?)?.toInt() ?? 500,
          '${err['message']}',
        );
      }
      final promptFeedback = json['promptFeedback'];
      if (promptFeedback is Map && promptFeedback['blockReason'] != null) {
        throw AiException(
          AiErrorKind.blocked,
          '${promptFeedback['blockReason']}',
        );
      }
      final candidates = json['candidates'];
      if (candidates is! List || candidates.isEmpty) continue;
      final candidate = candidates.first as Map;
      final parts = (candidate['content'] as Map?)?['parts'];
      if (parts is List) {
        for (final part in parts) {
          // Пропускаем «мысли» моделей с рассуждением.
          if (part is Map &&
              part['thought'] != true &&
              part['text'] is String) {
            gotText = true;
            yield part['text'] as String;
          }
        }
      }
      if (!gotText && candidate['finishReason'] == 'SAFETY') {
        throw const AiException(AiErrorKind.blocked);
      }
    }
  }

  @override
  Future<List<String>> listModels(String apiKey) async {
    final json = await getJson(
      Uri.parse('$_base/models?pageSize=200'),
      headers: {'x-goog-api-key': apiKey},
    );
    final models =
        (json['models'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .where(
              (m) => (m['supportedGenerationMethods'] as List? ?? const [])
                  .contains('generateContent'),
            )
            .map((m) => (m['name'] as String).replaceFirst('models/', ''))
            .where((name) => name.startsWith('gemini'))
            .toList()
          ..sort();
    return models;
  }
}
