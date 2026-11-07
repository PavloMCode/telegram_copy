import 'package:flutter/material.dart';
import '../services/auth_api.dart';

class AuthSessionScope extends InheritedWidget {
  const AuthSessionScope({super.key, required this.api, required super.child});
  final AuthApi? api;
  static AuthApi? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthSessionScope>()?.api;
  static Widget wrap(BuildContext context, Widget child) =>
      AuthSessionScope(api: maybeOf(context), child: child);
  @override
  bool updateShouldNotify(AuthSessionScope oldWidget) => api != oldWidget.api;
}
