import 'package:flutter/material.dart';
import '../services/local_contact_store.dart';
import 'confirmation_dialog.dart';

enum ContactAction { block, unblock, clearHistory }

Future<void> performContactAction(
  BuildContext context,
  LocalContactStore store,
  String id,
  ContactAction action,
) async {
  FocusScope.of(context).unfocus();
  if (action != ContactAction.unblock) {
    final block = action == ContactAction.block;
    final confirmed = await showConfirmationDialog(
      context,
      title: block ? 'Block user?' : 'Clear history?',
      message: block
          ? 'Messages and calls to this contact will be disabled on this device. You can unblock them at any time.'
          : 'All messages in this local conversation will be removed.',
      confirmLabel: block ? 'Block' : 'Clear',
    );
    if (!context.mounted || !confirmed) return;
  }
  try {
    if (action == ContactAction.clearHistory) {
      await store.clearHistory(id);
    } else {
      await store.setBlocked(id, action == ContactAction.block);
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not update contact settings. Please restart the app and try again.',
        ),
      ),
    );
  }
}

List<PopupMenuEntry<String>> contactActionMenuItems(
  BuildContext context, {
  required bool blocked,
  bool canBlock = true,
}) {
  final colors = Theme.of(context).colorScheme;
  return [
    PopupMenuItem(
      value: 'clear',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.delete_outline, color: colors.error),
        title: Text('Clear history', style: TextStyle(color: colors.error)),
      ),
    ),
    if (canBlock)
      PopupMenuItem(
        value: 'block',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            blocked ? Icons.lock_open : Icons.block,
            color: blocked ? colors.primary : colors.error,
          ),
          title: Text(
            blocked ? 'Unblock user' : 'Block user',
            style: TextStyle(color: blocked ? colors.primary : colors.error),
          ),
        ),
      ),
  ];
}
