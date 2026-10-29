import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../services/auth_api.dart';
import '../widgets/group_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/settings_row.dart';
import 'settings_screen_account.dart';
import 'settings_screen_notifications.dart';
import 'settings_screen_privacy.dart';
import 'settings_screen_security.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onSectionSelected,
    this.authApi,
  });

  final AuthApi? authApi;

  final ValueChanged<MainSection> onSectionSelected;

  Widget _sectionTitle(String title, ColorScheme colors) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Text(
      title,
      style: TextStyle(
        color: colors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _settingTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    height: 72,
    horizontalPadding: 20,
    card: false,
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: AppDrawer(
        selectedSection: MainSection.settings,
        onSectionSelected: onSectionSelected,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _sectionTitle('Account', colors),
          _settingTile(
            Icons.person_outline,
            'Account',
            'Profile, phone number and personal details',
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => GroupScope.wrap(
                  context,
                  SettingsScreenAccount(authApi: authApi),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Security & Privacy', colors),
          _settingTile(
            Icons.security_outlined,
            'Security',
            'Password and account protection',
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    GroupScope.wrap(context, const SettingsScreenSecurity()),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 72,
            endIndent: 20,
            color: colors.subtleDivider,
          ),
          _settingTile(
            Icons.lock_outline,
            'Privacy',
            'Control who can contact you',
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    GroupScope.wrap(context, const SettingsScreenPrivacy()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Notifications', colors),
          _settingTile(
            Icons.notifications_outlined,
            'Notifications',
            'Notification preferences and exceptions',
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => GroupScope.wrap(
                  context,
                  const SettingsScreenNotifications(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
