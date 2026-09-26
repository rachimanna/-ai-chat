import 'ai_provider_type.dart';

/// Настройки приложения. API-ключи хранятся отдельно, в защищённом хранилище.
class AppSettings {
  const AppSettings({
    this.provider = AiProviderType.gemini,
    this.models = const {},
    this.aboutMe = '',
    this.apiKeys = const {},
  });

  final AiProviderType provider;

  /// Выбранная модель для каждого провайдера.
  final Map<AiProviderType, String> models;

  /// «Расскажи о себе» — добавляется в системный промпт.
  final String aboutMe;

  /// API-ключи (в памяти; на диске — в flutter_secure_storage).
  final Map<AiProviderType, String> apiKeys;

  String modelFor(AiProviderType p) => models[p] ?? p.defaultModel;
  String get model => modelFor(provider);

  String keyFor(AiProviderType p) => apiKeys[p] ?? '';
  String get apiKey => keyFor(provider);
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    AiProviderType? provider,
    Map<AiProviderType, String>? models,
    String? aboutMe,
    Map<AiProviderType, String>? apiKeys,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      models: models ?? this.models,
      aboutMe: aboutMe ?? this.aboutMe,
      apiKeys: apiKeys ?? this.apiKeys,
    );
  }
}
