import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';
import 'message_bubble_border.dart';

/// Shared message geometry, typography and receipts for direct and group chats.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.time,
    this.isOwn = true,
    this.isRead = false,
    this.edited = false,
    this.forwardedFrom,
    this.replyPreview,
    this.reaction,
    this.attachments = const [],
    this.onAction,
    this.onRemoveReaction,
  });
  final String text;
  final DateTime time;
  final bool isOwn;
  final bool isRead;
  final bool edited;
  final String? forwardedFrom;
  final String? replyPreview;
  final String? reaction;
  final List<Widget> attachments;
  final ValueChanged<Offset>? onAction;
  final VoidCallback? onRemoveReaction;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPressStart: onAction == null
            ? null
            : (details) => onAction!(details.globalPosition),
        onSecondaryTapUp: onAction == null
            ? null
            : (details) => onAction!(details.globalPosition),
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.sizeOf(context).width *
                ChatLayout.bubbleWidthFraction,
          ),
          margin: const EdgeInsets.only(bottom: ChatLayout.bubbleGap),
          padding: const EdgeInsets.symmetric(
            horizontal: ChatLayout.space12,
            vertical: ChatLayout.space8,
          ),
          decoration: ShapeDecoration(
            color: isOwn
                ? colors.outgoingMessageBackground
                : colors.surfaceContainer,
            shape: MessageBubbleBorder(isOwn: isOwn),
            shadows: const [
              BoxShadow(
                color: AppTheme.messageShadow,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...attachments,
                if (forwardedFrom != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ChatLayout.space4),
                    child: Text(
                      'Forwarded from $forwardedFrom',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (replyPreview != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.replyBackground,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      border: Border(
                        left: BorderSide(
                          color: colors.onSurfaceVariant,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reply',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: ChatLayout.space4),
                        Text(
                          replyPreview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: ChatLayout.messageFontSize,
                      color: colors.onSurface,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: ChatLayout.space4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${edited ? 'edited · ' : ''}${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: ChatLayout.timeFontSize,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: colors.messageTimestamp,
                        ),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: isRead ? 'Read' : 'Sent',
                          child: Icon(
                            isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: ChatLayout.space12,
                            color: isRead ? colors.primary : colors.sentReceipt,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (reaction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: ChatLayout.space4),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: const StadiumBorder(),
                      label: Text('$reaction 1'),
                      tooltip: 'Remove reaction',
                      backgroundColor: colors.reactionBackground,
                      labelStyle: TextStyle(color: colors.onSurface),
                      side: BorderSide.none,
                      onPressed: onRemoveReaction,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
