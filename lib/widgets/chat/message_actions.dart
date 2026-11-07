import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';

Future<String?> showChatMessageActions(
  BuildContext context,
  Offset position, {
  String? reaction,
  bool canEdit = true,
  bool canReply = true,
  bool canForward = true,
  bool emptyText = false,
}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final localPosition = overlay.globalToLocal(position);
  final colors = AppTheme.colorsOf(context);
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(localPosition.dx, localPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: colors.surfaceContainer,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
    items: [
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final emoji in ['👍', '❤️', '😂', '🔥', '🎉', '👎'])
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.all(ChatLayout.space8),
                  backgroundColor: reaction == emoji
                      ? colors.primaryContainer
                      : null,
                  shape: const CircleBorder(),
                ),
                onPressed: () => Navigator.pop(context, emoji),
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      if (canEdit)
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 21),
              SizedBox(width: 12),
              Expanded(child: Text('Edit message')),
            ],
          ),
        ),
      if (canReply)
        const PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply_rounded, size: 21),
              SizedBox(width: 12),
              Expanded(child: Text('Reply')),
            ],
          ),
        ),
      if (canForward)
        const PopupMenuItem<String>(
          value: 'forward',
          child: Row(
            children: [
              Icon(Icons.forward_rounded, size: 21),
              SizedBox(width: 12),
              Expanded(child: Text('Forward')),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'copy',
        child: Row(
          children: [
            const Icon(Icons.copy_outlined, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(emptyText ? 'Copy file names' : 'Copy message'),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: colors.error, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete message',
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
