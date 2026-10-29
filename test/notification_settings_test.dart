import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/models/notification_category.dart';
import 'package:telegram_frontend/screens/settings_screen_notifications_exceptions.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/widgets/group_scope.dart';
import 'package:telegram_frontend/screens/settings_screen_notifications.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_account_store.dart';
import 'package:telegram_frontend/widgets/account_data_scope.dart';

void main() {
  testWidgets(
    'Group and channel exceptions use separate pickers and preserve contacts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const profile = AuthProfile('Test', '+441234567890');
      final store = LocalAccountStore(profile);
      await store.load();
      await store.setNotificationException(
        NotificationCategory.chats,
        'anna',
        false,
      );
      final groups = LocalGroupStore(profile);
      final groupId = await groups.create(
        name: 'Study team',
        description: '',
        memberIds: ['anna'],
      );
      final channelId = await groups.createChannel(name: 'Project news');
      addTearDown(store.dispose);
      addTearDown(groups.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDataScope(
            store: store,
            child: GroupScope(
              store: groups,
              child: const SettingsScreenNotificationsExceptions(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Groups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add exception'));
      await tester.pumpAndSettle();
      expect(find.text('Project news'), findsNothing);
      await tester.tap(find.text('Study team'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      expect(store.notificationExceptions(NotificationCategory.groups), {
        groupId: false,
      });
      await tester.tap(find.widgetWithText(ChoiceChip, 'Channels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add exception'));
      await tester.pumpAndSettle();
      expect(find.text('Study team'), findsNothing);
      await tester.tap(find.text('Project news'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notify'));
      await tester.pumpAndSettle();
      expect(store.notificationExceptions(NotificationCategory.channels), {
        channelId: true,
      });
      expect(store.notificationExceptions(NotificationCategory.chats), {
        'anna': false,
      });
      await tester.tap(find.byTooltip('Edit exception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use default settings'));
      await tester.pumpAndSettle();
      expect(
        store.notificationExceptions(NotificationCategory.channels),
        isEmpty,
      );
      expect(store.notificationExceptions(NotificationCategory.groups), {
        groupId: false,
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Master switch preserves categories and exceptions can be removed',
    (tester) async {
      final store = LocalAccountStore(
        const AuthProfile('Test', '+441234567890'),
      );
      await store.load();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDataScope(
            store: store,
            child: const SettingsScreenNotifications(),
          ),
        ),
      );
      final master = find.byKey(const ValueKey('notifications'));
      final chats = find.byKey(const ValueKey('notify_chats'));
      await tester.tap(chats);
      await tester.pumpAndSettle();
      expect(store.setting('notify_chats'), isFalse);
      await tester.tap(master);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(chats).onChanged, isNull);
      await tester.tap(master);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(chats).value, isFalse);
      expect(tester.widget<Switch>(chats).onChanged, isNotNull);
      await tester.tap(find.text('Notification exceptions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add exception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      expect(store.settings['notification_exceptions'], {'anna': false});
      expect(find.text('Muted'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit exception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use default settings'));
      await tester.pumpAndSettle();
      expect(store.settings['notification_exceptions'], isEmpty);
      expect(find.text('No exceptions yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
