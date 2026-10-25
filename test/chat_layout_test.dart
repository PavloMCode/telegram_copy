import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/theme/app_theme.dart';

Finder bubbleFor(String text) => find
    .ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox && widget.decoration is ShapeDecoration,
      ),
    )
    .first;

void main() {
  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('Chat geometry and multiline messages fit a $width px screen', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppBar)).height, 64);
      expect(tester.getSize(find.byType(CircleAvatar)), const Size(36, 36));
      expect(tester.widget<Text>(find.text('Anna')).style!.fontSize, 16);
      expect(
        tester.widget<Text>(find.text('Local chat · offline')).style!.fontSize,
        11,
      );

      final composer = find.byKey(const ValueKey('chat-composer'));
      final input = find.byKey(const ValueKey('chat-input'));
      final send = find.byKey(const ValueKey('chat-send'));
      expect(tester.getSize(composer).height, 64);
      expect(tester.getSize(input).height, 48);
      expect(tester.getSize(send), const Size(44, 44));
      final inputRect = tester.getRect(input);
      final sendRect = tester.getRect(send);
      expect(inputRect.left, 8);
      expect(sendRect.left - inputRect.right, 8);
      expect(width - sendRect.right, 8);

      final longMessage = List.filled(
        2,
        'A longer message that wraps across several lines and checks bubble '
        'width on phones and larger screens.',
      ).join(' ');
      await tester.enterText(find.byType(TextField), longMessage);
      await tester.pumpAndSettle();
      expect(tester.getSize(input).height, greaterThan(48));
      expect(
        tester.getSize(composer).height,
        tester.getSize(input).height + 16,
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final firstBubble = bubbleFor(longMessage);
      final firstRect = tester.getRect(firstBubble);
      expect(firstRect.width, closeTo(width * 0.72, 0.01));
      expect(width - firstRect.right, closeTo(12, 0.01));
      final messageRect = tester.getRect(find.text(longMessage));
      expect(messageRect.left - firstRect.left, closeTo(12, 0.01));
      expect(messageRect.top - firstRect.top, closeTo(8, 0.01));
      expect(tester.widget<Text>(find.text(longMessage)).style!.fontSize, 14);

      final decoration =
          tester.widget<DecoratedBox>(firstBubble).decoration
              as ShapeDecoration;
      final rect = Offset.zero & firstRect.size;
      final bounds = decoration.shape.getOuterPath(rect).getBounds();
      expect(bounds.left, closeTo(rect.left, 0.01));
      expect(bounds.top, closeTo(rect.top, 0.01));
      expect(bounds.right, closeTo(rect.right, 0.01));
      expect(bounds.bottom, closeTo(rect.bottom, 0.01));

      final date = find
          .ancestor(of: find.text('Today'), matching: find.byType(DecoratedBox))
          .first;
      expect(tester.getSize(date).height, 24);
      expect(tester.widget<Text>(find.text('Today')).style!.fontSize, 10);

      final time = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
      );
      expect(tester.widget<Text>(time).style!.fontSize, 10);
      expect(tester.getRect(time).top - messageRect.bottom, closeTo(4, 0.01));

      await tester.enterText(find.byType(TextField), 'Next message');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(bubbleFor('Next message')).top -
            tester.getRect(bubbleFor(longMessage)).bottom,
        closeTo(6, 0.01),
      );

      const multiline = 'First line\nSecond line\nThird line\nFourth line';
      await tester.enterText(find.byType(TextField), multiline);
      await tester.pumpAndSettle();
      expect(tester.getSize(input).height, greaterThan(48));
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text(multiline), findsOneWidget);
      expect(tester.getSize(input).height, 48);
      expect(tester.getSize(composer).height, 64);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A narrow chat supports larger text, keyboard and replies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const ChatScreen(
          chatId: 'anna',
          chatName: 'Anna with a longer contact name',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Original message');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Original message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.enterText(find.byType(TextField), 'First line\nSecond line');
    await tester.pumpAndSettle();
    final composer = find.byKey(const ValueKey('chat-composer'));
    final input = find.byKey(const ValueKey('chat-input'));
    expect(tester.getSize(input).height, greaterThan(48));
    expect(tester.getSize(composer).height, tester.getSize(input).height + 16);
    expect(tester.getRect(composer).bottom, closeTo(460, 0.01));
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('First line\nSecond line'), findsOneWidget);
    expect(find.byTooltip('Cancel reply or forwarding'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Composer grows upward to six lines and shrinks after deletion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('chat-input'));
    final composer = find.byKey(const ValueKey('chat-composer'));
    final send = find.byKey(const ValueKey('chat-send'));
    final bottom = tester.getRect(composer).bottom;
    final sendBottom = tester.getRect(send).bottom;
    final emojiBottom = tester.getRect(find.byTooltip('Emoji')).bottom;
    final attachBottom = tester.getRect(find.byTooltip('Attach files')).bottom;
    var previousHeight = tester.getSize(input).height;

    for (var lines = 2; lines <= 6; lines++) {
      await tester.enterText(
        find.byType(TextField),
        List.generate(lines, (index) => 'Line ${index + 1}').join('\n'),
      );
      await tester.pumpAndSettle();
      final height = tester.getSize(input).height;
      expect(height, greaterThan(previousHeight));
      expect(tester.getSize(composer).height, height + 16);
      expect(tester.getRect(composer).bottom, bottom);
      expect(tester.getRect(send).bottom, sendBottom);
      expect(tester.getRect(find.byTooltip('Emoji')).bottom, emojiBottom);
      expect(
        tester.getRect(find.byTooltip('Attach files')).bottom,
        attachBottom,
      );
      previousHeight = height;
    }

    await tester.enterText(
      find.byType(TextField),
      List.generate(10, (index) => 'Line ${index + 1}').join('\n'),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(input).height, previousHeight);
    expect(tester.getRect(send).bottom, sendBottom);

    await tester.enterText(find.byType(TextField), 'Short');
    await tester.pumpAndSettle();
    expect(tester.getSize(input).height, 48);
    expect(tester.getSize(composer).height, 64);
    expect(tester.getRect(composer).bottom, bottom);
    expect(tester.takeException(), isNull);
  });
}
