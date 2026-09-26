import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import '../../models/ai_provider_type.dart';
import '../../models/app_settings.dart';

/// Хранит настройки: обычные — в Hive, API-ключи — в flutter_secure_storage
/// (Android Keystore / iOS Keychain).
class SettingsRepository {
  SettingsRepository(this._box, this._secure);

  static const boxName = 'settings';

  final Box<String> _box;
  final FlutterSecureStorage _secure;

  static Future<SettingsRepository> open() async => SettingsRepository(
    await Hive.openBox<String>(boxName),
    const FlutterSecureStorage(),
  );

  static String _keyName(AiProviderType p) => 'api_key_${p.name}';
  static String _modelName(AiProviderType p) => 'model_${p.name}';

  Future<AppSettings> load() async {
    final provider =
        AiProviderType.values.asNameMap()[_box.get('provider')] ??
        AiProviderType.gemini;
    final models = <AiProviderType, String>{
      for (final p in AiProviderType.values)
        if (_box.get(_modelName(p)) case final String m) p: m,
    };
    final keys = <AiProviderType, String>{};
    for (final p in AiProviderType.values) {
      try {
        final key = await _secure.read(key: _keyName(p));
        if (key != null && key.isNotEmpty) keys[p] = key;
      } catch (_) {
        // Хранилище могло быть сброшено системой — просто просим ключ заново.
      }
    }
    return AppSettings(
      provider: provider,
      models: models,
      aboutMe: _box.get('about_me') ?? '',
      apiKeys: keys,
    );
  }

  Future<void> save(AppSettings s) async {
    await _box.putAll({
      'provider': s.provider.name,
      'about_me': s.aboutMe,
      for (final e in s.models.entries) _modelName(e.key): e.value,
    });
    for (final p in AiProviderType.values) {
      final key = s.keyFor(p).trim();
      if (key.isEmpty) {
        await _secure.delete(key: _keyName(p));
      } else {
        await _secure.write(key: _keyName(p), value: key);
      }
    }
  }

  Future<void> clear() async {
    await _box.clear();
    await _secure.deleteAll();
  }
}
