import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/local_account_store.dart';
import '../services/local_contact_store.dart';
import '../theme/app_theme.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/contact_scope.dart';
import '../widgets/group_scope.dart';
import '../widgets/settings_row.dart';

class SettingsScreenPrivacy extends StatefulWidget {
  const SettingsScreenPrivacy({super.key});

  @override
  State<SettingsScreenPrivacy> createState() => _SettingsScreenPrivacyState();
}

class _SettingsScreenPrivacyState extends State<SettingsScreenPrivacy> {
  static const _choices = ['Everybody', 'My contacts', 'Nobody'];
  final _values = <String, String>{};
  final _saving = <String>{};
  bool _readReceipts = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = AccountDataScope.maybeOf(context);
    if (_initialized || (data != null && !data.loaded)) return;
    _initialized = true;
    for (final key in const [
      'privacy_phone',
      'privacy_last_seen',
      'privacy_photo',
      'privacy_calls',
      'privacy_groups',
    ]) {
      _values[key] =
          data?.settingValue<String>(key, fallback: 'My contacts') ??
          'My contacts';
    }
    _readReceipts =
        data?.setting('privacy_read_receipts', fallback: true) ?? true;
  }

  Future<void> _choose(String key, String title) async {
    final current = _values[key] ?? 'My contacts';
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (value) => Navigator.pop(sheetContext, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final choice in _choices)
                    RadioListTile<String>(value: choice, title: Text(choice)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null || result == current) return;
    setState(() => _saving.add(key));
    try {
      await AccountDataScope.maybeOf(context)?.setSettingValue(key, result);
      if (mounted) setState(() => _values[key] = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save privacy settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<void> _changeReadReceipts(bool value) async {
    setState(() => _saving.add('privacy_read_receipts'));
    try {
      await AccountDataScope.maybeOf(
        context,
      )?.setSetting('privacy_read_receipts', value);
      if (mounted) setState(() => _readReceipts = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save privacy settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove('privacy_read_receipts'));
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

  Widget _privacyRow({
    required String keyName,
    required IconData icon,
    required String title,
  }) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: _saving.contains(keyName)
        ? 'Saving…'
        : (_values[keyName] ?? 'My contacts'),
    showChevron: true,
    onTap: _saving.contains(keyName) ? null : () => _choose(keyName, title),
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _sectionTitle('Who can see my information', colors),
          _privacyRow(
            keyName: 'privacy_phone',
            icon: Icons.phone_outlined,
            title: 'Phone number',
          ),
          const SizedBox(height: 8),
          _privacyRow(
            keyName: 'privacy_last_seen',
            icon: Icons.schedule_outlined,
            title: 'Last seen & online',
          ),
          const SizedBox(height: 8),
          _privacyRow(
            keyName: 'privacy_photo',
            icon: Icons.account_circle_outlined,
            title: 'Profile photos',
          ),
          _sectionTitle('Interactions', colors),
          _privacyRow(
            keyName: 'privacy_calls',
            icon: Icons.call_outlined,
            title: 'Calls',
          ),
          const SizedBox(height: 8),
          _privacyRow(
            keyName: 'privacy_groups',
            icon: Icons.group_add_outlined,
            title: 'Groups & channels',
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: Icons.done_all,
            title: 'Read receipts',
            subtitle: 'Let people know when you have read their messages',
            trailing: Switch(
              key: const ValueKey('privacy_read_receipts'),
              value: _readReceipts,
              onChanged: _saving.contains('privacy_read_receipts')
                  ? null
                  : _changeReadReceipts,
            ),
          ),
          _sectionTitle('People', colors),
          SettingsRow(
            icon: Icons.block_outlined,
            title: 'Blocked users',
            subtitle: 'Manage people who cannot contact you',
            showChevron: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => GroupScope.wrap(
                  context,
                  const SettingsScreenBlockedUsers(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreenBlockedUsers extends StatelessWidget {
  const SettingsScreenBlockedUsers({super.key});

  Future<void> _setBlocked(
    BuildContext context,
    LocalContactStore store,
    String id,
    bool blocked,
  ) async {
    try {
      await store.setBlocked(id, blocked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(blocked ? 'User blocked.' : 'User unblocked.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update blocked users.')),
        );
      }
    }
  }

  Future<void> _addBlockedUser(
    BuildContext context,
    LocalAccountStore data,
    LocalContactStore contacts,
  ) async {
    final available = data.contacts
        .where((contact) => !contacts.isBlocked(contact.id))
        .toList();
    final selected = await showModalBottomSheet<DemoContact>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Block a user',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('All contacts are already blocked.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final contact in available)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(contact.name.characters.first),
                        ),
                        title: Text(contact.name),
                        subtitle: Text(contact.phone),
                        onTap: () => Navigator.pop(sheetContext, contact),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await _setBlocked(context, contacts, selected.id, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final data = AccountDataScope.maybeOf(context);
    final contacts = ContactScope.maybeOf(context);
    final blocked = data == null || contacts == null
        ? <DemoContact>[]
        : data.contacts
              .where((contact) => contacts.isBlocked(contact.id))
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: blocked.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 48,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No blocked users',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Blocked users cannot message or call you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.secondaryText),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: blocked.length,
              separatorBuilder: (_, _) => const Divider(indent: 72, height: 1),
              itemBuilder: (context, index) {
                final contact = blocked[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name.characters.first),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  trailing: TextButton(
                    onPressed: contacts == null
                        ? null
                        : () =>
                              _setBlocked(context, contacts, contact.id, false),
                    child: const Text('Unblock'),
                  ),
                );
              },
            ),
      floatingActionButton: data == null || contacts == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addBlockedUser(context, data, contacts),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Block user'),
            ),
    );
  }
}
