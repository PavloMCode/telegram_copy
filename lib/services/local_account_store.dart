import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/demo_data.dart';
import '../models/notification_category.dart';
import 'auth_api.dart';
import 'local_database.dart';

class LocalAccountStore extends ChangeNotifier {
  LocalAccountStore(this.initialProfile, {this.database});
  final AuthProfile initialProfile;
  final LocalDatabase? database;
  String get accountId => initialProfile.phone;
  Map<String, dynamic> details = {};
  Map<String, dynamic> settings = {};
  Map<String, DemoContact> _contacts = {
    for (final contact in DemoContacts.all) contact.id: contact,
  };
  Map<String, Map<String, dynamic>> conversations = {};
  Map<String, Map<String, dynamic>> chatStates = {};
  final Map<String, int> _forwardVersions = {};
  int forwardVersion(String id) => _forwardVersions[id] ?? 0;

  Future<void> appendForwardedMessage(
    String id,
    String name,
    Map<String, dynamic> message,
  ) => _write(() async {
    final previous = await database?.messages(accountId, id) ?? [];
    final summary = {
      'name': name,
      'preview': message['text'] ?? '',
      'updated': message['time'] ?? '',
    };
    await database?.saveConversation(accountId, id, [
      message,
      ...previous,
    ], summary);
    conversations = {...conversations, id: summary};
    _forwardVersions[id] = forwardVersion(id) + 1;
  });
  bool isChatDeleted(String id) => conversations[id]?['deleted'] == true;
  bool isChatPinned(String id) =>
      chatStates[id]?['pinned'] as bool? ??
      demoChats.any((chat) => chat.id == id && chat.pinned);

  Future<void> setChatPinned(String id, bool value) => _write(() async {
    final next = {'pinned': value};
    await database?.put(accountId, 'chat_state', id, next);
    chatStates = {...chatStates, id: next};
  });

  Future<void> deleteConversation(String id) => _write(() async {
    await database?.deleteConversation(accountId, id);
    conversations = {
      ...conversations,
      id: {'deleted': true},
    };
    chatStates = {
      ...chatStates,
      id: {'pinned': false},
    };
  });
  bool loaded = false;
  String? error;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  List<DemoContact> get contacts => List.unmodifiable(_contacts.values);
  DemoContact? contact(String id) => _contacts[id];
  AuthProfile get profile => AuthProfile(
    details['name'] as String? ?? initialProfile.name,
    details['phone'] as String? ?? initialProfile.phone,
  );
  Uint8List? get photo => details['photo'] == null
      ? null
      : base64Decode(details['photo'] as String);
  bool setting(String key, {bool fallback = true}) =>
      settings[key] as bool? ?? fallback;
  T settingValue<T>(String key, {required T fallback}) {
    final value = settings[key];
    return value is T ? value : fallback;
  }

  Map<String, bool> notificationExceptions(NotificationCategory category) {
    final stored = settings[category.exceptionsKey];
    return stored is Map
        ? {
            for (final entry in stored.entries)
              if (entry.key is String && entry.value is bool)
                entry.key as String: entry.value as bool,
          }
        : {};
  }

  bool notificationsEnabledFor(NotificationCategory category, String id) {
    if (!setting('notifications', fallback: setting('notify_all'))) {
      return false;
    }
    return notificationExceptions(category)[id] ?? setting(category.settingKey);
  }

  Future<void> setNotificationException(
    NotificationCategory category,
    String id,
    bool? value,
  ) => _write(() async {
    final next = notificationExceptions(category);
    if (value == null) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    final preferences = {...settings, category.exceptionsKey: next};
    await database?.put(accountId, 'settings', 'preferences', preferences);
    settings = preferences;
  });

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      if (database != null) {
        details = await database!.get(accountId, 'profile', 'self') ?? {};
        settings =
            await database!.get(accountId, 'settings', 'preferences') ?? {};
        final stored = await database!.all(accountId, 'contacts');
        if (await database!.get(accountId, 'migration', 'contacts') == null) {
          for (final contact in DemoContacts.all) {
            await database!.put(accountId, 'contacts', contact.id, {
              'name': contact.name,
              'phone': contact.phone,
            });
          }
          await database!.put(accountId, 'migration', 'contacts', {
            'done': true,
          });
        } else {
          _contacts = {
            for (final entry in stored.entries)
              entry.key: DemoContact(
                entry.key,
                entry.value['name'] as String,
                entry.value['phone'] as String,
              ),
          };
        }
        conversations = await database!.all(accountId, 'conversations');
        chatStates = await database!.all(accountId, 'chat_state');
      }
    } catch (_) {
      error = 'Could not load local data. Please restart the app.';
    }
    loaded = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _write(Future<void> Function() action) {
    final next = _writes.then((_) async {
      await load();
      if (error != null) throw StateError(error!);
      await action();
      _notify();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> saveProfile(Map<String, dynamic> values) => _write(() async {
    final next = {...details, ...values};
    await database?.put(accountId, 'profile', 'self', next);
    details = next;
  });
  Future<void> setSetting(String key, bool value) =>
      setSettingValue(key, value);
  Future<void> setSettingValue(String key, Object? value) => _write(() async {
    final next = {...settings, key: value};
    await database?.put(accountId, 'settings', 'preferences', next);
    settings = next;
  });
  Future<void> saveContact(DemoContact contact) => _write(() async {
    await database?.put(accountId, 'contacts', contact.id, {
      'name': contact.name,
      'phone': contact.phone,
    });
    _contacts = {..._contacts, contact.id: contact};
  });
  Future<void> removeContact(String id) => _write(() async {
    await database?.remove(accountId, 'contacts', id);
    _contacts = Map.of(_contacts)..remove(id);
  });
  Future<List<Map<String, dynamic>>> messages(String chat) async {
    await load();
    return await database?.messages(accountId, chat) ?? [];
  }

  Future<Map<String, dynamic>?> draft(String chat) async {
    await load();
    return database?.get(accountId, 'drafts', chat);
  }

  Future<void> saveDraft(String chat, Map<String, dynamic> value) =>
      _write(() async {
        await database?.put(accountId, 'drafts', chat, value);
      });
  Future<void> saveConversation(
    String chat,
    String name,
    List<Map<String, dynamic>> messages,
  ) => _write(() async {
    final last = messages.firstOrNull;
    final summary = {
      'name': name,
      'preview': last?['text'] ?? '',
      'updated': last?['time'] ?? '',
    };
    await database?.saveConversation(accountId, chat, messages, summary);
    conversations = {...conversations, chat: summary};
  });
  Future<void> clearConversation(String chat) => saveConversation(
    chat,
    conversations[chat]?['name'] as String? ?? chat,
    [],
  );
  Future<void> flush() => _writes;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
