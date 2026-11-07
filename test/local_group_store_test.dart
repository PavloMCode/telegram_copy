import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/models/local_group.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = AuthProfile('Admin', '+380991234567');
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Group details, members, messages and media survive a new store',
    () async {
      final store = LocalGroupStore(profile);
      final id = await store.create(
        name: 'Study',
        description: 'Homework',
        memberIds: ['anna'],
      );
      expect(store.find(id)!.members.length, 2);
      await store.update(id, name: 'Study friends', description: 'Updated');
      await store.addMembers(id, ['maksym', 'anna']);
      expect(store.find(id)!.members.length, 3);
      await store.send(id, 'Hello', const [
        GroupMedia(
          name: 'voice.m4a',
          path: '/saved/voice.m4a',
          size: 1024,
          kind: GroupMediaKind.voice,
        ),
      ]);
      final restored = LocalGroupStore(profile);
      await restored.load();
      final group = restored.find(id)!;
      expect(group.name, 'Study friends');
      expect(group.description, 'Updated');
      expect(group.messages.single.text, 'Hello');
      expect(group.media.single.kind, GroupMediaKind.voice);
      expect(group.roleOf(profile.phone), GroupRole.owner);
      final anotherAccount = LocalGroupStore(
        const AuthProfile('Other', '+123456789'),
      );
      await anotherAccount.load();
      expect(anotherAccount.groups, isEmpty);
    },
  );

  test('Owner and admin permissions are enforced by the store', () async {
    final store = LocalGroupStore(profile);
    final id = await store.create(
      name: 'Study',
      description: '',
      memberIds: ['anna', 'maksym', 'olena'],
    );
    await expectLater(store.leave(id), throwsA(isA<GroupException>()));
    await expectLater(
      store.removeMember(id, profile.phone),
      throwsA(isA<GroupException>()),
    );
    await store.setRole(id, 'maksym', GroupRole.admin);
    await store.setRole(id, 'anna', GroupRole.owner);
    expect(store.find(id)!.roleOf(profile.phone), GroupRole.admin);
    expect(
      store.find(id)!.members.where((m) => m.role == GroupRole.owner).length,
      1,
    );
    await expectLater(store.delete(id), throwsA(isA<GroupException>()));
    await expectLater(
      store.removeMember(id, 'anna'),
      throwsA(isA<GroupException>()),
    );
    await expectLater(
      store.removeMember(id, 'maksym'),
      throwsA(isA<GroupException>()),
    );
    await expectLater(
      store.setRole(id, 'olena', GroupRole.admin),
      throwsA(isA<GroupException>()),
    );
    await store.removeMember(id, 'olena');
    expect(store.find(id)!.roleOf('olena'), isNull);
    await store.update(id, name: 'Edited by admin', description: '');
    await store.leave(id);
    final restored = LocalGroupStore(profile);
    await restored.load();
    expect(restored.groups, isEmpty);
  });

  test(
    'Owner can delete a group and queued changes do not lose data',
    () async {
      final store = LocalGroupStore(profile);
      final id = await store.create(
        name: 'Study',
        description: '',
        memberIds: ['anna'],
      );
      await Future.wait([
        store.addMembers(id, ['maksym']),
        store.send(id, 'Hello', []),
      ]);
      expect(store.find(id)!.members.length, 3);
      expect(store.find(id)!.messages.length, 1);
      await store.delete(id);
      await expectLater(
        store.send(id, 'After deletion', []),
        throwsA(isA<GroupException>()),
      );
      final restored = LocalGroupStore(profile);
      await restored.load();
      expect(restored.groups, isEmpty);
    },
  );

  test('Ordinary member cannot edit, add, remove or delete', () async {
    final store = LocalGroupStore(profile);
    final id = await store.create(
      name: 'Study',
      description: '',
      memberIds: ['anna'],
    );
    await store.setRole(id, 'anna', GroupRole.owner);
    // Seed the persisted member role to exercise a regular-member session.
    final group = LocalGroup.fromJson(store.find(id)!.toJson());
    group.members.firstWhere((m) => m.id == profile.phone).role =
        GroupRole.member;
    SharedPreferences.setMockInitialValues({
      store.storageKey: jsonEncode([group.toJson()]),
    });
    final member = LocalGroupStore(profile);
    await member.load();
    await expectLater(
      member.update(id, name: 'No', description: ''),
      throwsA(isA<GroupException>()),
    );
    await expectLater(
      member.addMembers(id, ['maksym']),
      throwsA(isA<GroupException>()),
    );
    await expectLater(
      member.removeMember(id, 'anna'),
      throwsA(isA<GroupException>()),
    );
    await expectLater(member.delete(id), throwsA(isA<GroupException>()));
    await member.send(id, 'Member message', []);
    await member.leave(id);
    expect(member.groups, isEmpty);
  });
}
