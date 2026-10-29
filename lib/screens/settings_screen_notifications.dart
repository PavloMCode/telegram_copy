import 'package:flutter/material.dart';
import '../widgets/settings_row.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/group_scope.dart';
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
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = AccountDataScope.maybeOf(context);
    if (!_initialized && (data == null || data.loaded)) {
      _initialized = true;
      _notificationsEnabled = data?.setting('notifications') ?? true;
    }
  }

  Future<void> _change(bool value) async {
    final data = AccountDataScope.maybeOf(context);
    setState(() => _saving = true);
    try {
      await data?.setSetting('notifications', value);
      if (mounted) setState(() => _notificationsEnabled = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save notifications.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            onChanged: _saving ? null : _change,
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
                builder: (_) => GroupScope.wrap(
                  context,
                  const SettingsScreenNotificationsExceptions(),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
