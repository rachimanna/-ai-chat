import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_config.dart';
import '../models/chat.dart';
import '../providers/chat_controller.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

/// Боковое меню: новый чат, список чатов, переименование, удаление, настройки.
class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatControllerProvider.select((s) => s.chats));
    final currentId = ref.watch(
      chatControllerProvider.select((s) => s.currentChatId),
    );
    final controller = ref.read(chatControllerProvider.notifier);

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _DrawerButton(
                icon: Icons.edit_square,
                label: 'Новый чат',
                onTap: () {
                  controller.newChat();
                  Navigator.of(context).pop();
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 16, 6),
              child: Text(
                'Чаты',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? const Center(
                      child: Text(
                        'Здесь появятся ваши чаты',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: chats.length,
                      itemBuilder: (context, i) => _ChatTile(
                        key: ValueKey(chats[i].id),
                        chat: chats[i],
                        selected: chats[i].id == currentId,
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _DrawerButton(
                icon: Icons.settings_outlined,
                label: 'Настройки',
                onTap: () {
                  Navigator.of(context)
                    ..pop()
                    ..push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
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

class _DrawerButton extends StatelessWidget {
  const _DrawerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.text),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(fontSize: 15, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChatAction { rename, delete }

class _ChatTile extends ConsumerWidget {
  const _ChatTile({super.key, required this.chat, required this.selected});

  final Chat chat;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(chatControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            controller.selectChat(chat.id);
            Navigator.of(context).pop();
          },
          onLongPress: () => _showMenu(context, ref),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: selected
                          ? AppColors.text
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                PopupMenuButton<_ChatAction>(
                  tooltip: 'Действия',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onSelected: (a) => _onAction(context, ref, a),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ChatAction.rename,
                      child: _MenuRow(Icons.edit_outlined, 'Переименовать'),
                    ),
                    PopupMenuItem(
                      value: _ChatAction.delete,
                      child: _MenuRow(
                        Icons.delete_outline_rounded,
                        'Удалить',
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_ChatAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать'),
              onTap: () => Navigator.pop(context, _ChatAction.rename),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Удалить',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.pop(context, _ChatAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action != null && context.mounted) _onAction(context, ref, action);
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _ChatAction action,
  ) async {
    final controller = ref.read(chatControllerProvider.notifier);
    switch (action) {
      case _ChatAction.rename:
        final title = await showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(initial: chat.title),
        );
        if (title != null) await controller.renameChat(chat.id, title);
      case _ChatAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить чат?'),
            content: Text(
              'Чат «${chat.title}» будет удалён без возможности '
              'восстановления.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
        if (ok == true) await controller.deleteChat(chat.id);
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color = AppColors.text});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Переименовать чат'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(hintText: 'Название чата'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
