import '../widgets/gradient_surfaces.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    void open(Widget screen) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => GroupScope.wrap(context, screen)),
    );
    Widget row(IconData icon, String title, String subtitle, Widget screen) =>
        SettingsRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          card: false,
          showChevron: true,
          onTap: () => open(screen),
        );
    Widget section(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colors.primary),
            ),
          ),
          GradientCard(
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ],
      ),
    );
    return AppScaffold(
      appBar: AppBar(
        flexibleSpace: const GradientHeader(),
        title: const Text('Settings'),
      ),
      drawer: MediaQuery.sizeOf(context).width >= 840
          ? null
          : AppDrawer(
              selectedSection: MainSection.settings,
              onSectionSelected: onSectionSelected,
            ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          section('Account', [
            row(
              Icons.person_outline,
              'Account',
              'Profile, phone number and personal details',
              SettingsScreenAccount(authApi: authApi),
            ),
          ]),
          section('Security & Privacy', [
            row(
              Icons.security_outlined,
              'Security',
              'Password and account protection',
              const SettingsScreenSecurity(),
            ),
            const Divider(height: 1, indent: 68, endIndent: 16),
            row(
              Icons.lock_outline,
              'Privacy',
              'Control who can contact you',
              const SettingsScreenPrivacy(),
            ),
          ]),
          section('Notifications', [
            row(
              Icons.notifications_outlined,
              'Notifications',
              'Notification preferences and exceptions',
              const SettingsScreenNotifications(),
            ),
          ]),
        ],
      ),
    );
  }
}
