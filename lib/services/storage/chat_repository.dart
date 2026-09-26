import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../../models/chat.dart';

/// Локальное хранилище чатов (Hive). Каждый чат хранится как JSON-строка.
class ChatRepository {
  ChatRepository(this._box);

  static const boxName = 'chats';

  final Box<String> _box;

  static Future<ChatRepository> open() async =>
      ChatRepository(await Hive.openBox<String>(boxName));

  List<Chat> loadAll() {
    final chats = <Chat>[];
    for (final raw in _box.values) {
      try {
        chats.add(Chat.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Повреждённая запись — пропускаем, чтобы приложение не падало.
      }
    }
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  Future<void> save(Chat chat) => _box.put(chat.id, jsonEncode(chat.toJson()));

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();
}
