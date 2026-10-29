import 'package:flutter/material.dart';
import '../widgets/settings_row.dart';
import '../widgets/account_data_scope.dart';

class SettingsScreenNotificationsExceptions extends StatefulWidget {
  const SettingsScreenNotificationsExceptions({super.key});
  @override
  State<SettingsScreenNotificationsExceptions> createState() =>
      _ExceptionsState();
}

class _ExceptionsState extends State<SettingsScreenNotificationsExceptions> {
  final _values = <String, bool>{};
  bool _saving = false;
  Future<void> _change(String key, bool value) async {
    final data = AccountDataScope.maybeOf(context);
    setState(() => _saving = true);
    try {
      await data?.setSetting(key, value);
      if (mounted) setState(() => _values[key] = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save notification settings.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AccountDataScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification exceptions')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          for (final (key, title, icon) in [
            ('notify_all', 'All chats', Icons.chat_sharp),
            ('notify_chats', 'Chats', Icons.wechat_outlined),
            ('notify_groups', 'Groups', Icons.group),
            ('notify_channels', 'Channels', Icons.newspaper),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SettingsRow(
                icon: icon,
                title: title,
                subtitle: (data?.setting(key) ?? _values[key] ?? true)
                    ? 'Notifications enabled'
                    : 'Notifications disabled',
                trailing: Switch(
                  value: data?.setting(key) ?? _values[key] ?? true,
                  onChanged: _saving ? null : (value) => _change(key, value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
