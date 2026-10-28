import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/local_auth_api.dart';
import 'screens/registration_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'services/auth_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localAuth = kDebugMode ? LocalAuthApi() : null;
  AuthProfile? profile;
  try {
    profile = await localAuth?.restoreSession();
  } catch (_) {
    // If local storage is unavailable, allow authentication to be retried.
  }
  runApp(TelegramApp(authApi: localAuth, initialProfile: profile));
}

class TelegramApp extends StatelessWidget {
  const TelegramApp({super.key, this.authApi, this.initialProfile});

  final AuthApi? authApi;
  final AuthProfile? initialProfile;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Clone',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.mode,
      home: initialProfile == null
          ? RegistrationScreen(authApi: authApi)
          : MainScreen(
              userName: initialProfile!.name,
              phone: initialProfile!.phone,
              authApi: authApi,
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}
