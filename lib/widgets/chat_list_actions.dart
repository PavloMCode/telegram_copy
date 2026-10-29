import 'package:flutter/material.dart';
import 'account_data_scope.dart';
import 'confirmation_dialog.dart';

List<PopupMenuEntry<String>> chatListMenuItems({
  required bool pinned,
  bool allowDelete = true,
}) => [
  PopupMenuItem(
    value: 'pin_chat',
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.push_pin_outlined),
      title: Text(pinned ? 'Unpin chat' : 'Pin chat'),
    ),
  ),
  if (allowDelete)
    const PopupMenuItem(
      value: 'delete_chat',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.delete_outline),
        title: Text('Delete chat'),
      ),
    ),
];

Future<bool> performChatListAction(
  BuildContext context,
  String id,
  String action,
) async {
  final data = AccountDataScope.maybeOf(context);
  if (data == null) return false;
  if (action == 'delete_chat') {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete chat?',
      message:
          'This chat, its messages and draft will be removed from this account on this device. The contact will remain in your contacts. This cannot be undone.',
      confirmLabel: 'Delete chat',
    );
    if (!confirmed || !context.mounted) return false;
  }
  try {
    if (action == 'delete_chat') {
      await data.deleteConversation(id);
      return true;
    }
    await data.setChatPinned(id, !data.isChatPinned(id));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update chat. Please try again.'),
        ),
      );
    }
  }
  return false;
}
