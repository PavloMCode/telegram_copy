import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/main.dart';
import 'package:telegram_frontend/navigation/main_section.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/screens/contact_account_screen.dart';
import 'package:telegram_frontend/screens/contacts_screen.dart';
import 'package:telegram_frontend/screens/home_screen.dart';
import 'package:telegram_frontend/screens/settings_screen.dart';
import 'package:telegram_frontend/screens/settings_screen_account.dart';
import 'package:telegram_frontend/screens/settings_screen_notifications.dart';
import 'package:telegram_frontend/screens/settings_screen_notifications_exceptions.dart';
import 'package:telegram_frontend/widgets/app_drawer.dart';

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Future<void> selectSection(WidgetTester tester, String title) async {
  await openDrawer(tester);
  await tester.tap(find.widgetWithText(ListTile, title));
  await tester.pumpAndSettle();
}

void expectMainSection(WidgetTester tester, Type screen) {
  expect(find.byType(screen), findsOneWidget);
  expect(find.byTooltip('Open navigation menu'), findsOneWidget);
  expect(find.byType(BackButton), findsNothing);
  expect(Navigator.of(tester.element(find.byType(screen))).canPop(), isFalse);
}

Future<void> expectDetail(WidgetTester tester, Type screen) async {
  expect(find.byType(screen), findsOneWidget);
  expect(find.byType(BackButton), findsOneWidget);
  expect(find.byTooltip('Open navigation menu'), findsNothing);
  expect(tester.widget<Scaffold>(find.byType(Scaffold)).drawer, isNull);
  await tester.dragFrom(const Offset(1, 300), const Offset(260, 0));
  await tester.pumpAndSettle();
  expect(find.byType(AppDrawer), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Main sections share a drawer without adding routes', (
    tester,
  ) async {
    await tester.pumpWidget(const TelegramApp());
    await tester.pumpAndSettle();
    expectMainSection(tester, HomeScreen);
    for (final (title, section, screen) in [
      ('Contacts', MainSection.contacts, ContactsScreen),
      ('Settings', MainSection.settings, SettingsScreen),
      ('Chats', MainSection.chats, HomeScreen),
      ('Settings', MainSection.settings, SettingsScreen),
      ('Contacts', MainSection.contacts, ContactsScreen),
    ]) {
      await selectSection(tester, title);
      expectMainSection(tester, screen);
      await openDrawer(tester);
      expect(
        tester.widget<AppDrawer>(find.byType(AppDrawer)).selectedSection,
        section,
      );
      for (final label in ['Chats', 'Contacts', 'Settings']) {
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, label))
              .selected,
          label == title,
        );
      }
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Saved Messages'))
            .selected,
        isFalse,
      );
      await tester.tap(find.widgetWithText(ListTile, title));
      await tester.pumpAndSettle();
      expectMainSection(tester, screen);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saved Messages keeps Back and returns to its source section', (
    tester,
  ) async {
    await tester.pumpWidget(const TelegramApp());
    await tester.pumpAndSettle();
    for (final (title, screen) in [
      ('Chats', HomeScreen),
      ('Contacts', ContactsScreen),
      ('Settings', SettingsScreen),
    ]) {
      await selectSection(tester, title);
      await selectSection(tester, 'Saved Messages');
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId,
        'saved',
      );
      await expectDetail(tester, ChatScreen);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expectMainSection(tester, screen);
    }
  });

  testWidgets('Chats and contact profiles use Back without a drawer', (
    tester,
  ) async {
    await tester.pumpWidget(const TelegramApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await expectDetail(tester, ChatScreen);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expectMainSection(tester, HomeScreen);
    await selectSection(tester, 'Contacts');
    await tester.tap(find.widgetWithText(ListTile, 'Name Surname').first);
    await tester.pumpAndSettle();
    await expectDetail(tester, ContactAccountScreen);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expectMainSection(tester, ContactsScreen);
  });

  testWidgets('Nested settings return through their own screens', (
    tester,
  ) async {
    await tester.pumpWidget(const TelegramApp());
    await tester.pumpAndSettle();
    await selectSection(tester, 'Settings');
    await tester.tap(find.widgetWithText(ListTile, 'Account'));
    await tester.pumpAndSettle();
    await expectDetail(tester, SettingsScreenAccount);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expectMainSection(tester, SettingsScreen);
    await tester.tap(find.widgetWithText(ListTile, 'Notifications'));
    await tester.pumpAndSettle();
    await expectDetail(tester, SettingsScreenNotifications);
    await tester.tap(find.widgetWithText(ListTile, 'Notification exceptions'));
    await tester.pumpAndSettle();
    await expectDetail(tester, SettingsScreenNotificationsExceptions);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await expectDetail(tester, SettingsScreenNotifications);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expectMainSection(tester, SettingsScreen);
  });

  testWidgets(
    'Switching sections preserves search and the menu remains usable',
    (tester) async {
      await tester.pumpWidget(const TelegramApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Anna');
      await tester.pumpAndSettle();
      await selectSection(tester, 'Contacts');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Surname');
      await tester.pumpAndSettle();
      await selectSection(tester, 'Chats');
      expectMainSection(tester, HomeScreen);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Anna',
      );
      expect(find.text('Study Group'), findsNothing);
      await selectSection(tester, 'Contacts');
      expectMainSection(tester, ContactsScreen);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Surname',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
