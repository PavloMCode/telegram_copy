import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/demo_data.dart';
import '../models/local_group.dart';
import '../services/local_group_store.dart';
import '../theme/app_theme.dart';
import '../widgets/contact_call_dialog.dart';
import '../widgets/group_scope.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

class ContactAccountScreen extends StatelessWidget {
  const ContactAccountScreen({
    super.key,
    required this.contact,
    this.fromChat = false,
  });
  final DemoContact contact;
  final bool fromChat;

  Future<void> _copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _message(BuildContext context) {
    if (fromChat) {
      Navigator.pop(context);
      return;
    }
    final screen = GroupScope.wrap(
      context,
      ChatScreen(chatId: contact.id, chatName: contact.name),
    );
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final store = GroupScope.maybeOf(context);
    if (store == null) return _page(context, null);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _page(context, store),
    );
  }

  Widget _page(BuildContext context, LocalGroupStore? store) {
    final colors = AppTheme.colorsOf(context);
    final initials = contact.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final groups =
        store?.groups
            .where((group) => group.roleOf(contact.id) != null)
            .toList() ??
        <LocalGroup>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Contact options',
            onSelected: (action) => action == 'copy-phone'
                ? _copy(context, contact.phone, 'Phone number copied')
                : _copy(
                    context,
                    '${contact.name}\n${contact.phone}',
                    'Contact details copied',
                  ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'copy-phone',
                child: Text('Copy phone number'),
              ),
              PopupMenuItem(
                value: 'copy-contact',
                child: Text('Copy contact details'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: .2),
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      contact.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      contact.status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _message(context),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Message'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: _callButton(context))],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _section(context, 'Contact information'),
            const SizedBox(height: 8),
            Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(Icons.phone_outlined, color: colors.primary),
                title: const Text(
                  'Phone number',
                  style: TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  contact.phone,
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                ),
                trailing: IconButton(
                  tooltip: 'Copy phone number',
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  onPressed: () =>
                      _copy(context, contact.phone, 'Phone number copied'),
                ),
                onTap: () =>
                    _copy(context, contact.phone, 'Phone number copied'),
              ),
            ),
            const SizedBox(height: 28),
            _section(context, 'Groups in common (${groups.length})'),
            const SizedBox(height: 8),
            if (groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group_outlined, color: colors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No groups in common yet.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            for (final group in groups)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundImage: group.photo == null
                      ? null
                      : MemoryImage(group.photo!),
                  child: group.photo == null
                      ? const Icon(Icons.group_outlined)
                      : null,
                ),
                title: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${group.members.length} members'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GroupChatScreen(store: store!, groupId: group.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _callButton(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    ),
    onPressed: () => showContactCallDialog(context, contact.name),
    icon: const Icon(Icons.call_outlined, size: 20),
    label: const Text('Call', textAlign: TextAlign.center),
  );

  Widget _section(BuildContext context, String title) => Text(
    title,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.colorsOf(context).primary,
    ),
  );
}
