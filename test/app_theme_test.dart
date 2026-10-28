import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/registered_app.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/screens/home_screen.dart';
import 'package:telegram_frontend/screens/settings_screen.dart';
import 'package:telegram_frontend/screens/settings_screen_notifications.dart';
import 'package:telegram_frontend/screens/settings_screen_notifications_exceptions.dart';
import 'package:telegram_frontend/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Screens and attachment menu inherit the $brightness theme', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpRegisteredApp(tester);
      await tester.pumpAndSettle();

      final expected = brightness == Brightness.dark
          ? AppTheme.dark.colorScheme
          : AppTheme.light.colorScheme;

      void expectTheme(Finder finder) {
        expect(Theme.of(tester.element(finder)).colorScheme, expected);
      }

      expectTheme(find.byType(HomeScreen));
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expectTheme(find.byType(ChatScreen));

      await tester.tap(find.byTooltip('Attach files'));
      await tester.pumpAndSettle();
      expectTheme(find.text('Photo'));
      final photoButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.photo_library_outlined),
      );
      expect(
        photoButton.style!.backgroundColor!.resolve({}),
        AppTheme.photoAttachment,
      );
      expect(
        photoButton.style!.foregroundColor!.resolve({}),
        AppTheme.attachmentForeground,
      );

      // Close the menu and chat, then follow the actual settings navigation.
      Navigator.of(tester.element(find.text('Photo'))).pop();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Settings'));
      await tester.pumpAndSettle();
      expectTheme(find.byType(SettingsScreen));

      await tester.tap(find.widgetWithText(ListTile, 'Notifications'));
      await tester.pumpAndSettle();
      expectTheme(find.byType(SettingsScreenNotifications));
      await tester.tap(
        find.widgetWithText(ListTile, 'Notification exceptions'),
      );
      await tester.pumpAndSettle();
      expectTheme(find.byType(SettingsScreenNotificationsExceptions));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('An open screen follows changes to the system theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpRegisteredApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();

    final chat = find.byType(ChatScreen);
    expect(AppTheme.colorsOf(tester.element(chat)), AppTheme.light.colorScheme);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(AppTheme.colorsOf(tester.element(chat)), AppTheme.dark.colorScheme);
    expect(tester.takeException(), isNull);
  });
}
