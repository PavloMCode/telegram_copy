import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as native;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Device storage. Each account has its own partition; messages have separate
/// rows rather than one preference containing the entire conversation history.
class LocalDatabase {
  LocalDatabase._(this._database);
  final Database _database;

  static Future<LocalDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    if (factory == null && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    }
    factory ??= native.databaseFactorySqflitePlugin;
    if (path == null) {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      path = '${directory.path}/telegram.sqlite';
    }
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE records (account TEXT NOT NULL, bucket TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(account,bucket,id))',
          );
          await db.execute(
            'CREATE TABLE messages (account TEXT NOT NULL, chat TEXT NOT NULL, id TEXT NOT NULL, position INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(account,chat,id))',
          );
          await db.execute(
            'CREATE INDEX messages_order ON messages(account,chat,position)',
          );
        },
      ),
    );
    return LocalDatabase._(database);
  }

  Future<Map<String, dynamic>?> get(
    String account,
    String bucket,
    String id,
  ) async {
    final rows = await _database.query(
      'records',
      where: 'account=? AND bucket=? AND id=?',
      whereArgs: [account, bucket, id],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>;
  }

  Future<Map<String, Map<String, dynamic>>> all(
    String account,
    String bucket,
  ) async {
    final rows = await _database.query(
      'records',
      where: 'account=? AND bucket=?',
      whereArgs: [account, bucket],
    );
    return {
      for (final row in rows)
        row['id'] as String:
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    };
  }

  Future<void> put(
    String account,
    String bucket,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _database.insert('records', {
      'account': account,
      'bucket': bucket,
      'id': id,
      'payload': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String account, String bucket, String id) async {
    await _database.delete(
      'records',
      where: 'account=? AND bucket=? AND id=?',
      whereArgs: [account, bucket, id],
    );
  }

  Future<List<Map<String, dynamic>>> messages(
    String account,
    String chat,
  ) async {
    final rows = await _database.query(
      'messages',
      where: 'account=? AND chat=?',
      whereArgs: [account, chat],
      orderBy: 'position ASC',
    );
    return rows
        .map(
          (row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<void> _replaceMessages(
    DatabaseExecutor db,
    String account,
    String chat,
    List<Map<String, dynamic>> messages,
  ) async {
    await db.delete(
      'messages',
      where: 'account=? AND chat=?',
      whereArgs: [account, chat],
    );
    for (var i = 0; i < messages.length; i++) {
      await db.insert('messages', {
        'account': account,
        'chat': chat,
        'id': messages[i]['id'],
        'position': i,
        'payload': jsonEncode(messages[i]),
      });
    }
  }

  Future<void> saveConversation(
    String account,
    String chat,
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> summary,
  ) => _database.transaction((db) async {
    await _replaceMessages(db, account, chat, messages);
    await db.insert('records', {
      'account': account,
      'bucket': 'conversations',
      'id': chat,
      'payload': jsonEncode(summary),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<void> saveGroups(String account, List<Map<String, dynamic>> groups) =>
      _database.transaction((db) async {
        final previous = await db.query(
          'records',
          columns: ['id'],
          where: 'account=? AND bucket=?',
          whereArgs: [account, 'groups'],
        );
        final keep = groups.map((g) => g['id']).toSet();
        for (final row in previous) {
          if (!keep.contains(row['id'])) {
            await db.delete(
              'messages',
              where: 'account=? AND chat=?',
              whereArgs: [account, row['id']],
            );
            await db.delete(
              'records',
              where: 'account=? AND bucket=? AND id=?',
              whereArgs: [account, 'drafts', row['id']],
            );
          }
        }
        await db.delete(
          'records',
          where: 'account=? AND bucket=?',
          whereArgs: [account, 'groups'],
        );
        for (final group in groups) {
          final metadata = Map<String, dynamic>.of(group)..remove('messages');
          await db.insert('records', {
            'account': account,
            'bucket': 'groups',
            'id': group['id'],
            'payload': jsonEncode(metadata),
          });
          await _replaceMessages(
            db,
            account,
            group['id'] as String,
            (group['messages'] as List).cast<Map<String, dynamic>>(),
          );
        }
        await db.insert('records', {
          'account': account,
          'bucket': 'migration',
          'id': 'groups',
          'payload': '{"done":true}',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
  Future<void> close() => _database.close();
}
