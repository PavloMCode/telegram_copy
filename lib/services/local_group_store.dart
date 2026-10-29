import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/demo_data.dart';
import '../models/local_group.dart';
import 'auth_api.dart';

class GroupException implements Exception {
  const GroupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Frontend-only groups, isolated by the locally signed-in profile.
class LocalGroupStore extends ChangeNotifier {
  LocalGroupStore(this.profile);
  final AuthProfile profile;
  String get userId => profile.phone;
  String get storageKey => 'local_groups_v1_$userId';
  Map<String, LocalGroup> _groups = {};
  List<LocalGroup> get groups => List.unmodifiable(_groups.values);
  LocalGroup? find(String id) => _groups[id];
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  String? loadError;
  bool _disposed = false;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(storageKey);
      if (raw != null) {
        final entries = (jsonDecode(raw) as List).map(
          (item) => LocalGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        );
        _groups = {for (final group in entries) group.id: group};
      }
      loadError = null;
    } catch (_) {
      loadError =
          'Could not load local groups. Restart the app before creating a group.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _commit(void Function(Map<String, LocalGroup>) change) {
    final operation = _writes.then((_) async {
      await load();
      if (loadError != null) throw GroupException(loadError!);
      final next = {
        for (final entry in _groups.entries)
          entry.key: LocalGroup.fromJson(entry.value.toJson()),
      };
      change(next);
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(
        storageKey,
        jsonEncode(next.values.map((g) => g.toJson()).toList()),
      )) {
        throw const GroupException(
          'Could not save the group. Please try again.',
        );
      }
      _groups = next;
      if (!_disposed) notifyListeners();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  LocalGroup _require(
    Map<String, LocalGroup> groups,
    String id, {
    bool manage = false,
    bool owner = false,
  }) {
    final group = groups[id];
    if (group == null || group.roleOf(userId) == null) {
      throw const GroupException('This group is no longer available.');
    }
    if (owner && group.roleOf(userId) != GroupRole.owner ||
        manage && !group.canManage(userId)) {
      throw const GroupException('You do not have permission for this action.');
    }
    return group;
  }

  Future<String> create({
    required String name,
    required String description,
    required List<String> memberIds,
    Uint8List? photo,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().length > 128 ||
        description.length > 255) {
      throw const GroupException('Enter a valid group name and description.');
    }
    final selected = DemoContacts.all
        .where((c) => memberIds.contains(c.id))
        .toList();
    if (selected.isEmpty) {
      throw const GroupException('Select at least one member.');
    }
    final id = 'local-group-${DateTime.now().microsecondsSinceEpoch}';
    await _commit(
      (groups) => groups[id] = LocalGroup(
        id: id,
        name: name.trim(),
        description: description.trim(),
        photo: photo,
        members: [
          GroupMember(id: userId, name: profile.name, role: GroupRole.owner),
          ...selected.map((c) => GroupMember(id: c.id, name: c.name)),
        ],
      ),
    );
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    required String description,
    Uint8List? photo,
  }) => _commit((groups) {
    final group = _require(groups, id, manage: true);
    if (name.trim().isEmpty ||
        name.trim().length > 128 ||
        description.length > 255) {
      throw const GroupException('Enter a valid group name and description.');
    }
    group.name = name.trim();
    group.description = description.trim();
    group.photo = photo;
  });

  Future<void> addMembers(String id, List<String> memberIds) =>
      _commit((groups) {
        final group = _require(groups, id, manage: true);
        for (final contact in DemoContacts.all.where(
          (c) => memberIds.contains(c.id),
        )) {
          if (group.roleOf(contact.id) == null) {
            group.members.add(GroupMember(id: contact.id, name: contact.name));
          }
        }
      });

  Future<void> removeMember(String id, String memberId) => _commit((groups) {
    final group = _require(groups, id, manage: true);
    final targetRole = group.roleOf(memberId);
    if (memberId == userId ||
        targetRole == GroupRole.owner ||
        (group.roleOf(userId) == GroupRole.admin &&
            targetRole == GroupRole.admin)) {
      throw const GroupException('You cannot remove this member.');
    }
    group.members.removeWhere((m) => m.id == memberId);
  });

  Future<void> setRole(String id, String memberId, GroupRole role) => _commit((
    groups,
  ) {
    final group = _require(groups, id, owner: true);
    if (memberId == userId || !group.members.any((m) => m.id == memberId)) {
      throw const GroupException('Select another group member.');
    }
    if (role == GroupRole.owner) {
      group.members.firstWhere((m) => m.id == userId).role = GroupRole.admin;
    }
    group.members.firstWhere((m) => m.id == memberId).role = role;
  });

  Future<void> leave(String id) => _commit((groups) {
    final group = _require(groups, id);
    if (group.roleOf(userId) == GroupRole.owner) {
      throw const GroupException(
        'Transfer ownership before leaving, or delete the group.',
      );
    }
    groups.remove(id);
  });

  Future<void> delete(String id) => _commit((groups) {
    _require(groups, id, owner: true);
    groups.remove(id);
  });

  Future<void> send(
    String id,
    String text,
    List<GroupMedia> media, {
    String? replyPreview,
  }) => _commit((groups) {
    final group = _require(groups, id);
    if (text.trim().isEmpty && media.isEmpty) return;
    group.messages.add(
      GroupMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        text: text.trim(),
        sentAt: DateTime.now(),
        media: List.of(media),
        replyPreview: replyPreview,
      ),
    );
  });

  Future<void> editMessage(String id, String messageId, String text) =>
      _commit((groups) {
        final group = _require(groups, id);
        final message = group.messages
            .where((m) => m.id == messageId)
            .firstOrNull;
        if (message == null) {
          throw const GroupException('This message is no longer available.');
        }
        if (text.trim().isEmpty && message.media.isEmpty) {
          throw const GroupException('A message cannot be empty.');
        }
        message.text = text.trim();
        message.edited = true;
      });

  Future<void> deleteMessage(String id, String messageId) => _commit((groups) {
    _require(groups, id).messages.removeWhere((m) => m.id == messageId);
  });

  Future<void> react(String id, String messageId, String emoji) =>
      _commit((groups) {
        final message = _require(
          groups,
          id,
        ).messages.where((m) => m.id == messageId).firstOrNull;
        if (message == null) {
          throw const GroupException('This message is no longer available.');
        }
        message.reaction = message.reaction == emoji ? null : emoji;
      });

  Future<void> clearHistory(String id) => _commit((groups) {
    _require(groups, id).messages.clear();
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
