import 'package:flutter/material.dart';
import 'screens/registration_screen.dart';
import 'theme/app_theme.dart';
import 'services/auth_api.dart';

void main() {
  runApp(const TelegramApp());
}

class TelegramApp extends StatelessWidget {
  const TelegramApp({super.key, this.authApi});

  final AuthApi? authApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Clone',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.mode,
      home: RegistrationScreen(authApi: authApi),
      debugShowCheckedModeBanner: false,
    );
  }
}
