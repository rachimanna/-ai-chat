// Меняет название приложения (под иконкой и внутри приложения).
//
// Использование:
//   dart run tool/rename_app.dart "Моё название" ["iOS name"]
//
// На iPhone название должно быть латиницей (иначе SideStore/Apple выдают
// ошибку «invalid value for appIdName»), поэтому для iOS можно указать
// отдельное имя вторым аргументом. По умолчанию — «AI Chat».
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args.first.trim().isEmpty) {
    stderr.writeln(
      'Укажите название: dart run tool/rename_app.dart "Название"',
    );
    exit(1);
  }
  final name = args.first.trim();
  final xmlName = name
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  _replace(
    'android/app/src/main/AndroidManifest.xml',
    RegExp(r'android:label="[^"]*"'),
    'android:label="$xmlName"',
  );
  final iosName = args.length > 1
      ? args[1].trim()
      : RegExp(r'^[\x20-\x7E]+$').hasMatch(name)
      ? xmlName
      : 'AI Chat';
  for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
    _replace(
      'ios/Runner/Info.plist',
      RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)'),
      null,
      (m) => '${m[1]}$iosName${m[2]}',
    );
  }
  final dartName = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  _replace(
    'lib/app_config.dart',
    RegExp(r"static const appName = '(?:[^'\\]|\\.)*';"),
    "static const appName = '$dartName';",
  );
  stdout.writeln('Готово! Новое название: $name');
}

void _replace(
  String path,
  RegExp pattern,
  String? replacement, [
  String Function(Match m)? builder,
]) {
  final file = File(path);
  final text = file.readAsStringSync();
  if (!pattern.hasMatch(text)) {
    stderr.writeln('Не найдено в $path — пропускаю');
    return;
  }
  file.writeAsStringSync(
    builder != null
        ? text.replaceAllMapped(pattern, builder)
        : text.replaceAll(pattern, replacement!),
  );
  stdout.writeln('Обновлён $path');
}
