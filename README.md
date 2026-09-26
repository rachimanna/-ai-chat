# ИИ Чат — мобильный чат с ИИ на Flutter

Один код для Android и iOS. Похоже на ChatGPT/Claude: тёмная тема, потоковые
ответы, Markdown с подсветкой кода, история чатов на устройстве.

## Возможности

- **Провайдеры ИИ:** Google Gemini (по умолчанию, бесплатный тариф), OpenRouter
  (бесплатные модели `:free`), Groq. Новый провайдер добавляется в пару строк.
- **Потоковые ответы:** текст появляется постепенно, кнопка «Стоп» прерывает генерацию.
- **Ошибки на русском:** нет интернета, неверный ключ, превышен лимит,
  модель не найдена, сервис перегружен, кнопка «Повторить».
- **Markdown:** заголовки, списки, жирный текст, таблицы, блоки кода с подсветкой
  и кнопкой «Копировать».
- **Память:** все чаты хранятся локально (Hive) и не пропадают после перезапуска.
  В каждый запрос отправляется вся история чата. Поле «Расскажи о себе»
  добавляется в системный промпт всех чатов.
- **Безопасность:** API-ключ не зашит в код, пользователь вводит его сам;
  ключ хранится в `flutter_secure_storage` (Android Keystore / iOS Keychain).

## Структура проекта

```
lib/
  main.dart                 — запуск, инициализация хранилищ
  app_config.dart           — название, системный промпт, примеры запросов
  models/                   — Chat, ChatMessage, AppSettings, AiProviderType
  services/ai/              — интерфейс AiProvider, Gemini, OpenAI-совместимые, ошибки
  services/storage/         — ChatRepository (Hive), SettingsRepository (Hive + secure storage)
  providers/                — Riverpod: чаты и генерация, настройки, потоковый текст
  screens/                  — ChatScreen, SettingsScreen
  widgets/                  — сообщения, Markdown, блок кода, поле ввода, меню, анимации
  theme/                    — тёмная тема
tool/rename_app.dart        — смена названия приложения
assets/icon/                — иконка приложения
```

## Установка

- **Android:** скачайте `ai-chat.apk` со страницы
  [Releases](https://github.com/rachimanna/-ai-chat/releases/latest) прямо на телефон и откройте.
- **iPhone без компьютера:** откройте в Safari https://rachimanna.github.io/-ai-chat/,
  нажмите «Поделиться» → «На экран „Домой“». Появится иконка, приложение
  открывается на весь экран и обновляется само.
- **iPhone как нативное приложение:** `ai-chat-unsigned.ipa` из Releases через
  Sideloadly на компьютере (подпись бесплатным Apple ID действует 7 дней).

## Как получить бесплатный ключ Gemini

1. Откройте https://aistudio.google.com/apikey и войдите в Google-аккаунт.
2. Нажмите **Create API key**, затем скопируйте ключ (начинается с `AIza`).
3. В приложении: меню → **Настройки** → вставьте ключ → **Проверить** → **Сохранить**.

Ключи других провайдеров: OpenRouter — https://openrouter.ai/keys,
Groq — https://console.groq.com/keys.

## Сборка

### Автоматически (GitHub Actions, без установки чего-либо)

При каждом пуше запускается workflow
`.github/workflows/build.yml`: он проверяет код и тесты, собирает APK
и неподписанный IPA. Файлы появляются на странице запуска
(**Actions → последний запуск → Artifacts**). Если запушить тег `v1.0.0`,
файлы также появятся в **Releases**.

### На своём компьютере

```bash
flutter pub get
flutter build apk --release          # Android
# файл: build/app/outputs/flutter-apk/app-release.apk
```

APK подписан debug-ключом, этого достаточно для установки файлом.
Для iOS нужен Mac (см. ниже).

## Как поменять название и иконку

```bash
dart run tool/rename_app.dart "Моё название"   # название под иконкой и в приложении
```

Иконка: замените `assets/icon/icon.png` (квадрат, лучше 1024×1024, без прозрачности)
и `assets/icon/icon_foreground.png` (тот же рисунок на прозрачном фоне с отступами
для адаптивной иконки Android), затем:

```bash
dart run flutter_launcher_icons
```

## Как добавить провайдера

- **OpenAI-совместимый API** (Together, DeepSeek, Mistral и т.д.): добавьте значение
  в `lib/models/ai_provider_type.dart` с `openAiBaseUrl` и одну строку в
  `lib/services/ai/ai_provider_factory.dart`.
- **Другой API:** реализуйте интерфейс `AiProvider`
  (`lib/services/ai/ai_provider.dart`) по образцу `GeminiProvider`.
