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

  Future<AuthProfile?> restoreSession() async {
    _requireDebug();
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_sessionKey);
    if (email == null) return null;
    final accounts = await _accounts();
    final account = accounts[email] as Map<String, dynamic>?;
    if (account == null) {
      await preferences.remove(_sessionKey);
      return null;
    }
    return AuthProfile(account['name'] as String, account['phone'] as String);
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
    if (accounts.containsKey(normalizedEmail)) {
      throw const AuthException(
        'This email is already registered. Please sign in.',
      );
    }
    final random = Random.secure();
    final salt = base64Encode(List.generate(32, (_) => random.nextInt(256)));
    _pending = {
      'email': normalizedEmail,
      'name': name.trim(),
      'phone': phone.trim(),
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
    if (_registering) {
      final accounts = await _accounts();
      accounts[account['email'] as String] = account;
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(_storageKey, jsonEncode(accounts))) {
        throw const AuthException(
          'Could not save the local profile. Please try again.',
        );
      }
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_sessionKey, account['email'] as String)) {
      throw const AuthException(
        'Could not save the local session. Please try again.',
      );
    }
    _pending = null;
    _challengeId = null;
    return AuthProfile(account['name'] as String, account['phone'] as String);
  }

  @override
  Future<void> logout() async {
    _requireDebug();
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(_sessionKey)) {
      throw const AuthException(
        'Could not clear the local session. Please try again.',
      );
    }
    _pending = null;
    _challengeId = null;
  }
}
