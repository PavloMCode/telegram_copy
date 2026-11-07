import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/data/demo_data.dart';
import 'package:telegram_frontend/models/local_group.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_account_store.dart';
import 'package:telegram_frontend/services/local_contact_store.dart';
import 'package:telegram_frontend/services/local_database.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/services/group_media_files.dart';
import 'package:telegram_frontend/services/stored_platform_file.dart';
import 'package:telegram_frontend/widgets/account_data_scope.dart';
import 'package:telegram_frontend/widgets/contact_scope.dart';
import 'package:telegram_frontend/widgets/group_scope.dart';
import 'package:telegram_frontend/widgets/chat/forward_message.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = AuthProfile('Admin', '+441234567890');
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Forwarding preserves history, origin and independent attachments across restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'telegram-forward-',
      );
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      var database = await LocalDatabase.open(
        path: '${directory.path}/app.sqlite',
      );
      final data = LocalAccountStore(profile, database: database);
      final groups = LocalGroupStore(profile, database: database);
      addTearDown(() async {
        data.dispose();
        groups.dispose();
        await database.close();
        PathProviderPlatform.instance = originalPaths;
        await directory.delete(recursive: true);
      });
      await data.load();
      final source = await groups.create(
        name: 'Source team',
        description: '',
        memberIds: ['anna'],
      );
      final target = await groups.create(
        name: 'Target team',
        description: '',
        memberIds: ['maksym'],
      );
      final channel = await groups.createChannel(name: 'Updates');
      final sourceFile = File('${directory.path}/source.gif');
      await sourceFile.writeAsBytes([71, 73, 70, 56, 57, 97]);
      final media = await saveGroupMedia(
        data.accountId,
        source,
        StoredPlatformFile('animation.gif', sourceFile.path, 6),
        GroupMediaKind.gif,
      );
      await data.saveConversation('anna', 'Anna', [
        {'id': 'old', 'text': 'Keep history', 'time': '2026-10-29T10:00:00'},
      ]);
      final attachments = [forwardedGroupMedia(media)];
      await sendForwardedMessage(
        data: data,
        groups: groups,
        recipient: const ForwardRecipient('anna', 'Anna'),
        text: 'Shared message',
        origin: 'Source team',
        attachments: attachments,
      );
      await sendForwardedMessage(
        data: data,
        groups: groups,
        recipient: ForwardRecipient(target, 'Target team', group: true),
        text: '',
        origin: 'Source team',
        attachments: attachments,
      );
      await sendForwardedMessage(
        data: data,
        groups: groups,
        recipient: ForwardRecipient(
          channel,
          'Updates',
          group: true,
          channel: true,
        ),
        text: 'Channel post',
        origin: 'Anna',
        attachments: [],
      );
      expect(data.forwardVersion('anna'), 1);
      await groups.delete(source);
      await removeGroupMedia(data.accountId, source);
      await database.close();
      database = await LocalDatabase.open(path: '${directory.path}/app.sqlite');
      final restoredData = LocalAccountStore(profile, database: database);
      final restoredGroups = LocalGroupStore(profile, database: database);
      addTearDown(restoredData.dispose);
      addTearDown(restoredGroups.dispose);
      await restoredData.load();
      await restoredGroups.load();
      final direct = await restoredData.messages('anna');
      expect(direct.map((m) => m['text']), ['Shared message', 'Keep history']);
      expect(direct.first['forwarded'], 'Source team');
      final directCopy = (direct.first['files'] as List).single as Map;
      expect(await File(directCopy['path'] as String).readAsBytes(), [
        71,
        73,
        70,
        56,
        57,
        97,
      ]);
      final groupMessage = restoredGroups.find(target)!.messages.single;
      expect(groupMessage.forwardedFrom, 'Source team');
      expect(groupMessage.media.single.kind, GroupMediaKind.gif);
      expect(await File(groupMessage.media.single.path).exists(), isTrue);
      expect(
        restoredGroups.find(channel)!.messages.single.forwardedFrom,
        'Anna',
      );
    },
  );

  testWidgets(
    'Picker searches real contacts, groups and channels; cancel does not send',
    (tester) async {
      final data = LocalAccountStore(profile);
      await data.load();
      await data.saveContact(
        const DemoContact('new-contact', 'New colleague', '+441234567891'),
      );
      final groups = LocalGroupStore(profile);
      final id = await groups.create(
        name: 'Created team',
        description: '',
        memberIds: ['anna'],
      );
      await groups.createChannel(name: 'Created channel');
      final contacts = LocalContactStore();
      await contacts.setBlocked('anna', true);
      addTearDown(data.dispose);
      addTearDown(groups.dispose);
      addTearDown(contacts.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDataScope(
            store: data,
            child: ContactScope(
              store: contacts,
              child: GroupScope(
                store: groups,
                child: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => forwardChatMessage(
                        context,
                        sourceId: 'source',
                        origin: 'Source',
                        text: 'Forwarded text',
                        attachments: [],
                      ),
                      child: const Text('Open forwarding'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open forwarding'));
      await tester.pumpAndSettle();
      expect(find.text('New colleague'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Created');
      await tester.pumpAndSettle();
      expect(find.text('Created team'), findsOneWidget);
      expect(find.text('Created channel'), findsOneWidget);
      expect(find.text('Anna'), findsNothing);
      expect(find.text('Study Group'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Created team');
      await tester.pumpAndSettle();
      expect(find.text('Created channel'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Created team'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(groups.find(id)!.messages, isEmpty);
      await tester.tap(find.text('Open forwarding'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Created team');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Created team'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Forward'));
      await tester.pumpAndSettle();
      expect(groups.find(id)!.messages.single.text, 'Forwarded text');
      expect(groups.find(id)!.messages.single.forwardedFrom, 'Source');
      expect(tester.takeException(), isNull);
    },
  );
}
