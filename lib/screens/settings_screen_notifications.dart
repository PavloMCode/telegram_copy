import 'package:flutter/material.dart';
import '../models/notification_category.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_row.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/group_scope.dart';
import 'settings_screen_notifications_exceptions.dart';
import '../widgets/auth_session_scope.dart';
import '../widgets/all_accounts_notifications_setting.dart';
import '../services/local_auth_api.dart';

class SettingsScreenNotifications extends StatefulWidget {
  const SettingsScreenNotifications({super.key});

  @override
  State<SettingsScreenNotifications> createState() =>
      _SettingsScreenNotificationsState();
}

class _SettingsScreenNotificationsState
    extends State<SettingsScreenNotifications> {
  bool _saving = false;

  Future<void> _change(String key, bool value) async {
    final data = AccountDataScope.maybeOf(context);
    if (data == null || _saving) return;
    setState(() => _saving = true);
    try {
      await data.setSetting(key, value);
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
  Widget build(BuildContext context) {
    final data = AccountDataScope.maybeOf(context);
    final colors = AppTheme.colorsOf(context);
    final sessionApi = AuthSessionScope.maybeOf(context);
    final exceptionCount = NotificationCategory.values.fold<int>(
      0,
      (count, category) =>
          count + (data?.notificationExceptions(category).length ?? 0),
    );
    final ready = data != null && data.loaded && data.error == null;
    final enabled =
        data?.setting('notifications', fallback: data.setting('notify_all')) ??
        true;
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    Widget toggle(
      String key,
      IconData icon,
      String title,
      String subtitle, {
      bool master = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        height: 80,
        trailing: Switch(
          key: ValueKey(key),
          value: master ? enabled : data?.setting(key) ?? true,
          onChanged: ready && !_saving && (master || enabled)
              ? (value) => _change(key, value)
              : null,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: data != null && !data.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (sessionApi is LocalAuthApi) ...[
                  AllAccountsNotificationsSetting(api: sessionApi),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                      'The settings below apply to the current account.',
                      style: TextStyle(
                        color: colors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (data?.error != null)
                  Text(data!.error!, style: TextStyle(color: colors.error)),
                toggle(
                  'notifications',
                  Icons.notifications_outlined,
                  'Notifications',
                  enabled
                      ? 'Notifications turned on'
                      : 'Notifications turned off',
                  master: true,
                ),
                heading('Messages'),
                toggle(
                  'notify_chats',
                  Icons.chat_bubble_outline,
                  'Private chats',
                  'Messages from contacts and other people',
                ),
                toggle(
                  'notify_groups',
                  Icons.group_outlined,
                  'Groups',
                  'Messages in group conversations',
                ),
                toggle(
                  'notify_channels',
                  Icons.campaign_outlined,
                  'Channels',
                  'New posts in channels',
                ),
                SettingsRow(
                  icon: Icons.edit_notifications,
                  title: 'Notification exceptions',
                  subtitle: exceptionCount == 0
                      ? 'Chats, groups and channels'
                      : '$exceptionCount custom settings',
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
                heading('Notification content'),
                toggle(
                  'notify_preview',
                  Icons.subject_outlined,
                  'Message preview',
                  'Show message text in notifications',
                ),
                heading('Sound & vibration'),
                toggle(
                  'notify_sound',
                  Icons.volume_up_outlined,
                  'Sound',
                  'Play a sound for new messages',
                ),
                toggle(
                  'notify_vibration',
                  Icons.vibration,
                  'Vibration',
                  'Vibrate for new messages',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
                  child: Text(
                    'Preferences are saved for this account. System notification delivery is not connected yet.',
                    style: TextStyle(color: colors.secondaryText, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
