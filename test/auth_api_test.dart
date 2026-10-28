import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:telegram_frontend/services/auth_api.dart';

void main() {
  test(
    'Auth API preserves and rotates session cookie and clears it on logout',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['X-Messenger-Client'], 'mobile');
        return switch (request.url.path.split('/').last) {
          'login' => http.Response(
            jsonEncode({
              'challengeId': 'challenge',
              'email': 'anna@example.com',
            }),
            200,
            headers: {
              'set-cookie': 'JSESSIONID=pending-session; Path=/; HttpOnly',
            },
          ),
          'verify' => http.Response(
            jsonEncode({'name': 'Anna', 'phone': '+380991234567'}),
            200,
            headers: {
              'set-cookie': 'JSESSIONID=verified-session; Path=/; HttpOnly',
            },
          ),
          _ => http.Response('', 204),
        };
      });
      final api = AuthApi(client: client, baseUrl: 'https://example.com');
      await api.login(email: 'anna@example.com', password: 'test-password');
      await api.verify('challenge', '123456');
      expect(requests[1].headers['Cookie'], 'JSESSIONID=pending-session');
      await api.logout();
      expect(requests[2].headers['Cookie'], 'JSESSIONID=verified-session');
      await api.login(email: 'anna@example.com', password: 'test-password');
      expect(requests[3].headers['Cookie'], isNull);
    },
  );

  test(
    'Server errors are surfaced without accepting a session as successful login',
    () async {
      final api = AuthApi(
        baseUrl: 'https://example.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Invalid email or password.'}),
            401,
          ),
        ),
      );
      await expectLater(
        api.login(email: 'anna@example.com', password: 'wrong'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password.',
          ),
        ),
      );
    },
  );

  test(
    'Credentials cannot be transmitted to a remote plain HTTP server',
    () async {
      var called = false;
      final api = AuthApi(
        baseUrl: 'http://example.com',
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.login(email: 'anna@example.com', password: 'test-password'),
        throwsA(isA<AuthException>()),
      );
      expect(called, isFalse);
    },
  );
}
