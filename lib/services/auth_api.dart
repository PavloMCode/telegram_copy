import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthChallenge {
  const AuthChallenge(this.id, this.email, {this.resendAfter = 60});
  final String id;
  final String email;
  final int resendAfter;
}

class AuthProfile {
  const AuthProfile(this.name, this.phone);
  final String name;
  final String phone;
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'AUTH_API_URL',
            defaultValue: 'http://10.0.2.2:8080',
          );

  static final instance = AuthApi();
  final http.Client _client;
  final String _baseUrl;
  String? _cookie;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/auth/$path');
    final localDebug =
        kDebugMode &&
        ['localhost', '127.0.0.1', '10.0.2.2', '::1'].contains(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && localDebug)) {
      throw const AuthException(
        'A secure HTTPS authentication server must be configured.',
      );
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Messenger-Client': 'mobile',
              'Cookie': ?_cookie,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      final cookie = response.headers['set-cookie'];
      if (cookie != null) {
        final match = RegExp(
          r'(?:^|,\s*)JSESSIONID=([^; ,]+)',
        ).firstMatch(cookie);
        if (match != null) _cookie = 'JSESSIONID=${match.group(1)}';
      }
      final data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          data['message'] as String? ??
              'Authentication failed. Please try again.',
        );
      }
      return data;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      throw const AuthException(
        'Cannot connect to the authentication server. Please try again.',
      );
    }
  }

  AuthChallenge _challenge(Map<String, dynamic> data) => AuthChallenge(
    data['challengeId'] as String,
    data['email'] as String,
    resendAfter: data['resendAfter'] as int? ?? 60,
  );

  Future<AuthChallenge> register({
    required String phone,
    required String name,
    required String email,
    required String password,
  }) async => _challenge(
    await _post('register', {
      'phone': phone,
      'name': name,
      'email': email,
      'password': password,
    }),
  );

  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) async =>
      _challenge(await _post('login', {'email': email, 'password': password}));

  Future<AuthChallenge> resend() async => _challenge(await _post('resend', {}));

  Future<AuthProfile> verify(String challengeId, String code) async {
    final data = await _post('verify', {
      'challengeId': challengeId,
      'code': code,
    });
    return AuthProfile(data['name'] as String, data['phone'] as String);
  }

  Future<void> logout() async {
    try {
      await _post('logout', {});
    } finally {
      _cookie = null;
    }
  }
}
