import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart';
import 'ai/ai_exception.dart';

/// Информация о свежем релизе на GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.currentBuild,
    required this.latestBuild,
    required this.version,
    required this.pageUrl,
    this.downloadUrl,
    this.notes = '',
  });

  final int currentBuild;
  final int latestBuild;
  final String version;

  /// Страница релиза.
  final String pageUrl;

  /// Прямая ссылка на файл для этой платформы (APK / IPA).
  final String? downloadUrl;
  final String notes;

  bool get hasUpdate => latestBuild > currentBuild;
}

/// Проверяет обновления через GitHub Releases.
///
/// Каждая сборка в CI публикует релиз с тегом `build-<номер>`,
/// а номер сборки зашивается в приложение (`--build-number`).
class UpdateService {
  static Future<int> currentBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<UpdateInfo> check() async {
    final current = await currentBuild();
    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/${AppConfig.githubRepo}/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw AiException.from(e);
    }
    if (response.statusCode == 404) {
      throw const UpdateException('Релизов пока нет.');
    }
    if (response.statusCode != 200) {
      throw UpdateException(
        'Не удалось проверить обновления (код ${response.statusCode}).',
      );
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final tag = json['tag_name'] as String? ?? '';
    final latest = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    // Файл для своей платформы. На iPhone .ipa ставится через SideStore,
    // поэтому там открываем страницу релиза.
    final wanted = switch (defaultTargetPlatform) {
      TargetPlatform.android => '.apk',
      TargetPlatform.windows => 'windows.zip',
      TargetPlatform.macOS => 'macos.zip',
      _ => null,
    };
    String? downloadUrl;
    if (wanted != null) {
      for (final asset in (json['assets'] as List? ?? const [])) {
        final name = (asset as Map)['name'] as String? ?? '';
        if (name.endsWith(wanted)) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    return UpdateInfo(
      currentBuild: current,
      latestBuild: latest,
      version: json['name'] as String? ?? tag,
      pageUrl:
          json['html_url'] as String? ??
          'https://github.com/${AppConfig.githubRepo}/releases/latest',
      downloadUrl: downloadUrl,
      notes: json['body'] as String? ?? '',
    );
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
