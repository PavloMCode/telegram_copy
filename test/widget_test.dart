import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/main.dart';
import 'package:telegram_frontend/screens/home_screen.dart';
import 'package:telegram_frontend/screens/registration_screen.dart';
import 'support/fake_auth_api.dart';
import 'support/registered_app.dart';

void main() {
  testWidgets(
    'Registration validates password and requires accepted email code',
    (tester) async {
      await tester.pumpWidget(TelegramApp(authApi: FakeAuthApi()));
      await fillRegistration(tester);
      await enterAuthField(tester, 'Confirm password', 'different-password');
      await tapAuthButton(tester, 'Send email code');
      expect(find.text('Passwords do not match'), findsOneWidget);
      await enterAuthField(tester, 'Confirm password', 'a-long-test-password');
      await tapAuthButton(tester, 'Send email code');
      expect(find.byType(HomeScreen), findsNothing);
      await enterAuthField(tester, 'Email code', '000000');
      await tapAuthButton(tester, 'Verify and sign in');
      expect(find.text('Invalid verification code.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await enterAuthField(tester, 'Email code', '123456');
      await tapAuthButton(tester, 'Verify and sign in');
      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).userName,
        'Anna',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Email delivery failure never opens app', (tester) async {
    await tester.pumpWidget(
      TelegramApp(authApi: FakeAuthApi()..failSend = true),
    );
    await fillRegistration(tester);
    await tapAuthButton(tester, 'Send email code');
    expect(
      find.text('Could not send the email. Please try again later.'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsNothing);
    expect(authField('Email code'), findsNothing);
  });

  testWidgets('Login checks password then email code and allows resend', (
    tester,
  ) async {
    final api = FakeAuthApi()..failLogin = true;
    await tester.pumpWidget(TelegramApp(authApi: api));
    await tester.scrollUntilVisible(
      find.text('Already have an account? Sign in'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
    await enterAuthField(tester, 'Email', 'anna@example.com');
    await enterAuthField(tester, 'Password', 'a-long-test-password');
    await tapAuthButton(tester, 'Send email code');
    expect(find.text('Invalid email or password.'), findsOneWidget);
    api.failLogin = false;
    await tapAuthButton(tester, 'Send email code');
    await tester.scrollUntilVisible(
      find.text('Resend code'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    await enterAuthField(tester, 'Email code', '123456');
    await tapAuthButton(tester, 'Verify and sign in');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Logout revokes session and cannot navigate back to account', (
    tester,
  ) async {
    final api = FakeAuthApi();
    await pumpRegisteredApp(tester, authApi: api);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 1);
    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(RegistrationScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets('Registration fits narrow screen with keyboard and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpRegisteredApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
