import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Multiple verified sessions switch, restore, filter notifications and log out independently',
    () async {
      final api = LocalAuthApi();
      final first = await api.register(
        phone: '+441234567890',
        name: 'First',
        email: 'first@example.com',
        password: 'password-one',
      );
      await api.verify(first.id, '123456');
      final second = await api.register(
        phone: '+441234567891',
        name: 'Second',
        email: 'second@example.com',
        password: 'password-two',
      );
      // Pending or failed verification never switches the active account.
      expect((await LocalAuthApi().restoreSession())?.name, 'First');
      await expectLater(
        api.verify(second.id, '000000'),
        throwsA(isA<AuthException>()),
      );
      expect((await api.restoreSession())?.name, 'First');
      await api.verify(second.id, '123456');
      final restarted = LocalAuthApi();
      expect((await restarted.signedInProfiles()).map((p) => p.name), [
        'First',
        'Second',
      ]);
      expect((await restarted.restoreSession())?.name, 'Second');
      expect(await restarted.shouldNotifyAccount('+441234567890'), isTrue);
      await restarted.setNotificationsFromAllAccounts(false);
      expect(await LocalAuthApi().notificationsFromAllAccounts(), isFalse);
      expect(await restarted.shouldNotifyAccount('+441234567890'), isFalse);
      expect(await restarted.shouldNotifyAccount('+441234567891'), isTrue);
      await restarted.switchAccount('+441234567890');
      expect((await LocalAuthApi().restoreSession())?.name, 'First');
      expect(await restarted.shouldNotifyAccount('+441234567890'), isTrue);
      expect(await restarted.shouldNotifyAccount('+441234567891'), isFalse);
      await restarted.logout();
      expect((await LocalAuthApi().restoreSession())?.name, 'Second');
      expect((await restarted.signedInProfiles()).length, 1);
      await expectLater(
        restarted.switchAccount('+441234567890'),
        throwsA(isA<AuthException>()),
      );
      await restarted.setNotificationsFromAllAccounts(true);
      expect(await restarted.shouldNotifyAccount('+441234567890'), isFalse);
      final login = await restarted.login(
        email: 'first@example.com',
        password: 'password-one',
      );
      await restarted.verify(login.id, '123456');
      expect((await restarted.signedInProfiles()).length, 2);
      await restarted.logout();
      await restarted.logout();
      expect(await LocalAuthApi().restoreSession(), isNull);
      expect(await LocalAuthApi().signedInProfiles(), isEmpty);
    },
  );

  test(
    'Legacy session migrates and duplicate phone cannot share account data',
    () async {
      final api = LocalAuthApi();
      final challenge = await api.register(
        phone: '+441234567890',
        name: 'First',
        email: 'first@example.com',
        password: 'password-one',
      );
      await api.verify(challenge.id, '123456');
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('debug_auth_sessions_v2');
      await preferences.setString('debug_auth_session_v1', 'first@example.com');
      final restored = LocalAuthApi();
      expect((await restored.restoreSession())?.name, 'First');
      expect((await restored.signedInProfiles()).length, 1);
      await expectLater(
        restored.register(
          phone: '+44 1234 567890',
          name: 'Duplicate',
          email: 'duplicate@example.com',
          password: 'password-two',
        ),
        throwsA(isA<AuthException>()),
      );
      await restored.switchAccount('+441234567890');
      expect(preferences.getString('debug_auth_sessions_v2'), isNotNull);
      await restored.logout();
      expect(await LocalAuthApi().restoreSession(), isNull);
    },
  );

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
