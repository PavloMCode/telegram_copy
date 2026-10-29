import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';

class ChatReplyBanner extends StatelessWidget {
  const ChatReplyBanner({
    super.key,
    required this.title,
    required this.preview,
    required this.onCancel,
    this.forward = false,
  });
  final String title;
  final String preview;
  final VoidCallback onCancel;
  final bool forward;
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            forward ? Icons.forward_rounded : Icons.reply_rounded,
            color: colors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: ChatLayout.space12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colors.primary, width: 3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Cancel reply or forwarding',
            icon: const Icon(Icons.close, size: 20),
            color: colors.onSurfaceVariant,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
