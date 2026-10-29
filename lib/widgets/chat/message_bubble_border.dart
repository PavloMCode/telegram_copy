import 'package:flutter/material.dart';
import 'chat_layout.dart';

class MessageBubbleBorder extends ShapeBorder {
  const MessageBubbleBorder({required this.isOwn});

  final bool isOwn;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
    left: isOwn ? 0 : ChatLayout.tailWidth,
    right: isOwn ? ChatLayout.tailWidth : 0,
  );

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final bodyRect = Rect.fromLTRB(
      rect.left + (isOwn ? 0 : ChatLayout.tailWidth),
      rect.top,
      rect.right - (isOwn ? ChatLayout.tailWidth : 0),
      rect.bottom,
    );
    final body = Path()
      ..addRRect(
        BorderRadius.only(
          topLeft: const Radius.circular(ChatLayout.bubbleRadius),
          topRight: const Radius.circular(ChatLayout.bubbleRadius),
          bottomLeft: Radius.circular(
            isOwn ? ChatLayout.bubbleRadius : ChatLayout.bubbleTailCornerRadius,
          ),
          bottomRight: Radius.circular(
            isOwn ? ChatLayout.bubbleTailCornerRadius : ChatLayout.bubbleRadius,
          ),
        ).toRRect(bodyRect),
      );
    final edge = isOwn ? bodyRect.right : bodyRect.left;
    final direction = isOwn ? 1.0 : -1.0;
    final tail = Path()
      ..moveTo(
        edge - direction * ChatLayout.bubbleTailCornerRadius,
        rect.bottom - ChatLayout.tailHeight,
      )
      ..quadraticBezierTo(
        edge + direction * 2,
        rect.bottom - ChatLayout.space4,
        edge + direction * ChatLayout.tailWidth,
        rect.bottom,
      )
      ..quadraticBezierTo(
        edge + direction * 2,
        rect.bottom,
        edge - direction * ChatLayout.bubbleTailCornerRadius,
        rect.bottom,
      )
      ..close();
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}
