import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import 'account_data_scope.dart';

/// The signed-in profile shared by all main sections and their detail routes.
class ProfileScope extends InheritedWidget {
  const ProfileScope({super.key, required this.profile, required super.child});
  final AuthProfile profile;

  static const placeholder = AuthProfile('My Name', '+380 99 123 45 67');
  static AuthProfile of(BuildContext context) =>
      AccountDataScope.maybeOf(context)?.profile ??
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()?.profile ??
      placeholder;

  @override
  bool updateShouldNotify(ProfileScope oldWidget) =>
      profile.name != oldWidget.profile.name ||
      profile.phone != oldWidget.profile.phone;
}
