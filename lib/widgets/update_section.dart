import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai/ai_exception.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Блок «Обновления» в настройках: текущая версия и проверка новой.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  static bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(
          () => _version = '${info.version} (сборка ${info.buildNumber})',
        );
      }
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final info = await UpdateService.check();
      if (!mounted) return;
      if (info.hasUpdate) {
        await _showUpdate(info);
      } else {
        _snack('У вас последняя версия');
      }
    } on UpdateException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack(AiException.from(e).message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showUpdate(UpdateInfo info) async {
    final download = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Доступно обновление'),
        content: Text(
          '${info.version}\n\n${_isDesktop ? 'Нажмите «Скачать», распакуйте архив и замените им старую '
                    'папку с приложением — чаты и настройки сохранятся.' : 'Нажмите «Скачать», откройте загруженный файл и установите его '
                    'поверх текущей версии — чаты и настройки сохранятся.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Позже'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
    if (download == true) {
      await launchUrl(
        Uri.parse(info.downloadUrl ?? info.pageUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.system_update_rounded),
        title: const Text('Проверить обновления'),
        subtitle: Text(
          _version.isEmpty ? 'Версия…' : 'Версия $_version',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        trailing: _checking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: _checking ? null : _check,
      ),
    );
  }
}
