import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.showEmoji,
    required this.pickingFiles,
    required this.hasPendingContent,
    required this.onToggleEmoji,
    required this.onInputTap,
    required this.onAttach,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool showEmoji;
  final bool pickingFiles;
  final bool hasPendingContent;
  final VoidCallback onToggleEmoji;
  final VoidCallback onInputTap;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final inputIconStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      fixedSize: const Size(32, 32),
      padding: const EdgeInsets.all(ChatLayout.space4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return ConstrainedBox(
      key: const ValueKey('chat-composer'),
      constraints: const BoxConstraints(
        minHeight: ChatLayout.minComposerHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ChatLayout.space16),
          ),
          border: Border(
            top: BorderSide(color: colors.subtleDivider, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ChatLayout.space8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  key: const ValueKey('chat-input'),
                  constraints: const BoxConstraints(
                    minHeight: ChatLayout.minInputHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(
                        ChatLayout.inputRadius,
                      ),
                      border: Border.all(color: colors.inputOutline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ChatLayout.space12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ChatLayout.space8,
                            ),
                            child: IconButton(
                              tooltip: showEmoji ? 'Close emoji' : 'Emoji',
                              style: inputIconStyle,
                              iconSize: ChatLayout.iconSize,
                              icon: Icon(
                                showEmoji
                                    ? Icons.close
                                    : Icons.sentiment_satisfied_alt_outlined,
                                color: colors.onSurfaceVariant,
                              ),
                              onPressed: onToggleEmoji,
                            ),
                          ),
                          const SizedBox(width: ChatLayout.space8),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: ChatLayout.maxInputLines,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(
                                fontSize: ChatLayout.messageFontSize,
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                filled: false,
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: ChatLayout.space12,
                                ),
                              ),
                              onTap: onInputTap,
                            ),
                          ),
                          const SizedBox(width: ChatLayout.space8),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ChatLayout.space8,
                            ),
                            child: IconButton(
                              tooltip: 'Attach files',
                              style: inputIconStyle,
                              iconSize: ChatLayout.iconSize,
                              onPressed: pickingFiles ? null : onAttach,
                              icon: pickingFiles
                                  ? const SizedBox(
                                      width: ChatLayout.iconSize,
                                      height: ChatLayout.iconSize,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.attach_file,
                                      color: colors.onSurfaceVariant,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ChatLayout.space8),
              Padding(
                padding: const EdgeInsets.only(
                  bottom:
                      (ChatLayout.minInputHeight - ChatLayout.sendButtonSize) /
                      2,
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, value, _) => IconButton.filled(
                    key: const ValueKey('chat-send'),
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(
                      fixedSize: const Size(
                        ChatLayout.sendButtonSize,
                        ChatLayout.sendButtonSize,
                      ),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ChatLayout.sendButtonRadius,
                        ),
                      ),
                      backgroundColor: colors.sendButtonBackground,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor: colors.disabledBackground,
                      disabledForegroundColor: colors.disabledForeground,
                    ),
                    onPressed:
                        pickingFiles ||
                            (value.text.trim().isEmpty && !hasPendingContent)
                        ? null
                        : onSend,
                    icon: const Icon(
                      Icons.send_rounded,
                      size: ChatLayout.iconSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
