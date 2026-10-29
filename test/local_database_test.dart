import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/data/demo_data.dart';
import 'package:telegram_frontend/models/local_group.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_account_store.dart';
import 'package:telegram_frontend/services/local_database.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/services/local_contact_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LocalDatabase database;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('telegram-storage-');
    database = await LocalDatabase.open(path: '${directory.path}/app.sqlite');
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'Messages, drafts, contacts, profile and settings survive database reopen',
    () async {
      const profile = AuthProfile('Admin', '+380991234567');
      final account = LocalAccountStore(profile, database: database);
      await account.load();
      await account.saveProfile({
        'name': 'New Admin',
        'phone': profile.phone,
        'nickname': 'admin',
        'about': 'Local profile',
        'birthday': '01/01/2000',
      });
      await account.setSetting('notifications', false);
      await account.saveContact(
        const DemoContact('custom', 'New contact', '+12345678901'),
      );
      await account.removeContact('anna');
      await account.saveConversation('maksym', 'Maksym', [
        {
          'id': 'm1',
          'text': 'Hello',
          'time': '2026-10-29T10:00:00',
          'files': [],
        },
      ]);
      await account.saveDraft('maksym', {
        'text': 'Unsent draft',
        'files': [],
        'reply': 'Hello',
      });
      await database.close();
      database = await LocalDatabase.open(path: '${directory.path}/app.sqlite');
      final restored = LocalAccountStore(profile, database: database);
      await restored.load();
      expect(restored.profile.name, 'New Admin');
      expect(restored.setting('notifications'), isFalse);
      expect(restored.contact('custom')!.name, 'New contact');
      expect(restored.contact('anna'), isNull);
      expect((await restored.messages('maksym')).single['text'], 'Hello');
      expect((await restored.draft('maksym'))!['text'], 'Unsent draft');
      final other = LocalAccountStore(
        const AuthProfile('Other', '+987654321'),
        database: database,
      );
      await other.load();
      expect(await other.messages('maksym'), isEmpty);
      expect(other.contact('custom'), isNull);
      expect(other.profile.name, 'Other');
      await restored.clearConversation('maksym');
      expect(await restored.messages('maksym'), isEmpty);
    },
  );

  test(
    'Legacy groups migrate once and legacy preferences remain intact',
    () async {
      const profile = AuthProfile('Admin', '+380991234567');
      final group = LocalGroup(
        id: 'local-group-123',
        name: 'Legacy group',
        description: 'Keep this',
        members: [
          GroupMember(id: profile.phone, name: 'Admin', role: GroupRole.owner),
        ],
        messages: [
          GroupMessage(
            id: 'legacy-message',
            text: 'Legacy history',
            sentAt: DateTime(2026, 10, 29),
          ),
        ],
      );
      final old = jsonEncode([group.toJson()]);
      SharedPreferences.setMockInitialValues({
        'local_groups_v1_${profile.phone}': old,
        'local_blocked_contacts_v1_${profile.phone}': ['anna'],
      });
      final groups = LocalGroupStore(profile, database: database);
      await groups.load();
      expect(groups.find(group.id)!.messages.single.text, 'Legacy history');
      await groups.update(
        group.id,
        name: 'Updated in SQLite',
        description: 'Updated',
      );
      final restored = LocalGroupStore(profile, database: database);
      await restored.load();
      expect(restored.find(group.id)!.name, 'Updated in SQLite');
      expect(
        (await SharedPreferences.getInstance()).getString(groups.storageKey),
        old,
      );
      final contacts = LocalContactStore(
        accountId: profile.phone,
        database: database,
      );
      await contacts.load();
      expect(contacts.isBlocked('anna'), isTrue);
      await contacts.setBlocked('anna', false);
      final newContacts = LocalContactStore(
        accountId: profile.phone,
        database: database,
      );
      await newContacts.load();
      expect(newContacts.isBlocked('anna'), isFalse);
    },
  );

  test(
    'Message replacement rolls back on duplicate IDs instead of losing history',
    () async {
      await database.saveConversation(
        'admin',
        'anna',
        [
          {'id': '1', 'text': 'Keep'},
        ],
        {'name': 'Anna'},
      );
      await expectLater(
        database.saveConversation(
          'admin',
          'anna',
          [
            {'id': '2', 'text': 'First'},
            {'id': '2', 'text': 'Duplicate'},
          ],
          {'name': 'Changed'},
        ),
        throwsA(anything),
      );
      expect((await database.messages('admin', 'anna')).single['text'], 'Keep');
      expect(
        (await database.get('admin', 'conversations', 'anna'))!['name'],
        'Anna',
      );
    },
  );
}
