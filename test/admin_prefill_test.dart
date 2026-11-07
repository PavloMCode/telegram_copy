import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/screens/main_screen.dart';
import 'package:telegram_frontend/screens/registration_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_auth_api.dart';

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> openLogin(WidgetTester tester) async {
  final button = find.text('Already have an account? Sign in');
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Prefilled admin can sign in through the real local form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RegistrationScreen(authApi: LocalAuthApi())),
    );
    await openLogin(tester);
    final send = find.widgetWithText(FilledButton, 'Send email code');
    await tester.scrollUntilVisible(
      send,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.byType(MainScreen), findsNothing);
    await tester.enterText(input('Email code'), '123456');
    final verify = find.widgetWithText(FilledButton, 'Verify and sign in');
    await tester.scrollUntilVisible(
      verify,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(verify);
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
    expect(
      tester.widget<MainScreen>(find.byType(MainScreen)).profile!.name,
      'Admin',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Local login prefills the test admin and preserves edited credentials',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegistrationScreen(authApi: LocalAuthApi())),
      );
      await openLogin(tester);
      expect(
        tester.widget<TextField>(input('Email')).controller!.text,
        LocalAuthApi.testAdminEmail,
      );
      expect(
        tester.widget<TextField>(input('Password')).controller!.text,
        LocalAuthApi.testAdminPassword,
      );
      expect(tester.widget<TextField>(input('Password')).obscureText, isTrue);
      await tester.enterText(input('Email'), 'another@example.com');
      await tester.enterText(input('Password'), 'another-password');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await openLogin(tester);
      expect(
        tester.widget<TextField>(input('Email')).controller!.text,
        'another@example.com',
      );
      expect(
        tester.widget<TextField>(input('Password')).controller!.text,
        'another-password',
      );
    },
  );

  testWidgets('Server login is not filled with local test credentials', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RegistrationScreen(authApi: AuthApi())),
    );
    await openLogin(tester);
    expect(tester.widget<TextField>(input('Email')).controller!.text, isEmpty);
    expect(
      tester.widget<TextField>(input('Password')).controller!.text,
      isEmpty,
    );
  });
}
