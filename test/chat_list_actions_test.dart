import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/widgets/group_scope.dart';
import 'package:telegram_frontend/screens/home_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_account_store.dart';
import 'package:telegram_frontend/widgets/account_data_scope.dart';

void main() {
  testWidgets(
    'Groups and channels pin from list and unpin inside conversation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const profile = AuthProfile('Test', '+441234567890');
      final data = LocalAccountStore(profile);
      await data.load();
      final groups = LocalGroupStore(profile);
      final groupId = await groups.create(
        name: 'Created group',
        description: '',
        memberIds: ['anna'],
      );
      final channelId = await groups.createChannel(name: 'Created channel');
      addTearDown(data.dispose);
      addTearDown(groups.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDataScope(
            store: data,
            child: GroupScope(
              store: groups,
              child: HomeScreen(onSectionSelected: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (id, name) in [
        (groupId, 'Created group'),
        (channelId, 'Created channel'),
      ]) {
        await tester.longPress(find.text(name));
        await tester.pumpAndSettle();
        expect(find.text('Delete chat'), findsNothing);
        await tester.tap(find.text('Pin chat'));
        await tester.pumpAndSettle();
        expect(data.isChatPinned(id), isTrue);
        expect(
          tester.getTopLeft(find.text(name)).dy,
          lessThan(
            tester
                .getTopLeft(
                  find.text(
                    'Created ${name == 'Created group' ? 'channel' : 'group'}',
                  ),
                )
                .dy,
          ),
        );
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Chat options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unpin chat'));
        await tester.pumpAndSettle();
        expect(data.isChatPinned(id), isFalse);
        await tester.tap(find.byTooltip('Chat options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pin chat'));
        await tester.pumpAndSettle();
        expect(data.isChatPinned(id), isTrue);
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Return to an unpinned baseline before checking the other category.
        await tester.longPress(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unpin chat'));
        await tester.pumpAndSettle();
      }
      expect(groups.find(groupId), isNotNull);
      expect(groups.find(channelId), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pin sorts chats, deletion supports cancel and hides chat', (
    tester,
  ) async {
    final store = LocalAccountStore(const AuthProfile('Test', '+441234567890'));
    await store.load();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDataScope(
          store: store,
          child: HomeScreen(onSectionSelected: (_) {}),
        ),
      ),
    );
    await tester.longPress(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin chat'));
    await tester.pumpAndSettle();
    expect(store.isChatPinned('anna'), isTrue);
    expect(
      tester.getTopLeft(find.text('Anna')).dy,
      lessThan(tester.getTopLeft(find.text('Maksym')).dy),
    );
    await tester.longPress(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    await tester.longPress(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete chat'));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsNothing);
    expect(store.contact('anna'), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
