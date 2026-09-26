/// Поддерживаемые провайдеры ИИ.
///
/// Чтобы добавить нового провайдера:
/// 1. Добавьте значение в этот enum (название, ссылку на ключ, модели).
/// 2. Если API совместим с OpenAI — просто укажите [openAiBaseUrl].
///    Иначе реализуйте свой класс от `AiProvider` и зарегистрируйте его
///    в `services/ai/ai_provider_factory.dart`.
enum AiProviderType {
  gemini(
    title: 'Google Gemini',
    keyUrl: 'https://aistudio.google.com/apikey',
    keyHint: 'AIza...',
    defaultModel: 'gemini-2.5-flash',
    models: [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.5-pro',
      'gemini-2.0-flash',
    ],
  ),
  openRouter(
    title: 'OpenRouter',
    keyUrl: 'https://openrouter.ai/keys',
    keyHint: 'sk-or-...',
    defaultModel: 'deepseek/deepseek-chat-v3-0324:free',
    models: [
      'deepseek/deepseek-chat-v3-0324:free',
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemma-3-27b-it:free',
      'mistralai/mistral-small-3.2-24b-instruct:free',
    ],
    openAiBaseUrl: 'https://openrouter.ai/api/v1',
  ),
  groq(
    title: 'Groq',
    keyUrl: 'https://console.groq.com/keys',
    keyHint: 'gsk_...',
    defaultModel: 'llama-3.3-70b-versatile',
    models: [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'openai/gpt-oss-120b',
      'qwen/qwen3-32b',
    ],
    openAiBaseUrl: 'https://api.groq.com/openai/v1',
  );

  const AiProviderType({
    required this.title,
    required this.keyUrl,
    required this.keyHint,
    required this.defaultModel,
    required this.models,
    this.openAiBaseUrl,
  });

  final String title;

  /// Где получить API-ключ.
  final String keyUrl;
  final String keyHint;
  final String defaultModel;

  /// Предустановленные модели (пользователь может ввести и свою).
  final List<String> models;

  /// Базовый URL для OpenAI-совместимых API.
  final String? openAiBaseUrl;
}
