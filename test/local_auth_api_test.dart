import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Verified account survives a new API instance and logout', () async {
    final api = LocalAuthApi();
    expect(await api.restoreSession(), isNull);
    final registration = await api.register(
      phone: '+380991234567',
      name: 'Admin',
      email: 'Admin@example.com',
      password: 'test-password-123',
    );
    await expectLater(
      api.verify(registration.id, '000000'),
      throwsA(isA<AuthException>()),
    );
    final profile = await api.verify(registration.id, '123456');
    expect(profile.name, 'Admin');
    expect((await LocalAuthApi().restoreSession())?.name, 'Admin');
    await api.logout();
    expect(await LocalAuthApi().restoreSession(), isNull);

    final restarted = LocalAuthApi();
    await expectLater(
      restarted.login(email: 'admin@example.com', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
    final login = await restarted.login(
      email: 'ADMIN@example.com',
      password: 'test-password-123',
    );
    final signedIn = await restarted.verify(login.id, '123456');
    expect(signedIn.phone, '+380991234567');
    expect((await LocalAuthApi().restoreSession())?.phone, '+380991234567');
    await expectLater(
      restarted.verify(login.id, '123456'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      restarted.register(
        phone: '+380991234567',
        name: 'Admin',
        email: 'admin@example.com',
        password: 'test-password-123',
      ),
      throwsA(isA<AuthException>()),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('debug_auth_accounts_v1'),
      isNot(contains('test-password-123')),
    );
  });

  test(
    'Unverified registration is not saved and resend replaces the code challenge',
    () async {
      final api = LocalAuthApi();
      final first = await api.register(
        phone: '+380991234567',
        name: 'Admin',
        email: 'admin@example.com',
        password: 'test-password-123',
      );
      await expectLater(
        LocalAuthApi().login(
          email: 'admin@example.com',
          password: 'test-password-123',
        ),
        throwsA(isA<AuthException>()),
      );
      final replacement = await api.resend();
      await expectLater(
        api.verify(first.id, '123456'),
        throwsA(isA<AuthException>()),
      );
      expect((await api.verify(replacement.id, '123456')).name, 'Admin');
    },
  );
}
