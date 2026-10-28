import 'package:telegram_frontend/services/auth_api.dart';

// This transport is used only by tests.
class FakeAuthApi extends AuthApi {
  String name = 'Anna';
  String phone = '+380991234567';
  String email = 'anna@example.com';
  bool failSend = false;
  bool failLogin = false;
  int logoutCalls = 0;

  @override
  Future<AuthChallenge> register({
    required String phone,
    required String name,
    required String email,
    required String password,
  }) async {
    if (failSend) {
      throw const AuthException(
        'Could not send the email. Please try again later.',
      );
    }
    this.name = name;
    this.phone = phone;
    this.email = email;
    return AuthChallenge('test-challenge', email, resendAfter: 0);
  }

  @override
  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) async {
    if (failLogin) throw const AuthException('Invalid email or password.');
    return AuthChallenge('test-challenge', email, resendAfter: 0);
  }

  @override
  Future<AuthProfile> verify(String challengeId, String code) async {
    if (code != '123456') {
      throw const AuthException('Invalid verification code.');
    }
    return AuthProfile(name, phone);
  }

  @override
  Future<AuthChallenge> resend() async =>
      AuthChallenge('replacement-challenge', email, resendAfter: 0);

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}
