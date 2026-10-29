import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/main.dart';
import 'package:telegram_frontend/screens/main_screen.dart';
import 'package:telegram_frontend/screens/accounts_screen.dart';
import 'package:telegram_frontend/services/local_auth_api.dart';
import 'support/registered_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Adding can be cancelled, verified account opens and switching clears old routes',
    (tester) async {
      final api = LocalAuthApi();
      final challenge = await api.register(
        phone: '+441234567890',
        name: 'Admin',
        email: 'admin@example.com',
        password: 'admin-password',
      );
      final profile = await api.verify(challenge.id, '123456');
      await tester.pumpWidget(
        TelegramApp(authApi: api, initialProfile: profile),
      );
      await tester.pumpAndSettle();
      Future<void> openAccounts() async {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Accounts'));
        await tester.pumpAndSettle();
      }

      await openAccounts();
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel adding account'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountsScreen), findsOneWidget);
      expect((await api.restoreSession())?.name, 'Admin');
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      await fillRegistration(tester);
      await tapAuthButton(tester, 'Send email code');
      await enterAuthField(tester, 'Email code', '123456');
      await tapAuthButton(tester, 'Verify and sign in');
      expect(
        tester.widget<MainScreen>(find.byType(MainScreen)).profile?.name,
        'Anna',
      );
      expect((await api.signedInProfiles()).length, 2);
      await openAccounts();
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MainScreen>(find.byType(MainScreen)).profile?.name,
        'Admin',
      );
      expect(
        Navigator.of(tester.element(find.byType(MainScreen))).canPop(),
        isFalse,
      );
      expect((await LocalAuthApi().restoreSession())?.name, 'Admin');
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notification preferences and exceptions'));
      await tester.pumpAndSettle();
      final allAccounts = find.byKey(
        const ValueKey('notifications_all_accounts'),
      );
      expect(tester.widget<Switch>(allAccounts).value, isTrue);
      await tester.tap(allAccounts);
      await tester.pumpAndSettle();
      expect(await LocalAuthApi().notificationsFromAllAccounts(), isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile, phone number and personal details'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Log out'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MainScreen>(find.byType(MainScreen)).profile?.name,
        'Anna',
      );
      expect((await LocalAuthApi().signedInProfiles()).length, 1);
      expect(
        Navigator.of(tester.element(find.byType(MainScreen))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
