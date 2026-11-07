import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/main.dart';

import 'fake_auth_api.dart';

Finder authField(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

Future<void> enterAuthField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final finder = authField(label);
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> tapAuthButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillRegistration(WidgetTester tester) async {
  await enterAuthField(tester, 'Phone number', '+380991234567');
  await tapAuthButton(tester, 'Continue');
  await enterAuthField(tester, 'First name', 'Anna');
  await enterAuthField(tester, 'Email', 'anna@example.com');
  await enterAuthField(tester, 'Password', 'a-long-test-password');
  await enterAuthField(tester, 'Confirm password', 'a-long-test-password');
}

Future<void> pumpRegisteredApp(
  WidgetTester tester, {
  FakeAuthApi? authApi,
}) async {
  await tester.pumpWidget(TelegramApp(authApi: authApi ?? FakeAuthApi()));
  await fillRegistration(tester);
  await tapAuthButton(tester, 'Send email code');
  await enterAuthField(tester, 'Email code', '123456');
  await tapAuthButton(tester, 'Verify and sign in');
}
