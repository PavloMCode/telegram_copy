import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/screens/settings_screen_privacy.dart';
import 'package:telegram_frontend/screens/settings_screen_security.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_account_store.dart';
import 'package:telegram_frontend/services/local_contact_store.dart';
import 'package:telegram_frontend/theme/app_theme.dart';
import 'package:telegram_frontend/widgets/account_data_scope.dart';
import 'package:telegram_frontend/widgets/contact_scope.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<LocalAccountStore> accountStore() async {
    final store = LocalAccountStore(
      const AuthProfile('Test User', '+441234567890'),
    );
    await store.load();
    return store;
  }

  testWidgets('Security preferences update the account store', (tester) async {
    final store = await accountStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountDataScope(
          store: store,
          child: const SettingsScreenSecurity(),
        ),
      ),
    );

    final alerts = find.byKey(const ValueKey('security_login_alerts'));
    expect(tester.widget<Switch>(alerts).value, isTrue);
    await tester.tap(alerts);
    await tester.pumpAndSettle();

    expect(store.setting('security_login_alerts'), isFalse);
    expect(tester.widget<Switch>(alerts).value, isFalse);
  });

  testWidgets('Privacy visibility and blocked users can be managed', (
    tester,
  ) async {
    final store = await accountStore();
    final contacts = LocalContactStore(accountId: store.accountId);
    await contacts.load();
    addTearDown(store.dispose);
    addTearDown(contacts.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountDataScope(
          store: store,
          child: ContactScope(
            store: contacts,
            child: const SettingsScreenPrivacy(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Phone number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nobody'));
    await tester.pumpAndSettle();
    expect(
      store.settingValue<String>('privacy_phone', fallback: 'My contacts'),
      'Nobody',
    );

    await tester.scrollUntilVisible(
      find.text('Blocked users'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Blocked users'));
    await tester.pumpAndSettle();
    expect(find.text('No blocked users'), findsOneWidget);
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(contacts.isBlocked('anna'), isTrue);
    expect(find.text('Unblock'), findsOneWidget);
  });
}
