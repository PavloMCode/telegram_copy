import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/settings_row.dart';

class SettingsScreenSecurity extends StatefulWidget {
  const SettingsScreenSecurity({super.key});

  @override
  State<SettingsScreenSecurity> createState() => _SettingsScreenSecurityState();
}

class _SettingsScreenSecurityState extends State<SettingsScreenSecurity> {
  final _values = <String, bool>{};
  final _saving = <String>{};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = AccountDataScope.maybeOf(context);
    if (_initialized || (data != null && !data.loaded)) return;
    _initialized = true;
    _values.addAll({
      'security_two_step':
          data?.setting('security_two_step', fallback: true) ?? true,
      'security_passcode':
          data?.setting('security_passcode', fallback: false) ?? false,
      'security_biometrics':
          data?.setting('security_biometrics', fallback: false) ?? false,
      'security_login_alerts':
          data?.setting('security_login_alerts', fallback: true) ?? true,
    });
  }

  Future<void> _change(String key, bool value) async {
    final data = AccountDataScope.maybeOf(context);
    setState(() => _saving.add(key));
    try {
      await data?.setSetting(key, value);
      if (!mounted) return;
      setState(() {
        _values[key] = value;
        if (key == 'security_passcode' && !value) {
          _values['security_biometrics'] = false;
        }
      });
      if (key == 'security_passcode' && !value) {
        await data?.setSetting('security_biometrics', false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save security settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Widget _sectionTitle(String title, ColorScheme colors) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      title,
      style: TextStyle(
        color: colors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _switchRow({
    required String keyName,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final value = _values[keyName] ?? false;
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        key: ValueKey(keyName),
        value: value,
        onChanged: enabled && !_saving.contains(keyName)
            ? (next) => _change(keyName, next)
            : null,
      ),
    );
  }

  Future<void> _showSessions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final colors = AppTheme.colorsOf(sheetContext);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active sessions',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: const Icon(Icons.smartphone_outlined),
              ),
              title: const Text('This device'),
              subtitle: const Text('Current session · Active now'),
              trailing: Icon(Icons.check_circle, color: colors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'No other sessions are connected to this local account.',
              style: TextStyle(color: colors.secondaryText),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final passcodeEnabled = _values['security_passcode'] ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            elevation: 0,
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account protection',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use an additional password and device lock to keep your chats secure.',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _sectionTitle('Sign-in security', colors),
          _switchRow(
            keyName: 'security_two_step',
            icon: Icons.password_outlined,
            title: 'Two-step verification',
            subtitle: 'Require an additional password when signing in',
          ),
          const SizedBox(height: 8),
          _switchRow(
            keyName: 'security_login_alerts',
            icon: Icons.notification_important_outlined,
            title: 'Login alerts',
            subtitle: 'Notify you about a sign-in from a new device',
          ),
          _sectionTitle('Device protection', colors),
          _switchRow(
            keyName: 'security_passcode',
            icon: Icons.pin_outlined,
            title: 'Passcode lock',
            subtitle: 'Lock the app on this device',
          ),
          const SizedBox(height: 8),
          _switchRow(
            keyName: 'security_biometrics',
            icon: Icons.fingerprint,
            title: 'Biometric unlock',
            subtitle: passcodeEnabled
                ? 'Use biometrics to unlock the app'
                : 'Turn on passcode lock first',
            enabled: passcodeEnabled,
          ),
          _sectionTitle('Sessions', colors),
          SettingsRow(
            icon: Icons.devices_outlined,
            title: 'Active sessions',
            subtitle: '1 device',
            showChevron: true,
            onTap: _showSessions,
          ),
        ],
      ),
    );
  }
}
