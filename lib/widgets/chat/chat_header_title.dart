import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';

class ChatHeaderTitle extends StatelessWidget {
  const ChatHeaderTitle({
    super.key,
    required this.name,
    required this.status,
    this.icon,
    this.photo,
    this.onTap,
  });
  final String name;
  final String status;
  final IconData? icon;
  final ImageProvider? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final content = Row(
      children: [
        CircleAvatar(
          radius: ChatLayout.avatarSize / 2,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          backgroundImage: photo,
          child: photo != null
              ? null
              : icon != null
              ? Icon(icon)
              : Text(
                  name.trim().isEmpty
                      ? '?'
                      : name.trim().characters.first.toUpperCase(),
                ),
        ),
        const SizedBox(width: ChatLayout.space12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: ChatLayout.nameFontSize,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ChatLayout.statusFontSize,
                  height: 1.2,
                  color: colors.onPrimaryMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
