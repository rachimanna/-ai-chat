import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_provider_type.dart';
import '../models/app_settings.dart';
import '../providers/chat_controller.dart';
import '../providers/settings_provider.dart';
import '../services/ai/ai_exception.dart';
import '../services/ai/ai_provider_factory.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late AppSettings _settings;
  late final Map<AiProviderType, TextEditingController> _keyControllers;
  late final TextEditingController _aboutController;
  bool _obscureKey = true;
  bool _checking = false;
  final Map<AiProviderType, List<String>> _loadedModels = {};

  @override
  void initState() {
    super.initState();
    _settings = ref.read(settingsProvider);
    _keyControllers = {
      for (final p in AiProviderType.values)
        p: TextEditingController(text: _settings.keyFor(p)),
    };
    _aboutController = TextEditingController(text: _settings.aboutMe);
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    _aboutController.dispose();
    super.dispose();
  }

  AppSettings get _current => _settings.copyWith(
    aboutMe: _aboutController.text.trim(),
    apiKeys: {
      for (final e in _keyControllers.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    },
  );

  Future<void> _save({bool showMessage = false}) async {
    await ref.read(settingsProvider.notifier).save(_current);
    if (showMessage && mounted) {
      _snack('Настройки сохранены');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _checkKey() async {
    final provider = _settings.provider;
    final key = _keyControllers[provider]!.text.trim();
    if (key.isEmpty) {
      _snack('Сначала введите API-ключ');
      return;
    }
    setState(() => _checking = true);
    try {
      final models = await createAiProvider(provider).listModels(key);
      if (!mounted) return;
      setState(() => _loadedModels[provider] = models);
      _snack('Ключ работает! Доступно моделей: ${models.length}');
      await _save();
    } catch (e) {
      if (mounted) _snack(AiException.from(e).message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickModel() async {
    final provider = _settings.provider;
    final models = <String>{
      ...provider.models,
      ...?_loadedModels[provider],
    }.toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ModelPicker(
        models: models,
        selected: _settings.model,
        recommended: provider.models,
      ),
    );
    if (selected != null && selected.trim().isNotEmpty) {
      setState(() {
        _settings = _settings.copyWith(
          models: {..._settings.models, provider: selected.trim()},
        );
      });
      await _save();
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить все данные?'),
        content: const Text(
          'Будут удалены все чаты, API-ключи и настройки. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(chatControllerProvider.notifier).clearAll();
    if (!mounted) return;
    setState(() {
      _settings = const AppSettings();
      for (final c in _keyControllers.values) {
        c.clear();
      }
      _aboutController.clear();
      _loadedModels.clear();
    });
    _snack('Все данные удалены');
  }

  @override
  Widget build(BuildContext context) {
    final provider = _settings.provider;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _SectionTitle('Провайдер ИИ'),
            SegmentedButton<AiProviderType>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.surfaceHigh,
                selectedForegroundColor: AppColors.text,
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
              ),
              segments: [
                for (final p in AiProviderType.values)
                  ButtonSegment(value: p, label: Text(p.title, maxLines: 1)),
              ],
              selected: {provider},
              onSelectionChanged: (s) => setState(() {
                _settings = _settings.copyWith(provider: s.first);
              }),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('API-ключ'),
            TextField(
              controller: _keyControllers[provider],
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: provider.keyHint,
                suffixIcon: IconButton(
                  tooltip: _obscureKey ? 'Показать' : 'Скрыть',
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(provider.keyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Получить ключ'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.text),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _checking ? null : _checkKey,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: const Text('Проверить'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.text),
                ),
              ],
            ),
            const Text(
              'Ключ хранится только на этом устройстве в защищённом хранилище.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Модель'),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(_settings.model),
                subtitle: const Text(
                  'Нажмите, чтобы выбрать',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                trailing: const Icon(Icons.unfold_more_rounded),
                onTap: _pickModel,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Расскажи о себе'),
            TextField(
              controller: _aboutController,
              minLines: 3,
              maxLines: 8,
              maxLength: 1500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Например: меня зовут Анна, я дизайнер, люблю короткие ответы с примерами.',
              ),
            ),
            const Text(
              'Эта информация добавляется в каждый чат, чтобы ИИ помнил вас.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _save(showMessage: true),
              child: const Text('Сохранить'),
            ),
            const SizedBox(height: 40),
            const _SectionTitle('Данные'),
            OutlinedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Очистить все данные'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({
    required this.models,
    required this.selected,
    required this.recommended,
  });

  final List<String> models;
  final String selected;
  final List<String> recommended;

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _custom,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Своя модель (ID)',
                  fillColor: AppColors.surfaceHigh,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () => Navigator.pop(context, _custom.text),
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: widget.models.length,
                itemBuilder: (context, i) {
                  final m = widget.models[i];
                  return ListTile(
                    title: Text(m),
                    subtitle: widget.recommended.contains(m)
                        ? const Text(
                            'Рекомендуемая',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: m == widget.selected
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
