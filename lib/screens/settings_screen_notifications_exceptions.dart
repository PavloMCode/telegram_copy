import 'package:flutter/material.dart';
import '../models/notification_category.dart';
import '../services/local_group_store.dart';
import '../theme/app_theme.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/group_scope.dart';

class SettingsScreenNotificationsExceptions extends StatefulWidget {
  const SettingsScreenNotificationsExceptions({super.key});
  @override
  State<SettingsScreenNotificationsExceptions> createState() =>
      _ExceptionsState();
}

class _ExceptionsState extends State<SettingsScreenNotificationsExceptions> {
  bool _saving = false;
  NotificationCategory _category = NotificationCategory.chats;
  LocalGroupStore? _groups;
  bool _loadingGroups = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groups = GroupScope.maybeOf(context);
    if (identical(groups, _groups)) return;
    _groups?.removeListener(_refresh);
    _groups = groups;
    groups?.addListener(_refresh);
    if (groups != null) {
      _loadingGroups = true;
      groups.load().then((_) {
        if (mounted && identical(groups, _groups)) {
          setState(() => _loadingGroups = false);
        }
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _groups?.removeListener(_refresh);
    super.dispose();
  }

  Map<String, bool> _exceptions() {
    return AccountDataScope.maybeOf(
          context,
        )?.notificationExceptions(_category) ??
        {};
  }

  Future<void> _save(String id, bool? value) async {
    final data = AccountDataScope.maybeOf(context);
    if (_saving || data == null) return;
    setState(() => _saving = true);
    try {
      await data.setNotificationException(_category, id, value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save notification exception.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final data = AccountDataScope.maybeOf(context);
    if (data == null) return;
    final exceptions = _exceptions();
    final available = _category == NotificationCategory.chats
        ? data.contacts
              .map((c) => (id: c.id, name: c.name, subtitle: c.phone))
              .toList()
        : (_groups?.groups ?? [])
              .where(
                (g) =>
                    g.isChannel == (_category == NotificationCategory.channels),
              )
              .map(
                (g) => (
                  id: g.id,
                  name: g.name,
                  subtitle: '${g.members.length} members',
                ),
              )
              .toList();
    available.removeWhere((c) => exceptions.containsKey(c.id));
    final contact =
        await showModalBottomSheet<({String id, String name, String subtitle})>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          builder: (sheetContext) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(switch (_category) {
                  NotificationCategory.chats => 'Choose a contact',
                  NotificationCategory.groups => 'Choose a group',
                  NotificationCategory.channels => 'Choose a channel',
                }, style: Theme.of(sheetContext).textTheme.titleLarge),
                if (available.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      _category == NotificationCategory.chats
                          ? 'No contacts available.'
                          : 'No ${_category.label.toLowerCase()} available. Create one or remove an existing exception.',
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in available)
                          ListTile(
                            title: Text(c.name),
                            subtitle: Text(c.subtitle),
                            onTap: () => Navigator.pop(sheetContext, c),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
    if (!mounted || contact == null) return;
    final value = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Notifications for ${contact.name}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Notify'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Mute'),
          ),
        ],
      ),
    );
    if (mounted && value != null) await _save(contact.id, value);
  }

  @override
  Widget build(BuildContext context) {
    final data = AccountDataScope.maybeOf(context);
    final ready = data != null && data.loaded && data.error == null;
    final canAdd =
        ready &&
        !_saving &&
        (_category == NotificationCategory.chats ||
            (!_loadingGroups && _groups != null && _groups!.loadError == null));
    final entries = _exceptions().entries.toList();
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification exceptions')),
      body: data != null && !data.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  data?.error ??
                      'Customize notifications for individual chats, groups and channels. Exceptions override category settings. Turning off all notifications takes priority.',
                  style: TextStyle(color: colors.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final category in NotificationCategory.values)
                      ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                if (_category != NotificationCategory.chats && _loadingGroups)
                  const LinearProgressIndicator(),
                if (_category != NotificationCategory.chats &&
                    _groups?.loadError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _groups!.loadError!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none_outlined, size: 48),
                        SizedBox(height: 12),
                        Text('No exceptions yet'),
                        SizedBox(height: 6),
                        Text(
                          'Add an exception to customize notifications.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      entry.value
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    title: Text(
                      _category == NotificationCategory.chats
                          ? data?.contact(entry.key)?.name ??
                                'Unavailable contact'
                          : _groups?.find(entry.key)?.name ??
                                'Unavailable conversation',
                    ),
                    subtitle: Text(entry.value ? 'Notify' : 'Muted'),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Edit exception',
                      enabled: ready && !_saving,
                      onSelected: (action) => _save(
                        entry.key,
                        action == 'remove' ? null : action == 'notify',
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'notify', child: Text('Notify')),
                        PopupMenuItem(value: 'mute', child: Text('Mute')),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Use default settings'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAdd ? _add : null,
        icon: const Icon(Icons.add),
        label: Text(_saving ? 'Saving…' : 'Add exception'),
      ),
    );
  }
}
