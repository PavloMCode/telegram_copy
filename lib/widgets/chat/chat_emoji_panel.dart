import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

void insertChatEmoji(TextEditingController controller, String emoji) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  controller.value = TextEditingValue(
    text: value.text.replaceRange(start, end, emoji),
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
}

class ChatEmojiPanel extends StatelessWidget {
  const ChatEmojiPanel({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppTheme.colorsOf(context).surfaceContainerLow,
    padding: const EdgeInsets.all(8),
    child: Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final emoji in ['😀', '😊', '😂', '❤️', '👍', '🎉', '👋', '🔥'])
          TextButton(
            onPressed: () => insertChatEmoji(controller, emoji),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
      ],
    ),
  );
}
