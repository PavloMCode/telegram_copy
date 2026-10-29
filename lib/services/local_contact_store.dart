import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_database.dart';

/// Contact actions shared by profiles and every open direct conversation.
class LocalContactStore extends ChangeNotifier {
  LocalContactStore({this.accountId, this.database, this.onClear});
  final LocalDatabase? database;
  final Future<void> Function(String)? onClear;
  final String? accountId;
  String get storageKey => 'local_blocked_contacts_v1_$accountId';
  Set<String> _blocked = {};
  final Map<String, int> _cleared = {};
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool _loadFailed = false;

  bool isBlocked(String id) => _blocked.contains(id);
  int clearVersion(String id) => _cleared[id] ?? 0;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    if (accountId == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      _blocked = preferences.getStringList(storageKey)?.toSet() ?? {};
      if (database != null) {
        final stored = await database!.get(accountId!, 'settings', 'blocked');
        if (stored != null) {
          _blocked = (stored['ids'] as List).cast<String>().toSet();
        } else {
          await database!.put(accountId!, 'settings', 'blocked', {
            'ids': _blocked.toList(),
          });
        }
      }
    } catch (_) {
      _loadFailed = true;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setBlocked(String id, bool blocked) {
    final operation = _writes.then((_) async {
      await load();
      if (_loadFailed) {
        throw StateError('Local contact settings are unavailable.');
      }
      final next = Set<String>.of(_blocked);
      if (blocked) {
        next.add(id);
      } else {
        next.remove(id);
      }
      if (database != null && accountId != null) {
        await database!.put(accountId!, 'settings', 'blocked', {
          'ids': next.toList(),
        });
      } else if (accountId != null) {
        final preferences = await SharedPreferences.getInstance();
        if (!await preferences.setStringList(storageKey, next.toList())) {
          throw StateError('Could not save contact settings.');
        }
      }
      _blocked = next;
      if (!_disposed) notifyListeners();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  /// Direct-chat messages currently live in their screen state. Notify all
  /// mounted conversations to clear them, whichever screen initiated it.
  Future<void> clearHistory(String id) async {
    if (onClear != null) await onClear!(id);
    _cleared[id] = clearVersion(id) + 1;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
