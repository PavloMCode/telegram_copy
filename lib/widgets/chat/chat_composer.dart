import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';
import '../../theme/app_gradients.dart';

class ChatComposer extends StatefulWidget {
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
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onInputFocusChanged);
  }

  void _onInputFocusChanged() => setState(() {});

  @override
  void dispose() {
    _inputFocusNode
      ..removeListener(_onInputFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final showEmoji = widget.showEmoji;
    final pickingFiles = widget.pickingFiles;
    final hasPendingContent = widget.hasPendingContent;
    final onToggleEmoji = widget.onToggleEmoji;
    final onInputTap = widget.onInputTap;
    final onAttach = widget.onAttach;
    final onSend = widget.onSend;
    final colors = AppTheme.colorsOf(context);
    final iconStyle = IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      fixedSize: const Size(48, 48),
      padding: const EdgeInsets.all(12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final emoji = IconButton(
      tooltip: showEmoji ? 'Close emoji' : 'Emoji',
      style: iconStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          showEmoji ? colors.secondaryContainer : Colors.transparent,
        ),
      ),
      iconSize: ChatLayout.iconSize,
      icon: Icon(
        showEmoji ? Icons.close : Icons.sentiment_satisfied_alt_outlined,
        color: showEmoji
            ? colors.onSecondaryContainer
            : colors.onSurfaceVariant,
      ),
      onPressed: onToggleEmoji,
    );
    final attach = IconButton(
      tooltip: 'Attach files',
      style: iconStyle,
      iconSize: ChatLayout.iconSize,
      onPressed: pickingFiles ? null : onAttach,
      icon: pickingFiles
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.attach_file, color: colors.onSurfaceVariant),
    );
    final send = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, _) => IconButton.filled(
        key: const ValueKey('chat-send'),
        tooltip: 'Send message',
        style: IconButton.styleFrom(
          fixedSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
          backgroundColor: colors.sendButtonBackground,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: .12),
          disabledForegroundColor: colors.disabledForeground,
        ),
        onPressed:
            pickingFiles || (value.text.trim().isEmpty && !hasPendingContent)
            ? null
            : onSend,
        icon: const Icon(Icons.send_rounded, size: ChatLayout.iconSize),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // At larger text sizes, keep a full-width editor rather than squeezing
        // text between controls. The controls retain their 48dp touch targets.
        final stacked =
            constraints.maxWidth < 420 &&
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final field = TextField(
          controller: controller,
          focusNode: _inputFocusNode,
          minLines: 1,
          maxLines: ChatLayout.maxInputLines,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          decoration: const InputDecoration(
            hintText: 'Message',
            hintMaxLines: 1,
            filled: false,
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
          onTap: onInputTap,
        );
        final input = ConstrainedBox(
          key: const ValueKey('chat-input'),
          constraints: const BoxConstraints(
            minHeight: ChatLayout.minInputHeight,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(ChatLayout.inputRadius),
              border: Border.all(
                color: _inputFocusNode.hasFocus
                    ? colors.primary
                    : colors.outlineVariant,
                width: _inputFocusNode.hasFocus ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: stacked ? 16 : 4),
              child: stacked
                  ? field
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: emoji,
                        ),
                        Expanded(child: field),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: attach,
                        ),
                      ],
                    ),
            ),
          ),
        );
        return ConstrainedBox(
          key: const ValueKey('chat-composer'),
          constraints: const BoxConstraints(
            minHeight: ChatLayout.minComposerHeight,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.panel(colors)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        input,
                        const SizedBox(height: 4),
                        Row(children: [emoji, attach, const Spacer(), send]),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: input),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: send,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
