import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_provider_type.dart';
import '../models/app_settings.dart';
import '../services/ai/ai_provider.dart';
import '../services/ai/ai_provider_factory.dart';
import '../services/storage/chat_repository.dart';
import '../services/storage/settings_repository.dart';

/// Репозитории создаются в main() и подставляются через overrides.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => throw UnimplementedError('Переопределяется в main()'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Переопределяется в main()'),
);

/// Настройки, загруженные при старте.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// Фабрика провайдеров ИИ (можно подменить в тестах).
final aiProviderFactory = Provider<AiProvider Function(AiProviderType)>(
  (ref) => createAiProvider,
);
