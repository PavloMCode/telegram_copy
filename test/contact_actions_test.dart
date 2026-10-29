import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/main.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_contact_store.dart';
import 'package:telegram_frontend/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Blocking survives restart, stays account-specific and supports unblock',
    () async {
      final store = LocalContactStore(accountId: 'admin');
      await store.setBlocked('anna', true);
      final restored = LocalContactStore(accountId: 'admin');
      await restored.load();
      expect(restored.isBlocked('anna'), isTrue);
      final other = LocalContactStore(accountId: 'other');
      await other.load();
      expect(other.isBlocked('anna'), isFalse);
      await restored.setBlocked('anna', false);
      final afterUnblock = LocalContactStore(accountId: 'admin');
      await afterUnblock.load();
      expect(afterUnblock.isBlocked('anna'), isFalse);
      restored.clearHistory('anna');
      expect(restored.clearVersion('anna'), 1);
      expect(restored.clearVersion('maksym'), 0);
    },
  );

  testWidgets('Block in chat, unblock in profile, clear history in profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Keep until cleared');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Block'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Call Anna',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked'), findsOneWidget);
    final callButton = find
        .ancestor(
          of: find.text('Call'),
          matching: find.byWidgetPredicate(
            (widget) => widget is OutlinedButton,
          ),
        )
        .first;
    expect(tester.widget<OutlinedButton>(callButton).onPressed, isNull);
    await tester.tap(find.byTooltip('Contact options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock user').last);
    await tester.pumpAndSettle();
    expect(find.text('Blocked'), findsNothing);
    expect(tester.widget<OutlinedButton>(callButton).onPressed, isNotNull);
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Keep until cleared'), findsOneWidget);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Contact options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Keep until cleared'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Blocking in profile is respected by New chat and after restarting the app',
    (tester) async {
      const app = TelegramApp(
        initialProfile: AuthProfile('Admin', '+380991234567'),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Contact options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block user').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Call Anna',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Chats'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New message'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Anna'));
      await tester.pumpAndSettle();
      expect(find.text('Contact blocked'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expect(find.text('Contact blocked'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
