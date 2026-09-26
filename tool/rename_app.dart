// Меняет название приложения (под иконкой и внутри приложения).
//
// Использование (из папки ai_chat):
//   dart run tool/rename_app.dart "Моё название"
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
  for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
    _replace(
      'ios/Runner/Info.plist',
      RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)'),
      null,
      (m) => '${m[1]}$xmlName${m[2]}',
    );
  }
  _replace(
    'web/index.html',
    RegExp(r'<title>[^<]*</title>'),
    '<title>$xmlName</title>',
  );
  _replace(
    'web/index.html',
    RegExp(r'(apple-mobile-web-app-title" content=")[^"]*(")'),
    null,
    (m) => '${m[1]}$xmlName${m[2]}',
  );
  final jsonName = name.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  _replace(
    'web/manifest.json',
    RegExp(r'"(short_name|name)": "(?:[^"\\]|\\.)*"'),
    null,
    (m) => '"${m[1]}": "$jsonName"',
  );
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
