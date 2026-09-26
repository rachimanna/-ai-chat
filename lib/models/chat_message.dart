enum MessageRole { user, assistant }

/// Одно сообщение в чате.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.error,
  });

  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;

  /// Текст ошибки, если ответ ИИ не удалось получить.
  final String? error;

  bool get isUser => role == MessageRole.user;
  bool get hasError => error != null;

  ChatMessage copyWith({String? text, String? error, bool clearError = false}) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (error != null) 'error': error,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    role: MessageRole.values.byName(json['role'] as String),
    text: json['text'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    error: json['error'] as String?,
  );
}
