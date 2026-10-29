import 'package:flutter/material.dart';
import '../services/local_auth_api.dart';
import 'settings_row.dart';

class AllAccountsNotificationsSetting extends StatefulWidget {
  const AllAccountsNotificationsSetting({super.key, required this.api});
  final LocalAuthApi api;
  @override
  State<AllAccountsNotificationsSetting> createState() =>
      _AllAccountsNotificationsSettingState();
}

class _AllAccountsNotificationsSettingState
    extends State<AllAccountsNotificationsSetting> {
  bool? _enabled;
  bool _saving = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.api.notificationsFromAllAccounts();
      if (mounted) {
        setState(() {
          _enabled = value;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.api.setNotificationsFromAllAccounts(value);
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save account notifications.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SettingsRow(
      icon: Icons.manage_accounts_outlined,
      title: 'All accounts',
      subtitle: _failed
          ? 'Could not load preferences. Tap to retry.'
          : _enabled == null
          ? 'Loading…'
          : _enabled!
          ? 'Use notification settings of every signed-in account'
          : 'Only notify for the active account',
      height: 88,
      onTap: _failed ? _load : null,
      trailing: Switch(
        key: const ValueKey('notifications_all_accounts'),
        value: _enabled ?? true,
        onChanged: _enabled != null && !_saving ? _change : null,
      ),
    ),
  );
}
