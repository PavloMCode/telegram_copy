import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/models/local_group.dart';
import 'package:telegram_frontend/screens/group_chat_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/theme/app_theme.dart';
import 'package:telegram_frontend/widgets/chat/message_bubble.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('Group chat matches direct-chat geometry at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = LocalGroupStore(
        const AuthProfile('Admin', '+380991234567'),
      );
      final id = await store.create(
        name: 'Study group',
        description: '',
        memberIds: ['anna'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GroupChatScreen(store: store, groupId: id),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, 64);
      expect(tester.getSize(find.byType(CircleAvatar)).width, 36);
      expect(
        tester.getSize(find.byKey(const ValueKey('chat-composer'))).height,
        64,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('chat-input'))).height,
        48,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('chat-send'))),
        const Size(44, 44),
      );
      final text = List.filled(
        3,
        'A longer group message that wraps across multiple lines.',
      ).join(' ');
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final bubble = find
          .ancestor(
            of: find.text(text),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is ShapeDecoration,
            ),
          )
          .first;
      expect(tester.getSize(bubble).width, closeTo(width * .72, .01));
      expect(width - tester.getRect(bubble).right, closeTo(12, .01));
      expect(tester.widget<Text>(find.text(text)).style!.fontSize, 14);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byTooltip('Sent'), findsOneWidget);
      await store.send(id, '', const [
        GroupMedia(
          name: 'a-long-attachment-name.pdf',
          path: '/unused',
          size: 1024,
          kind: GroupMediaKind.file,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('a-long-attachment-name.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Group message reactions, replies, edits and deletion persist', (
    tester,
  ) async {
    final store = LocalGroupStore(const AuthProfile('Admin', '+380991234567'));
    final id = await store.create(
      name: 'Study group',
      description: '',
      memberIds: ['anna'],
    );
    await store.send(id, 'Original message', []);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GroupChatScreen(store: store, groupId: id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Original message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect(find.text('👍 1'), findsOneWidget);
    await tester.longPress(find.text('Original message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cancel reply or forwarding'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A reply');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(store.find(id)!.messages.last.replyPreview, 'Original message');
    await tester.longPress(find.text('A reply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit message'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Edited reply');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.find(id)!.messages.last.edited, isTrue);
    final restored = LocalGroupStore(
      const AuthProfile('Admin', '+380991234567'),
    );
    await restored.load();
    expect(restored.find(id)!.messages.last.text, 'Edited reply');
    expect(restored.find(id)!.messages.first.reaction, '👍');
    await tester.longPress(find.text('Edited reply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();
    expect(find.text('Edited reply'), findsNothing);
    expect(find.byType(ChatMessageBubble), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
