import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/local_auth_api.dart';
import 'screens/registration_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'services/auth_api.dart';
import 'services/local_database.dart';
import 'widgets/database_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final LocalDatabase database;
  try {
    database = await LocalDatabase.open();
    final theme = await database.get('device', 'settings', 'theme');
    AppTheme.selectedMode.value = ThemeMode.values.firstWhere(
      (mode) => mode.name == theme?['mode'],
      orElse: () => ThemeMode.system,
    );
    AppTheme.persistMode = (mode) =>
        database.put('device', 'settings', 'theme', {'mode': mode.name});
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Local storage startup failed: $error');
      debugPrintStack(stackTrace: stack);
    }
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not open local storage. Your data has not been reset.',
                  ),
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  final localAuth = kDebugMode ? LocalAuthApi() : null;
  AuthProfile? profile;
  try {
    profile = await localAuth?.restoreSession();
  } catch (_) {
    // If local storage is unavailable, allow authentication to be retried.
  }
  runApp(
    TelegramApp(
      authApi: localAuth,
      initialProfile: profile,
      database: database,
    ),
  );
}

class TelegramApp extends StatelessWidget {
  const TelegramApp({
    super.key,
    this.authApi,
    this.initialProfile,
    this.database,
  });
  final LocalDatabase? database;

  final AuthApi? authApi;
  final AuthProfile? initialProfile;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.selectedMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Telegram Clone',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: initialProfile == null
            ? RegistrationScreen(authApi: authApi)
            : MainScreen(profile: initialProfile, authApi: authApi),
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            DatabaseScope(database: database, child: child!),
      ),
    );
  }
}
