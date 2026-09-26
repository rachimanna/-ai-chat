import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

enum AiErrorKind {
  noInternet,
  invalidKey,
  noKey,
  rateLimit,
  modelNotFound,
  overloaded,
  blocked,
  timeout,
  unknown,
}

/// Ошибка обращения к ИИ с понятным сообщением на русском.
class AiException implements Exception {
  const AiException(this.kind, [this.details]);

  final AiErrorKind kind;

  /// Технические подробности (показываются мелким шрифтом).
  final String? details;

  String get message => switch (kind) {
    AiErrorKind.noInternet =>
      'Нет подключения к интернету. Проверьте сеть и попробуйте ещё раз.',
    AiErrorKind.invalidKey => 'Неверный API-ключ. Проверьте ключ в настройках.',
    AiErrorKind.noKey =>
      'API-ключ не указан. Откройте настройки и введите ключ.',
    AiErrorKind.rateLimit => 'Превышен лимит запросов бесплатного тарифа. Подождите минуту и повторите, либо выберите другую модель.',
    AiErrorKind.modelNotFound =>
      'Модель не найдена или недоступна. Выберите другую модель в настройках.',
    AiErrorKind.overloaded =>
      'Сервис ИИ сейчас перегружен. Попробуйте чуть позже.',
    AiErrorKind.blocked => 'Ответ заблокирован фильтрами безопасности. Попробуйте переформулировать запрос.',
    AiErrorKind.timeout =>
      'Сервер слишком долго не отвечает. Попробуйте ещё раз.',
    AiErrorKind.unknown => 'Не удалось получить ответ.',
  };

  /// Преобразует HTTP-ответ с ошибкой в [AiException].
  factory AiException.fromHttp(int status, String body) {
    final lower = body.toLowerCase();
    final kind = switch (status) {
      401 || 403 => AiErrorKind.invalidKey,
      400 when lower.contains('api key') || lower.contains('api_key') =>
        AiErrorKind.invalidKey,
      402 || 429 => AiErrorKind.rateLimit,
      404 => AiErrorKind.modelNotFound,
      500 || 502 || 503 || 504 || 529 => AiErrorKind.overloaded,
      _ => AiErrorKind.unknown,
    };
    return AiException(kind, 'HTTP $status: ${_shorten(body)}');
  }

  /// Преобразует любое исключение в [AiException].
  factory AiException.from(Object error) {
    if (error is AiException) return error;
    if (error is SocketException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return AiException(AiErrorKind.noInternet, error.toString());
    }
    if (error is TimeoutException) {
      return const AiException(AiErrorKind.timeout);
    }
    return AiException(AiErrorKind.unknown, error.toString());
  }

  static String _shorten(String s) {
    final t = s.trim();
    return t.length > 300 ? '${t.substring(0, 300)}…' : t;
  }

  @override
  String toString() => details == null ? message : '$message ($details)';
}
