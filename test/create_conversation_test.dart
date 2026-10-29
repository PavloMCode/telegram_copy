import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/screens/group_chat_screen.dart';
import 'support/registered_app.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';

Future<void> openCreation(WidgetTester tester, String title) async {
  await pumpRegisteredApp(tester);
  await tester.tap(find.byTooltip('New message'));
  await tester.pumpAndSettle();
  if (title != 'New chat') {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'New chat searches contacts and opens the selected conversation',
    (tester) async {
      await openCreation(tester, 'New chat');
      await tester.enterText(find.byType(TextField), 'Anna');
      await tester.pump();
      expect(find.text('Maksym'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Anna'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId, 'anna');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsOneWidget);
    },
  );

  testWidgets('Group requires members and a name before opening', (
    tester,
  ) async {
    await openCreation(tester, 'New group');
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Anna'));
    await tester.pump();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('1 members'), findsOneWidget);
    await tester.tap(find.byTooltip('Create group'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Study friends');
    await tester.tap(find.byTooltip('Create group'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GroupChatScreen>(find.byType(GroupChatScreen))
          .store
          .groups
          .single
          .name,
      'Study friends',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Public channel generates a stub link and needs no link input', (
    tester,
  ) async {
    await openCreation(tester, 'New channel');
    await tester.enterText(find.byType(TextFormField).first, 'Public news');
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    final link = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data?.startsWith('https://example.invalid/channel/') ??
              false),
    );
    expect(link, findsOneWidget);
    final generated = tester.widget<Text>(link).data;
    await tester.tap(find.text('Private channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public channel'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(link).data, generated);
    await tester.tap(find.byTooltip('Create channel'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GroupChatScreen>(find.byType(GroupChatScreen))
          .store
          .groups
          .single
          .name,
      'Public news',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Private channel creation remains available', (tester) async {
    await openCreation(tester, 'New channel');
    await tester.enterText(find.byType(TextFormField).first, 'Study news');
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private channel'));
    await tester.pumpAndSettle();
    expect(find.text('Invite link'), findsOneWidget);
    await tester.tap(find.byTooltip('Create channel'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GroupChatScreen>(find.byType(GroupChatScreen))
          .store
          .groups
          .single
          .name,
      'Study news',
    );
    expect(tester.takeException(), isNull);
  });
}
