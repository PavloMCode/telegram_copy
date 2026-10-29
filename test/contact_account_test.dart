import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/data/demo_data.dart';
import 'package:telegram_frontend/screens/contact_account_screen.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/screens/group_chat_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/theme/app_theme.dart';
import 'package:telegram_frontend/widgets/group_scope.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Contact shows its data, copies phone and opens the correct chat',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ContactAccountScreen(contact: DemoContacts.maksym),
        ),
      );
      expect(find.text('Maksym'), findsOneWidget);
      expect(find.text(DemoContacts.maksym.phone), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Copy phone number'));
      await tester.tap(find.byTooltip('Copy phone number'));
      await tester.pumpAndSettle();
      expect(copied, DemoContacts.maksym.phone);
      await tester.ensureVisible(find.text('Message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId,
        'maksym',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Opening a contact from chat returns to the existing conversation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep this message');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactAccountScreen), findsOneWidget);
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactAccountScreen), findsNothing);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Keep this message'), findsOneWidget);
    },
  );

  testWidgets('Common groups come from actual group membership', (
    tester,
  ) async {
    final store = LocalGroupStore(const AuthProfile('Admin', '+380991234567'));
    final commonId = await store.create(
      name: 'Shared study group',
      description: '',
      memberIds: ['anna'],
    );
    await store.create(
      name: 'Other group',
      description: '',
      memberIds: ['olena'],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GroupScope(
          store: store,
          child: const ContactAccountScreen(contact: DemoContacts.anna),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Shared study group'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Groups in common (1)'), findsOneWidget);
    expect(find.text('Other group'), findsNothing);
    await tester.tap(find.text('Shared study group'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GroupChatScreen>(find.byType(GroupChatScreen)).groupId,
      commonId,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('Contact fits a narrow screen with large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const ContactAccountScreen(
            contact: DemoContact(
              'long',
              'Anna with a longer contact name',
              '+380991234561',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      expect(
        find.text('Calls are not available in this frontend demo yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
