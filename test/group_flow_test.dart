import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/main.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/screens/group_chat_screen.dart';
import 'package:telegram_frontend/screens/group_details_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Create, edit, add/remove members, reopen messages and delete group',
    (tester) async {
      await tester.pumpWidget(
        const TelegramApp(
          initialProfile: AuthProfile('Admin', '+380991234567'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Study friends');
      await tester.enterText(find.byType(TextFormField).last, 'Homework');
      await tester.tap(find.byTooltip('Create group'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupChatScreen), findsOneWidget);
      final chat = tester.widget<GroupChatScreen>(find.byType(GroupChatScreen));
      await tester.enterText(find.byType(TextField), 'Hello group');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Hello group'), findsOneWidget);
      await tester.tap(find.byTooltip('Group settings'));
      await tester.pumpAndSettle();
      expect(find.text('Homework'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Renamed group');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed group'), findsOneWidget);
      await tester.tap(find.text('Add members'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maksym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add selected members'));
      await tester.pumpAndSettle();
      expect(find.text('Maksym'), findsOneWidget);
      await tester.tap(find.byTooltip('Manage Maksym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove member'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Maksym'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Renamed group'), findsOneWidget);
      await tester.tap(find.text('Renamed group'));
      await tester.pumpAndSettle();
      expect(find.text('Hello group'), findsOneWidget);
      final restored = LocalGroupStore(
        const AuthProfile('Admin', '+380991234567'),
      );
      await restored.load();
      expect(restored.find(chat.groupId)!.messages.single.text, 'Hello group');
      await tester.tap(find.byTooltip('Group settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete group').hitTestable(),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Delete group'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete group'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupDetailsScreen), findsNothing);
      expect(find.byType(GroupChatScreen), findsNothing);
      expect(find.text('Renamed group'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
