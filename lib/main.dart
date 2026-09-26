import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app_config.dart';
import 'providers/app_providers.dart';
import 'screens/chat_screen.dart';
import 'services/storage/chat_repository.dart';
import 'services/storage/settings_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Hive.initFlutter();
  final chatRepository = await ChatRepository.open();
  final settingsRepository = await SettingsRepository.open();
  final settings = await settingsRepository.load();

  runApp(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(chatRepository),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const AiChatApp(),
    ),
  );
}

class AiChatApp extends StatelessWidget {
  const AiChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const ChatScreen(),
    );
  }
}
