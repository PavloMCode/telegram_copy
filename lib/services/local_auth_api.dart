import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';

/// Local test accounts for frontend development only.
class LocalAuthApi extends AuthApi {
  static const _storageKey = 'debug_auth_accounts_v1';
  static const _sessionKey = 'debug_auth_session_v1';
  static const _sessionsKey = 'debug_auth_sessions_v2';
  static const _notifyAllKey = 'notifications_all_accounts_v1';
  static Future<void> _sessionWrites = Future.value();
  Map<String, dynamic>? _pending;
  String? _challengeId;
  bool _registering = false;
  int _sequence = 0;

  void _requireDebug() {
    if (!kDebugMode) {
      throw const AuthException('Local authentication is debug-only.');
    }
  }

  Future<Map<String, dynamic>> _accounts() async {
    _requireDebug();
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    return stored == null
        ? <String, dynamic>{}
        : jsonDecode(stored) as Map<String, dynamic>;
  }

  String _digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<Map<String, dynamic>> _sessions() async {
    _requireDebug();
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_sessionsKey);
    if (stored != null) return jsonDecode(stored) as Map<String, dynamic>;
    final legacy = preferences.getString(_sessionKey);
    return {
      'active': legacy,
      'emails': [?legacy],
    };
  }

  Future<void> _changeSessions(
    Future<void> Function(Map<String, dynamic>) change,
  ) {
    final operation = _sessionWrites.then((_) async {
      final sessions = await _sessions();
      await change(sessions);
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(_sessionsKey, jsonEncode(sessions))) {
        throw const AuthException(
          'Could not save account sessions. Please try again.',
        );
      }
    });
    _sessionWrites = operation.catchError((Object _) {});
    return operation;
  }

  Future<List<AuthProfile>> signedInProfiles() async {
    final sessions = await _sessions();
    final accounts = await _accounts();
    return [
      for (final email in (sessions['emails'] as List))
        if (accounts[email] case final Map account)
          AuthProfile(account['name'] as String, account['phone'] as String),
    ];
  }

  Future<AuthProfile?> restoreSession() async {
    final sessions = await _sessions();
    final email = sessions['active'] as String?;
    final accounts = await _accounts();
    final account = accounts[email] as Map<String, dynamic>?;
    if (account == null) return null;
    return AuthProfile(account['name'] as String, account['phone'] as String);
  }

  Future<AuthProfile> switchAccount(String phone) async {
    late AuthProfile profile;
    await _changeSessions((sessions) async {
      final accounts = await _accounts();
      final email = (sessions['emails'] as List)
          .cast<String>()
          .where((email) => (accounts[email] as Map?)?['phone'] == phone)
          .firstOrNull;
      if (email == null) {
        throw const AuthException('Sign in to this account again.');
      }
      final account = accounts[email] as Map;
      profile = AuthProfile(
        account['name'] as String,
        account['phone'] as String,
      );
      sessions['active'] = email;
    });
    return profile;
  }

  Future<bool> notificationsFromAllAccounts() async {
    _requireDebug();
    return (await SharedPreferences.getInstance()).getBool(_notifyAllKey) ??
        true;
  }

  Future<void> setNotificationsFromAllAccounts(bool value) async {
    _requireDebug();
    if (!await (await SharedPreferences.getInstance()).setBool(
      _notifyAllKey,
      value,
    )) {
      throw const AuthException('Could not save notification preferences.');
    }
  }

  Future<bool> shouldNotifyAccount(String phone) async {
    if (!(await signedInProfiles()).any((profile) => profile.phone == phone)) {
      return false;
    }
    return await notificationsFromAllAccounts() ||
        (await restoreSession())?.phone == phone;
  }

  AuthChallenge _issue() {
    _challengeId = 'local-${++_sequence}';
    return AuthChallenge(
      _challengeId!,
      _pending!['email'] as String,
      resendAfter: 0,
    );
  }

  @override
  Future<AuthChallenge> register({
    required String phone,
    required String name,
    required String email,
    required String password,
  }) async {
    final accounts = await _accounts();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.replaceAll(RegExp(r'[ ()-]'), '');
    if (accounts.containsKey(normalizedEmail)) {
      throw const AuthException(
        'This email is already registered. Please sign in.',
      );
    }
    if (accounts.values.any(
      (account) =>
          (account['phone'] as String).replaceAll(RegExp(r'[ ()-]'), '') ==
          normalizedPhone,
    )) {
      throw const AuthException(
        'This phone number is already registered. Please sign in.',
      );
    }
    final random = Random.secure();
    final salt = base64Encode(List.generate(32, (_) => random.nextInt(256)));
    _pending = {
      'email': normalizedEmail,
      'name': name.trim(),
      'phone': normalizedPhone,
      'salt': salt,
      'passwordHash': _digest(salt, password),
    };
    _registering = true;
    return _issue();
  }

  @override
  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) async {
    _pending = null;
    _challengeId = null;
    final accounts = await _accounts();
    final account =
        accounts[email.trim().toLowerCase()] as Map<String, dynamic>?;
    if (account == null ||
        account['passwordHash'] !=
            _digest(account['salt'] as String, password)) {
      throw const AuthException('Invalid email or password.');
    }
    _pending = account;
    _registering = false;
    return _issue();
  }

  @override
  Future<AuthChallenge> resend() async {
    _requireDebug();
    if (_pending == null) throw const AuthException('Please sign in again.');
    return _issue();
  }

  @override
  Future<AuthProfile> verify(String challengeId, String code) async {
    _requireDebug();
    final account = _pending;
    if (account == null || challengeId != _challengeId || code != '123456') {
      throw const AuthException('Invalid verification code.');
    }
    await _changeSessions((sessions) async {
      if (_registering) {
        final accounts = await _accounts();
        if (accounts.containsKey(account['email']) ||
            accounts.values.any(
              (existing) =>
                  (existing['phone'] as String).replaceAll(
                    RegExp(r'[ ()-]'),
                    '',
                  ) ==
                  account['phone'],
            )) {
          throw const AuthException(
            'This account is already registered. Please sign in.',
          );
        }
        accounts[account['email'] as String] = account;
        final preferences = await SharedPreferences.getInstance();
        if (!await preferences.setString(_storageKey, jsonEncode(accounts))) {
          throw const AuthException(
            'Could not save the local profile. Please try again.',
          );
        }
        // A retry after a session-write failure must not register twice.
        _registering = false;
      }
      final emails = (sessions['emails'] as List).cast<String>().toSet()
        ..add(account['email'] as String);
      sessions['emails'] = emails.toList();
      sessions['active'] = account['email'];
    });
    _pending = null;
    _challengeId = null;
    return AuthProfile(account['name'] as String, account['phone'] as String);
  }

  @override
  Future<void> logout() async {
    _requireDebug();
    await _changeSessions((sessions) async {
      final emails = (sessions['emails'] as List).cast<String>()
        ..remove(sessions['active']);
      final accounts = await _accounts();
      emails.removeWhere((email) => !accounts.containsKey(email));
      sessions['emails'] = emails;
      sessions['active'] = emails.firstOrNull;
    });
    _pending = null;
    _challengeId = null;
  }
}
