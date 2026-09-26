import '../../app_config.dart';
import '../../models/ai_provider_type.dart';
import 'ai_provider.dart';
import 'gemini_provider.dart';
import 'openai_compatible_provider.dart';

/// Создаёт реализацию [AiProvider] для выбранного типа провайдера.
AiProvider createAiProvider(AiProviderType type) {
  return switch (type) {
    AiProviderType.gemini => GeminiProvider(),
    AiProviderType.openRouter => OpenAiCompatibleProvider(
      baseUrl: type.openAiBaseUrl!,
      extraHeaders: {'X-Title': AppConfig.appName},
    ),
    AiProviderType.groq => OpenAiCompatibleProvider(
      baseUrl: type.openAiBaseUrl!,
    ),
  };
}
