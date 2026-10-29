import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';

class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.time});
  final DateTime time;
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ChatLayout.space12),
      child: SizedBox(
        height: ChatLayout.dateHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(ChatLayout.dateRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ChatLayout.dateHorizontalPadding,
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                DateUtils.isSameDay(time, DateTime.now())
                    ? 'Today'
                    : '${time.day}/${time.month}/${time.year}',
                style: TextStyle(
                  color: colors.onSecondaryContainer,
                  fontSize: ChatLayout.dateFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
