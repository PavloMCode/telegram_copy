import 'package:flutter/material.dart';
import '../widgets/settings_row.dart';
import 'settings_screen_notifications_exceptions.dart';

class SettingsScreenNotifications extends StatefulWidget {
  const SettingsScreenNotifications({super.key});

  @override
  State<SettingsScreenNotifications> createState() =>
      _SettingsScreenNotificationsState();
}

class _SettingsScreenNotificationsState
    extends State<SettingsScreenNotifications> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        SettingsRow(
          icon: Icons.notifications,
          title: 'Notifications',
          subtitle: _notificationsEnabled
              ? 'Notifications turned on'
              : 'Notifications turned off',
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
          ),
        ),
        const SizedBox(height: 8),
        SettingsRow(
          icon: Icons.edit_notifications,
          title: 'Notification exceptions',
          subtitle: 'Manage exceptions',
          showChevron: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreenNotificationsExceptions(),
              ),
            );
          },
        ),
      ],
    ),
  );
}
